import Foundation

/// 用量历史样本：时间 + 5h% + 7d%(或 relay 用量%)。
struct UsageSample: Codable {
    let t: TimeInterval     // unix 时间戳
    let h: Double           // 5h 或主指标 %
    let w: Double           // 7d 或副指标 %
}

/// 按数据源 id 维护一份滚动 7 天历史(每 ~5 分钟记一条，多余的删)。
enum History {
    private static var path: String {
        FileManager.default.homeDirectoryForCurrentUser.path + "/.claude/claude-pet-history.json"
    }
    private static var cache: [String: [UsageSample]] = load()
    private static let maxAge: TimeInterval = 7 * 24 * 3600
    private static let minGap: TimeInterval = 30          // 至少 30 秒才记一条(防手动连点)
    private static let maxPerSource = 600                 // 防爆

    /// 追加一条样本(自带去抖：太密会丢弃)
    static func record(source: String, h: Double, w: Double) {
        let now = Date().timeIntervalSince1970
        var arr = cache[source] ?? []
        if let last = arr.last, now - last.t < minGap { return }
        arr.append(UsageSample(t: now, h: h, w: w))
        // 删除 7 天外
        let cutoff = now - maxAge
        arr.removeAll { $0.t < cutoff }
        if arr.count > maxPerSource { arr.removeFirst(arr.count - maxPerSource) }
        cache[source] = arr
        save()
    }

    static func samples(source: String) -> [UsageSample] {
        cache[source] ?? []
    }

    private static func load() -> [String: [UsageSample]] {
        guard let d = FileManager.default.contents(atPath: path),
              let m = try? JSONDecoder().decode([String: [UsageSample]].self, from: d) else { return [:] }
        return m
    }
    private static func save() {
        let dir = (path as NSString).deletingLastPathComponent
        try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        if let d = try? JSONEncoder().encode(cache) {
            try? d.write(to: URL(fileURLWithPath: path))
            try? FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: path)
        }
    }
}

/// 绘制 ASCII sparkline(8 字符宽)。用 ▁▂▃▄▅▆▇█ 8 级
enum Sparkline {
    private static let blocks = ["▁","▂","▃","▄","▅","▆","▇","█"]
    static func text(_ values: [Double], width: Int = 12) -> String {
        guard !values.isEmpty else { return "" }
        // 抽样到指定宽度
        let buckets = max(1, width)
        var sampled: [Double] = []
        for i in 0..<buckets {
            let from = Int(Double(i) / Double(buckets) * Double(values.count))
            let to = max(from + 1, Int(Double(i+1) / Double(buckets) * Double(values.count)))
            let slice = values[from..<min(to, values.count)]
            sampled.append(slice.reduce(0, +) / Double(slice.count))
        }
        // 归一化到 0-7
        let lo = sampled.min() ?? 0
        let hi = max(sampled.max() ?? 0, lo + 1)   // 防止 hi==lo
        return sampled.map { v -> String in
            let idx = Int(((v - lo) / (hi - lo) * 7).rounded())
            return blocks[max(0, min(7, idx))]
        }.joined()
    }
}
