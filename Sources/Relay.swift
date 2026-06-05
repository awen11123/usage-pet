import Foundation

// MARK: - 中转 API 账户 & 余额
struct RelayAccount: Codable, Identifiable {
    var id: String = UUID().uuidString
    var name: String
    var baseURL: String
    var apiKey: String
}

struct RelaySnapshot {
    var total: Double?      // 总额度 USD
    var used: Double?       // 已用 USD
    var remaining: Double? { guard let t = total, let u = used else { return nil }; return t - u }
    var usedPercent: Double? {
        guard let t = total, t > 0, let u = used else { return nil }
        return max(0, min(100, u / t * 100))
    }
}

// MARK: - 配置存储(~/.claude/claude-pet-relays.json)
enum RelayStore {
    static let path: String = {
        FileManager.default.homeDirectoryForCurrentUser.path + "/.claude/claude-pet-relays.json"
    }()
    static func load() -> [RelayAccount] {
        guard let data = FileManager.default.contents(atPath: path),
              let arr = try? JSONDecoder().decode([RelayAccount].self, from: data) else { return [] }
        return arr
    }
    static func save(_ accounts: [RelayAccount]) {
        let dir = (path as NSString).deletingLastPathComponent
        try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        if let data = try? JSONEncoder().encode(accounts) {
            try? data.write(to: URL(fileURLWithPath: path))
            try? FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: path)
        }
    }
}

// MARK: - 查询(OpenAI 兼容计费接口)
enum RelayAPI {
    static func fetch(_ acc: RelayAccount, completion: @escaping (Result<RelaySnapshot, Error>) -> Void) {
        let base = normalize(acc.baseURL)
        // 1) 订阅(总额度)
        request("\(base)/v1/dashboard/billing/subscription", key: acc.apiKey) { r1 in
            switch r1 {
            case .failure(let e): completion(.failure(e))
            case .success(let sub):
                let total = (sub["hard_limit_usd"] as? Double)
                    ?? (sub["hard_limit_usd"] as? NSNumber)?.doubleValue
                // 2) 用量(已用，单位美分)
                let end = ymd(Date().addingTimeInterval(86400))
                let start = "2024-01-01"
                request("\(base)/v1/dashboard/billing/usage?start_date=\(start)&end_date=\(end)", key: acc.apiKey) { r2 in
                    var snap = RelaySnapshot()
                    snap.total = total
                    if case .success(let use) = r2 {
                        if let cents = (use["total_usage"] as? Double) ?? (use["total_usage"] as? NSNumber)?.doubleValue {
                            snap.used = cents / 100.0
                        }
                    }
                    completion(.success(snap))
                }
            }
        }
    }

    private static func normalize(_ url: String) -> String {
        var s = url.trimmingCharacters(in: .whitespaces)
        while s.hasSuffix("/") { s.removeLast() }
        if s.hasSuffix("/v1") { s.removeLast(3) }
        return s
    }
    private static func ymd(_ d: Date) -> String {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"; f.timeZone = TimeZone(identifier: "UTC")
        return f.string(from: d)
    }

    enum RelayError: LocalizedError {
        case http(Int), message(String)
        var errorDescription: String? {
            switch self {
            case .http(let c): return "HTTP \(c)"
            case .message(let m): return m
            }
        }
    }

    private static func request(_ urlStr: String, key: String,
                                completion: @escaping (Result<[String: Any], Error>) -> Void) {
        guard let url = URL(string: urlStr) else { completion(.failure(RelayError.message("URL 无效"))); return }
        var req = URLRequest(url: url)
        req.timeoutInterval = 15
        req.addValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        req.addValue("application/json", forHTTPHeaderField: "Accept")
        URLSession.shared.dataTask(with: req) { data, resp, err in
            if let err = err { completion(.failure(err)); return }
            if let code = (resp as? HTTPURLResponse)?.statusCode, code != 200 {
                completion(.failure(RelayError.http(code))); return
            }
            guard let data = data,
                  let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                completion(.failure(RelayError.message("解析失败"))); return
            }
            completion(.success(obj))
        }.resume()
    }
}
