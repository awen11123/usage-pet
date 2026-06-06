import Foundation
import UserNotifications

/// 通知发送：优先 UNUserNotificationCenter(原生、点击可回主 App)，失败时回退 osascript。
enum Notifier {
    private static var permissionRequested = false
    private static var permissionGranted = false

    static func requestPermissionIfNeeded() {
        guard !permissionRequested else { return }
        permissionRequested = true
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { ok, _ in
            permissionGranted = ok
        }
    }

    static func send(title: String, body: String) {
        requestPermissionIfNeeded()
        // 异步先试 UN，如果没权限再用 osascript 兜底
        UNUserNotificationCenter.current().getNotificationSettings { setting in
            if setting.authorizationStatus == .authorized || setting.authorizationStatus == .provisional {
                let content = UNMutableNotificationContent()
                content.title = title
                content.body = body
                content.sound = .default
                let req = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
                UNUserNotificationCenter.current().add(req, withCompletionHandler: nil)
            } else {
                osascriptFallback(title: title, body: body)
            }
        }
    }

    private static func osascriptFallback(title: String, body: String) {
        let t = escape(title), b = escape(body)
        DispatchQueue.global(qos: .utility).async {
            let p = Process()
            p.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
            p.arguments = ["-e", "display notification \"\(b)\" with title \"\(t)\""]
            try? p.run()
        }
    }
    private static func escape(_ s: String) -> String {
        s.replacingOccurrences(of: "\\", with: "\\\\")
         .replacingOccurrences(of: "\"", with: "\\\"")
    }
}
