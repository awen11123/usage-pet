import Foundation

// MARK: - 中转 API 账户 & 余额
struct RelayAccount: Codable, Identifiable {
    var id: String = UUID().uuidString
    var name: String
    var baseURL: String
    var apiKey: String
}

struct RelaySnapshot {
    var total: Double?           // 总额度
    var used: Double?            // 已用
    var remainingDirect: Double? // 接口直接给出的余额(如 DeepSeek)
    var currency: String = "$"   // 货币符号
    var remaining: Double? {
        if let r = remainingDirect { return r }
        guard let t = total, let u = used else { return nil }
        return t - u
    }
    var usedPercent: Double? {
        guard let t = total, t > 0, let u = used else { return nil }
        return max(0, min(100, u / t * 100))
    }
}

// MARK: - 配置存储
// 名称/URL 存 JSON(~/.claude/claude-pet-relays.json)，API Key 存钥匙串。
enum RelayStore {
    static let path: String = {
        FileManager.default.homeDirectoryForCurrentUser.path + "/.claude/claude-pet-relays.json"
    }()

    static func load() -> [RelayAccount] {
        guard let data = FileManager.default.contents(atPath: path),
              var arr = try? JSONDecoder().decode([RelayAccount].self, from: data) else { return [] }
        var migrated = false
        for i in arr.indices {
            if arr[i].apiKey.isEmpty {
                arr[i].apiKey = Keychain.get(arr[i].id) ?? ""      // 正常：从钥匙串取
            } else {
                Keychain.set(arr[i].apiKey, account: arr[i].id)    // 旧明文：迁移进钥匙串
                migrated = true
            }
        }
        if migrated { save(arr) }   // 重写 JSON(去掉明文 key)
        return arr
    }

    static func save(_ accounts: [RelayAccount]) {
        let dir = (path as NSString).deletingLastPathComponent
        try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        for a in accounts { Keychain.set(a.apiKey, account: a.id) }
        // JSON 里抹掉 key
        let sanitized = accounts.map { a -> RelayAccount in var c = a; c.apiKey = ""; return c }
        if let data = try? JSONEncoder().encode(sanitized) {
            try? data.write(to: URL(fileURLWithPath: path))
            try? FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: path)
        }
    }

    static func remove(_ account: RelayAccount) {
        Keychain.delete(account.id)
    }
}

// MARK: - 查询(OpenAI 兼容计费接口)
enum RelayAPI {
    /// preferred: 上次成功的探测下标(优先尝试)。回调附带本次命中的下标，供缓存。
    static func fetch(_ acc: RelayAccount, preferred: Int? = nil,
                      completion: @escaping (Result<RelaySnapshot, Error>, Int?) -> Void) {
        let base = normalize(acc.baseURL)
        let org = origin(acc.baseURL)
        let key = acc.apiKey
        let probes: [(@escaping (RelaySnapshot?) -> Void) -> Void] = [
            { cb in probeOneAPI(base, key, cb) },        // 0 one-api / new-api
            { cb in probeDeepSeek(org, key, cb) },       // 1 DeepSeek
            { cb in probeOpenRouter(org, key, cb) },     // 2 OpenRouter
            { cb in probeSiliconFlow(base, key, cb) },   // 3 硅基流动
        ]
        // 探测顺序：优先项排最前，其余按原序补上
        var order = Array(probes.indices)
        if let p = preferred, order.contains(p) {
            order.removeAll { $0 == p }; order.insert(p, at: 0)
        }
        runProbes(probes, order, 0) { snap, idx in
            if let s = snap { completion(.success(s), idx) }
            else { completion(.failure(RelayError.message("无法识别该中转的余额接口")), nil) }
        }
    }

    private static func runProbes(_ probes: [(@escaping (RelaySnapshot?) -> Void) -> Void],
                                  _ order: [Int], _ k: Int,
                                  _ done: @escaping (RelaySnapshot?, Int?) -> Void) {
        if k >= order.count { done(nil, nil); return }
        let idx = order[k]
        let probe = probes[idx]
        probe { snap in
            if let s = snap { done(s, idx) } else { runProbes(probes, order, k + 1, done) }
        }
    }

