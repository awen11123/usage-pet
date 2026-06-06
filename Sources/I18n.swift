import Foundation

/// 轻量本地化。语言偏好存 UserDefaults "lang"：auto / zh / en。
enum L {
    static var lang: String {
        get { UserDefaults.standard.string(forKey: "lang") ?? "auto" }
        set { UserDefaults.standard.set(newValue, forKey: "lang") }
    }
    /// 实际生效语言
    static var effective: String {
        if lang == "zh" || lang == "en" { return lang }
        let pref = Locale.preferredLanguages.first ?? "en"
        return pref.hasPrefix("zh") ? "zh" : "en"
    }
    static var isZH: Bool { effective == "zh" }

    static func t(_ key: String) -> String {
        let row = table[key]
        return (isZH ? row?.0 : row?.1) ?? key
    }

    // key: (中文, English)
    private static let table: [String: (String, String)] = [
        // 菜单
        "refresh":    ("立即刷新", "Refresh now"),
        "skin":       ("换形象", "Skin"),
        "size":       ("大小", "Size"),
        "size_l":     ("大", "Large"),
        "size_m":     ("中", "Medium"),
        "size_s":     ("小", "Small"),
        "source":     ("数据源", "Source"),
        "addRelay":   ("添加中转 API…", "Add relay API…"),
        "delRelay":   ("删除中转 API", "Remove relay API"),
        "login":      ("登录 / 重新登录 Claude…", "Log in / re-login to Claude…"),
        "autostart":  ("开机自启动", "Launch at login"),
        "language":   ("语言", "Language"),
        "lang_auto":  ("自动", "Auto"),
        "quit":       ("退出", "Quit"),
        "threshold":  ("提醒阈值", "Alert thresholds"),
        "th_strict":  ("严格 60/80%", "Strict 60/80%"),
        "th_default": ("默认 80/95%", "Default 80/95%"),
        "th_relax":   ("宽松 90/98%", "Relaxed 90/98%"),
        "interval":   ("刷新间隔", "Refresh interval"),
        "i_1m":       ("1 分钟", "1 minute"),
        "i_3m":       ("3 分钟", "3 minutes"),
        "i_5m":       ("5 分钟", "5 minutes"),
        "i_15m":      ("15 分钟", "15 minutes"),
        "about":      ("关于…", "About…"),
        "aboutTitle": ("Usage Pet", "Usage Pet"),
        "aboutBody":  ("桌面像素宠物，实时显示 Claude / Codex / 中转 API 用量。\nMIT 开源 © awen",
                       "Floating desktop pet that shows Claude / Codex / relay API usage in real time.\nMIT © awen"),
        "openRepo":   ("打开 GitHub 仓库", "Open GitHub repo"),
        "ok":         ("好", "OK"),
        // 气泡
        "w5h":        ("5小时", "5h"),
        "w7d":        ("7天", "7d"),
        "week":       ("周", "Week"),
        "reset":      ("重置", "Resets"),
        "loading":    ("加载中…", "Loading…"),
        "usage":      ("用量", "Usage"),
        "bal":        ("余", "Bal"),
        "balance":    ("余额", "Balance"),
        "used":       ("已用", "Used"),
        "noData":     ("无数据", "No data"),
        "noSource":   ("未选择数据源\n右键 → 数据源", "No source\nRight-click → Source"),
        "soon":       ("即将刷新", "soon"),
        // 预测
        "pace":       ("照此速度 %d%%", "At this pace: %d%%"),
        "runout":     ("约 %@ 后用尽", "Runs out in ~%@"),
        // 添加中转弹窗
        "relayTitle": ("添加中转 API", "Add relay API"),
        "relayInfo":  ("填写名称、Base URL 和 API Key，自动探测余额接口。",
                       "Enter name, Base URL and API Key — balance endpoint is auto-detected."),
        "relayName":  ("名称（如：我的中转）", "Name (e.g. My relay)"),
        "relayURL":   ("Base URL（如 https://api.example.com）", "Base URL (e.g. https://api.example.com)"),
        "relayKey":   ("API Key（sk-…）", "API Key (sk-…)"),
        "save":       ("保存", "Save"),
        "cancel":     ("取消", "Cancel"),
        // 通知
        "notifTitle": ("用量提醒", "Usage alert"),
        "notifWarn":  ("%@ 已用 %d%%，注意节制", "%@ at %d%% — slow down"),
        "notifCrit":  ("%@ 已用 %d%%，即将到限！", "%@ at %d%% — almost out!"),
        // 时长
        "hm":         ("%d小时%d分后", "%dh %dm"),
        "m":          ("%d分后", "%dm"),
    ]
}
