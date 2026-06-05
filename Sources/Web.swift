import Cocoa
import WebKit

/// 内嵌真实浏览器(WKWebView)。用户在弹出的窗口里登录 claude.ai 一次，
/// cookie 持久保存(WKWebsiteDataStore.default)，之后 App 每次静默调用
/// 页面内的 fetch 拿用量数据——既绕过 Cloudflare，也不依赖会过期的 sessionKey。
final class ClaudeWeb: NSObject, WKNavigationDelegate {
    let webView: WKWebView
    private var loginWindow: NSWindow?
    private var loaded = false
    private var loginMode = false   // true 时持续轮询直到登录成功

    override init() {
        let cfg = WKWebViewConfiguration()
        cfg.websiteDataStore = .default()   // 持久 cookie
        webView = WKWebView(frame: NSRect(x: 0, y: 0, width: 460, height: 680), configuration: cfg)
        super.init()
        webView.navigationDelegate = self
        webView.customUserAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15"
        UsageAPI.log("加载 claude.ai")
        webView.load(URLRequest(url: URL(string: "https://claude.ai/")!))
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        loaded = true
    }
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        UsageAPI.log("预导航失败: \(error.localizedDescription)")
    }

    // MARK: 登录窗口
    func showLogin() {
        loginMode = true
        if loginWindow == nil {
            let win = NSWindow(contentRect: webView.frame,
                               styleMask: [.titled, .closable, .resizable],
                               backing: .buffered, defer: false)
            win.title = "登录 Claude（登录成功后会自动关闭）"
            win.contentView = webView
            win.center()
            win.level = .floating
            loginWindow = win
        }
        NSApp.activate(ignoringOtherApps: true)
        loginWindow?.makeKeyAndOrderFront(nil)
        // 进入登录态后持续轮询
        scheduleLoginPoll()
    }
    private func hideLogin() {
        loginMode = false
        loginWindow?.orderOut(nil)
    }
    private func scheduleLoginPoll() {
        guard loginMode else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
            guard let self = self, self.loginMode else { return }
            self.fetchUsage { _ in }   // 结果由 fetchUsage 内部处理(成功则收起窗口)
        }
    }

    // MARK: 取数据
    func fetchUsage(retriesLeft: Int = 6, completion: @escaping (Result<UsageSnapshot, Error>) -> Void) {
        guard loaded else {
            if retriesLeft > 0 {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
                    self?.fetchUsage(retriesLeft: retriesLeft - 1, completion: completion)
                }
            } else { completion(.failure(UsageAPI.APIError.message("页面加载超时"))) }
            return
        }

        // 先从 lastActiveOrg cookie 拿 org id，再直接请求 usage(绕过会 403 的列表接口)
        webView.configuration.websiteDataStore.httpCookieStore.getAllCookies { [weak self] cookies in
            guard let self = self else { return }
            var orgId = cookies.first { $0.name == "lastActiveOrg" }?.value ?? ""
            orgId = orgId.removingPercentEncoding ?? orgId
            UsageAPI.log("org id = \(orgId.isEmpty ? "<空>" : orgId)")
            self.runUsageJS(orgId: orgId, retriesLeft: retriesLeft, completion: completion)
        }
    }

    private func runUsageJS(orgId: String, retriesLeft: Int,
                            completion: @escaping (Result<UsageSnapshot, Error>) -> Void) {
        let js = """
        try {
          let id = orgId;
          if (!id) {
            const o = await fetch('/api/organizations', {headers:{accept:'application/json'}});
            if (o.status === 401 || o.status === 403) return JSON.stringify({__auth: o.status});
            if (!o.ok) return JSON.stringify({__cf: o.status});
            const orgs = await o.json();
            if (!orgs.length) return JSON.stringify({__err:'no orgs'});
            id = orgs[0].uuid;
          }
          const u = await fetch(`/api/organizations/${id}/usage`, {headers:{accept:'application/json'}});
          if (u.status === 401 || u.status === 403) return JSON.stringify({__auth: u.status});
          if (!u.ok) return JSON.stringify({__cf: u.status});
          return await u.text();
        } catch (e) { return JSON.stringify({__err: String(e)}); }
        """
        webView.callAsyncJavaScript(js, arguments: ["orgId": orgId], in: nil, in: .page) { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .failure(let e):
                UsageAPI.log("JS 失败: \(e.localizedDescription)")
                self.afterFailure(retriesLeft, completion) { completion(.failure(e)) }
            case .success(let value):
                guard let s = value as? String, let data = s.data(using: .utf8) else {
                    completion(.failure(UsageAPI.APIError.message("无返回"))); return
                }
                if let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    // 未登录 / 授权无效 → 弹出登录窗口并持续轮询
                    if obj["__auth"] != nil {
                        UsageAPI.log("需要登录 (\(obj["__auth"]!))")
                        self.showLogin()
                        completion(.failure(UsageAPI.APIError.sessionExpired))
                        return
                    }
                    if obj["__cf"] != nil {
                        UsageAPI.log("Cloudflare/其他 \(obj["__cf"]!)，重试")
                        self.afterFailure(retriesLeft, completion) {
                            completion(.failure(UsageAPI.APIError.message("暂时无法访问")))
                        }
                        return
                    }
                    if let err = obj["__err"] as? String {
                        completion(.failure(UsageAPI.APIError.message(err))); return
                    }
                }
                do {
                    let r = try JSONDecoder().decode(UsageResponse.self, from: data)
                    self.hideLogin()   // 成功 → 收起登录窗口
                    completion(.success(r.toSnapshot()))
                } catch {
                    UsageAPI.log("解析失败 body=\(s.prefix(150))")
                    self.afterFailure(retriesLeft, completion) { completion(.failure(error)) }
                }
            }
        }
    }

    private func afterFailure(_ retriesLeft: Int,
                              _ completion: @escaping (Result<UsageSnapshot, Error>) -> Void,
                              _ giveUp: @escaping () -> Void) {
        if loginMode {            // 登录态：持续轮询
            scheduleLoginPoll()
        } else if retriesLeft > 0 {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) { [weak self] in
                self?.fetchUsage(retriesLeft: retriesLeft - 1, completion: completion)
            }
        } else { giveUp() }
    }
}
