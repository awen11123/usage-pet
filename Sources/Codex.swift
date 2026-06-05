import Foundation

// MARK: - Codex(OpenAI) 用量快照
struct CodexSnapshot {
    var fiveHour: Double?
    var weekly: Double?
    var fiveHourResets: Date?
    var weeklyResets: Date?
    var planType: String?
    var maxUtilization: Double { max(fiveHour ?? 0, weekly ?? 0) }
}

enum CodexError: LocalizedError {
    case notInstalled, timeout, rpc(String)
    var errorDescription: String? {
        switch self {
        case .notInstalled: return "未检测到 codex CLI"
        case .timeout:      return "codex 响应超时"
        case .rpc(let m):   return m
        }
    }
}

/// 通过官方 `codex app-server`(JSON-RPC over stdio) 读取速率限额：
/// initialize → initialized → account/rateLimits/read
enum CodexUsage {
    static func findBinary() -> String? {
        let fm = FileManager.default
        if let ov = ProcessInfo.processInfo.environment["CLAUDEPET_CODEX_BIN"],
           fm.isExecutableFile(atPath: ov) { return ov }
        let home = fm.homeDirectoryForCurrentUser.path
        let candidates = [
            "/opt/homebrew/bin/codex", "/usr/local/bin/codex",
            "\(home)/.codex/bin/codex", "\(home)/.local/bin/codex",
            "\(home)/.npm-global/bin/codex", "\(home)/.bun/bin/codex",
            "\(home)/.volta/bin/codex", "\(home)/.nvm/bin/codex",
        ]
        for c in candidates where fm.isExecutableFile(atPath: c) { return c }
        // 用登录 shell 解析 PATH(GUI 进程默认 PATH 不全)
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/bin/zsh")
        p.arguments = ["-lc", "command -v codex"]
        let out = Pipe(); p.standardOutput = out; p.standardError = Pipe()
        do { try p.run(); p.waitUntilExit() } catch { return nil }
        let s = String(data: out.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return fm.isExecutableFile(atPath: s) ? s : nil
    }

    static func fetch(completion: @escaping (Result<CodexSnapshot, Error>) -> Void) {
        DispatchQueue.global().async {
            guard let bin = findBinary() else { completion(.failure(CodexError.notInstalled)); return }

            let proc = Process()
            proc.executableURL = URL(fileURLWithPath: bin)
            proc.arguments = ["app-server"]
            let inPipe = Pipe(), outPipe = Pipe()
            proc.standardInput = inPipe
            proc.standardOutput = outPipe
            proc.standardError = Pipe()

            let lock = NSLock()
            var done = false
            func finish(_ r: Result<CodexSnapshot, Error>) {
                lock.lock(); let already = done; done = true; lock.unlock()
                if already { return }
                outPipe.fileHandleForReading.readabilityHandler = nil
                if proc.isRunning { proc.terminate() }
                completion(r)
            }

            func send(_ s: String) {
                try? inPipe.fileHandleForWriting.write(contentsOf: (s + "\n").data(using: .utf8)!)
            }

            var buffer = Data()
            outPipe.fileHandleForReading.readabilityHandler = { h in
                let d = h.availableData
                if d.isEmpty { return }
                buffer.append(d)
                while let nl = buffer.firstIndex(of: 0x0A) {
                    let line = buffer.subdata(in: buffer.startIndex..<nl)
                    buffer.removeSubrange(buffer.startIndex...nl)
                    guard let obj = try? JSONSerialization.jsonObject(with: line) as? [String: Any] else { continue }
                    let id = obj["id"] as? Int
                    if id == 1 {
                        send("{\"method\":\"initialized\"}")
                        send("{\"method\":\"account/rateLimits/read\",\"id\":2}")
                    } else if id == 2 {
                        if let result = obj["result"] as? [String: Any] {
                            finish(.success(parse(result)))
                        } else if let err = obj["error"] {
                            finish(.failure(CodexError.rpc("\(err)")))
                        } else {
                            finish(.failure(CodexError.rpc("无 result")))
                        }
                    }
                }
            }

            do { try proc.run() } catch { finish(.failure(CodexError.notInstalled)); return }
            send("{\"method\":\"initialize\",\"id\":1,\"params\":{\"clientInfo\":{\"name\":\"claude-pet\",\"title\":\"Claude Pet\",\"version\":\"1.0\"}}}")

            DispatchQueue.global().asyncAfter(deadline: .now() + 15) { finish(.failure(CodexError.timeout)) }
        }
    }

    private static func parse(_ result: [String: Any]) -> CodexSnapshot {
        let rl = (result["rateLimits"] as? [String: Any]) ?? result
        func window(_ key: String) -> (Double?, Date?) {
            guard let w = rl[key] as? [String: Any] else { return (nil, nil) }
            var pct = (w["usedPercent"] as? Double) ?? (w["used_percent"] as? Double)
            if let p = pct, p > 0, p < 1 { pct = p * 100 }   // 有时返回 0~1 小数
            var reset: Date?
            if let r = (w["resetsAt"] as? Double) ?? (w["resets_at"] as? Double) {
                reset = Date(timeIntervalSince1970: r)
            }
            return (pct, reset)
        }
        let (p, pr) = window("primary")
        let (s, sr) = window("secondary")
        var snap = CodexSnapshot()
        snap.fiveHour = p; snap.fiveHourResets = pr
        snap.weekly = s;   snap.weeklyResets = sr
        snap.planType = rl["planType"] as? String
        return snap
    }
}
