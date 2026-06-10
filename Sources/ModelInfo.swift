import Foundation

/// 读取各 CLI 本地会话日志，推断「当前使用的模型」。
enum ModelInfo {
    /// 把原始模型名美化：claude-opus-4-8 → Opus 4.8；gpt-5-codex → GPT-5 Codex
    static func pretty(_ raw: String) -> String {
        var s = raw
        for p in ["claude-", "openai/", "anthropic/", "models/"] {
            if s.hasPrefix(p) { s.removeFirst(p.count) }
        }
        // 数字间的连字符当成小数点：4-8 → 4.8
        var out = ""
        let chars = Array(s)
        for (i, c) in chars.enumerated() {
            if c == "-" {
                let prev = i > 0 ? chars[i-1] : " "
                let next = i < chars.count-1 ? chars[i+1] : " "
                out.append(prev.isNumber && next.isNumber ? "." : " ")
            } else { out.append(c) }
        }
        // 首字母大写每个单词；丢弃日期样式的长数字串(如 20241022)
        return out.split(separator: " ").compactMap { w -> String? in
            let str = String(w)
            if str.count >= 6 && str.allSatisfy({ $0.isNumber }) { return nil }
            if str.lowercased() == "gpt" { return "GPT" }
            return str.prefix(1).uppercased() + str.dropFirst()
        }.joined(separator: " ")
    }

    /// Claude：最近用过的 *Claude* 模型。
    /// ~/.claude/projects 里也会混入中转(DeepSeek/GPT)会话日志，
    /// 故只认 model 以 "claude" 开头的，跳过其它供应商。
    static func claude() -> String? {
        let dir = home("/.claude/projects")
        return latestModel(inDir: dir, accept: { $0.lowercased().hasPrefix("claude") }) { obj in
            (obj["message"] as? [String: Any])?["model"] as? String
        }
    }

    /// Codex：优先 ~/.codex/sessions 最新 jsonl，其次 config.toml 的 model=
    static func codex() -> String? {
        if let m = latestModel(inDir: home("/.codex/sessions"), accept: { _ in true }, extract: { obj in
            (obj["model"] as? String) ?? (obj["payload"] as? [String: Any])?["model"] as? String
        }) { return m }
        // config.toml
        if let toml = try? String(contentsOfFile: home("/.codex/config.toml"), encoding: .utf8) {
            for line in toml.split(separator: "\n") {
                let t = line.trimmingCharacters(in: .whitespaces)
                if t.hasPrefix("model"), let eq = t.firstIndex(of: "=") {
                    return t[t.index(after: eq)...].trimmingCharacters(in: CharacterSet(charactersIn: " \"'"))
                }
            }
        }
        return nil
    }

    // MARK: 工具
    private static func home(_ p: String) -> String {
        FileManager.default.homeDirectoryForCurrentUser.path + p
    }

    /// 在目录里按修改时间从新到旧扫描 jsonl，返回第一个被 accept 接受的 model。
    /// 只检查最近的若干个文件，避免遍历整个历史。
    private static func latestModel(inDir dir: String,
                                    accept: (String) -> Bool,
                                    extract: ([String: Any]) -> String?) -> String? {
        let fm = FileManager.default
        guard let en = fm.enumerator(atPath: dir) else { return nil }
        var files: [(path: String, date: Date)] = []
        for case let rel as String in en where rel.hasSuffix(".jsonl") {
            let full = dir + "/" + rel
            if let attr = try? fm.attributesOfItem(atPath: full),
               let d = attr[.modificationDate] as? Date {
                files.append((full, d))
            }
        }
        // 最近修改的优先，最多看 20 个文件
        for (path, _) in files.sorted(by: { $0.date > $1.date }).prefix(20) {
            if let m = lastAcceptedModel(path: path, accept: accept, extract: extract) {
                return m
            }
        }
        return nil
    }

    /// 读文件(末尾往前)找第一个 accept 接受的 model
    private static func lastAcceptedModel(path: String,
                                          accept: (String) -> Bool,
                                          extract: ([String: Any]) -> String?) -> String? {
        guard let content = try? String(contentsOfFile: path, encoding: .utf8) else { return nil }
        for line in content.split(separator: "\n").reversed() {
            guard let data = line.data(using: .utf8),
                  let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
            else { continue }
            if let m = extract(obj), !m.isEmpty, accept(m) { return m }
        }
        return nil
    }
}
