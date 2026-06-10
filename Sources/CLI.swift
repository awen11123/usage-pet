import Foundation

/// 命令行模式：不弹宠物，直接在终端打印用量。供 shell 脚本 / Raycast / Alfred 用。
enum CLI {
    private static func run(_ block: @escaping () -> Void) {
        // 这些子命令是异步的(网络/进程)，用 RunLoop 等到完成
        block()
    }
    private static func wait(_ work: (@escaping () -> Void) -> Void) {
        let sem = DispatchSemaphore(value: 0)
        work { sem.signal() }
        _ = sem.wait(timeout: .now() + 30)
    }

    // MARK: status —— Codex + 中转(Claude 需 GUI 登录态，CLI 暂不支持)
    static func status(json: Bool) {
        var out: [String: Any] = [:]
        // Codex
        wait { done in
            CodexUsage.fetch { result in
                if case .success(let s) = result {
                    out["codex"] = ["five_hour": s.fiveHour as Any, "weekly": s.weekly as Any,
                                    "plan": s.planType as Any]
                }
                done()
            }
        }
        // 中转
        var relays: [[String: Any]] = []
        for acc in RelayStore.load() {
            wait { done in
                RelayAPI.fetch(acc) { result, _ in
                    if case .success(let s) = result {
                        relays.append(["name": acc.name,
                                       "remaining": s.remaining as Any,
                                       "total": s.total as Any,
                                       "currency": s.currency])
                    }
                    done()
                }
            }
        }
        if !relays.isEmpty { out["relays"] = relays }

        if json {
            printJSON(out)
        } else {
            if let codex = out["codex"] as? [String: Any] {
                let h = (codex["five_hour"] as? Double).map { Int($0) }.map(String.init) ?? "-"
                let w = (codex["weekly"] as? Double).map { Int($0) }.map(String.init) ?? "-"
                print("Codex   5h \(h)%   周 \(w)%")
            }
            for r in relays {
                let cur = r["currency"] as? String ?? "$"
                let rem = (r["remaining"] as? Double).map { String(format: "%.2f", $0) } ?? "-"
                print("\(r["name"] as? String ?? "中转")   余 \(cur)\(rem)")
            }
            if out.isEmpty { print("无可用数据(Codex 未安装且未配置中转)") }
        }
    }

    static func codex(json: Bool) {
        wait { done in
            CodexUsage.fetch { result in
                switch result {
                case .success(let s):
                    if json {
                        printJSON(["five_hour": s.fiveHour as Any, "weekly": s.weekly as Any,
                                   "plan": s.planType as Any])
                    } else {
                        let h = s.fiveHour.map { Int($0) }.map(String.init) ?? "-"
                        let w = s.weekly.map { Int($0) }.map(String.init) ?? "-"
                        print("Codex  5h \(h)%  周 \(w)%  plan=\(s.planType ?? "?")")
                    }
                case .failure(let e):
                    FileHandle.standardError.write("Codex 读取失败: \(e.localizedDescription)\n".data(using: .utf8)!)
                }
                done()
            }
        }
    }

    static func relays() {
        let accts = RelayStore.load()
        if accts.isEmpty { print("(未配置中转 API)"); return }
        for a in accts { print("\(a.name)\t\(a.baseURL)") }
    }

    private static func printJSON(_ obj: [String: Any]) {
        if let d = try? JSONSerialization.data(withJSONObject: obj, options: [.prettyPrinted, .sortedKeys]),
           let s = String(data: d, encoding: .utf8) {
            print(s)
        }
    }
}