    // one-api / new-api：/v1/dashboard/billing/subscription + /usage
    private static func probeOneAPI(_ base: String, _ key: String, _ cb: @escaping (RelaySnapshot?) -> Void) {
        get("\(base)/v1/dashboard/billing/subscription", key) { code, sub in
            guard code == 200, let sub = sub, let total = num(sub["hard_limit_usd"]) else { cb(nil); return }
            let end = ymd(Date().addingTimeInterval(86400))
            get("\(base)/v1/dashboard/billing/usage?start_date=2024-01-01&end_date=\(end)", key) { _, use in
                var s = RelaySnapshot(); s.total = total
                if let use = use, let cents = num(use["total_usage"]) { s.used = cents / 100.0 }
                cb(s)
            }
        }
    }
    // DeepSeek：{origin}/user/balance
    private static func probeDeepSeek(_ origin: String, _ key: String, _ cb: @escaping (RelaySnapshot?) -> Void) {
        get("\(origin)/user/balance", key) { code, obj in
            guard code == 200, let infos = obj?["balance_infos"] as? [[String: Any]], let info = infos.first else { cb(nil); return }
            var s = RelaySnapshot()
            s.remainingDirect = num(info["total_balance"])
            s.currency = symbol(info["currency"] as? String)
            cb(s)
        }
    }
    // OpenRouter：{origin}/api/v1/credits → data.total_credits - data.total_usage (USD)
    private static func probeOpenRouter(_ origin: String, _ key: String, _ cb: @escaping (RelaySnapshot?) -> Void) {
        get("\(origin)/api/v1/credits", key) { code, obj in
            guard code == 200, let d = obj?["data"] as? [String: Any],
                  let total = num(d["total_credits"]) else { cb(nil); return }
            var s = RelaySnapshot()
            s.total = total
            s.used = num(d["total_usage"]) ?? 0
            cb(s)
        }
    }
    // 硅基流动：/v1/user/info → data.totalBalance / balance (CNY)
    private static func probeSiliconFlow(_ base: String, _ key: String, _ cb: @escaping (RelaySnapshot?) -> Void) {
        get("\(base)/v1/user/info", key) { code, obj in
            guard code == 200, let d = obj?["data"] as? [String: Any],
                  let bal = num(d["totalBalance"]) ?? num(d["balance"]) else { cb(nil); return }
            var s = RelaySnapshot()
            s.remainingDirect = bal
            s.currency = "¥"
            cb(s)
        }
    }

    /// 兼容数字或字符串数字
    private static func num(_ v: Any?) -> Double? {
        if let d = v as? Double { return d }
        if let n = v as? NSNumber { return n.doubleValue }
        if let s = v as? String { return Double(s) }
        return nil
    }
    private static func symbol(_ currency: String?) -> String {
        switch currency?.uppercased() {
        case "CNY", "RMB": return "¥"
        case "USD": return "$"
        case "EUR": return "€"
        default: return currency.map { "\($0) " } ?? "$"
        }
    }

    private static func normalize(_ url: String) -> String {
        var s = url.trimmingCharacters(in: .whitespaces)
        while s.hasSuffix("/") { s.removeLast() }
        if s.hasSuffix("/v1") { s.removeLast(3) }
        return s
    }
    /// 取协议+域名(+端口)，忽略后面的 /anthropic、/v1 等路径
    private static func origin(_ s: String) -> String {
        if let u = URL(string: s.trimmingCharacters(in: .whitespaces)),
           let scheme = u.scheme, let host = u.host {
            if let port = u.port { return "\(scheme)://\(host):\(port)" }
            return "\(scheme)://\(host)"
        }
        return normalize(s)
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

    /// GET 请求，回调 (HTTP状态码, 解析后的 JSON?)。非 200 也回调，由探测器决定。
    private static func get(_ urlStr: String, _ key: String,
                            completion: @escaping (Int, [String: Any]?) -> Void) {
        guard let url = URL(string: urlStr) else { completion(-1, nil); return }
        var req = URLRequest(url: url)
        req.timeoutInterval = 15
        req.addValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        req.addValue("application/json", forHTTPHeaderField: "Accept")
        URLSession.shared.dataTask(with: req) { data, resp, err in
            if let err = err {
                UsageAPI.log("Relay \(urlStr) 网络错误: \(err.localizedDescription)")
                completion(-1, nil); return
            }
            let code = (resp as? HTTPURLResponse)?.statusCode ?? -1
            let snippet = data.flatMap { String(data: $0.prefix(120), encoding: .utf8) } ?? ""
            UsageAPI.log("Relay \(urlStr) -> \(code)  \(snippet)")
            let obj = data.flatMap { try? JSONSerialization.jsonObject(with: $0) as? [String: Any] } ?? nil
            completion(code, obj)
        }.resume()
    }
}
