import Foundation

/// 用 osascript 发系统通知——对自签名/本地构建的 App 最稳，无需签名或权限授权。
enum Notifier {
    static func send(title: String, body: String) {
        let t = escape(title), b = escape(body)
        let script = "display notification \"\(b)\" with title \"\(t)\""
        DispatchQueue.global(qos: .utility).async {
            let p = Process()
            p.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
            p.arguments = ["-e", script]
            try? p.run()
        }
    }
    private static func escape(_ s: String) -> String {
        s.replacingOccurrences(of: "\\", with: "\\\\")
         .replacingOccurrences(of: "\"", with: "\\\"")
    }
}
