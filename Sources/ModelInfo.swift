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

    /// Claude：~/.claude/projects 下最新 jsonl 里最后出现的 message.model
    static func claude() -> String? {
        let dir = home("/.claude/projects")
        return lastModel(inNewestJSONL: dir) { obj in
            (obj["message"] as? [String: Any])?["model"] as? String
        }
    }

    /// Codex：优先 ~/.codex/sessions 最新 jsonl，其次 config.toml 的 model=
    static func codex() -> String? {
        if let m = lastModel(inNewestJSONL: home("/.codex/sessions"), extract: { obj in
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

    /// 找目录下(递归)最新修改的 .jsonl，从末尾往前找第一个能取到 model 的行
    private static func lastModel(inNewestJSONL dir: String,
                                  extract: ([String: Any]) -> String?) -> String? {
        let fm = FileManager.default
        guard let en = fm.enumerator(atPath: dir) else { return nil }
        var newest: (path: String, date: Date)?
        for case let rel as String in en where rel.hasSuffix(".jsonl") {
            let full = dir + "/" + rel
            if let attr = try? fm.attributesOfItem(atPath: full),
               let d = attr[.modificationDate] as? Date {
                if newest == nil || d > newest!.date { newest = (full, d) }
            }
        }
        guard let path = newest?.path,
              let content = try? String(contentsOfFile: path, encoding: .utf8) else { return nil }
        for line in content.split(separator: "\n").reversed() {
            guard let data = line.data(using: .utf8),
                  let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
            else { continue }
            if let m = extract(obj), !m.isEmpty { return m }
        }
        return nil
    }
}
