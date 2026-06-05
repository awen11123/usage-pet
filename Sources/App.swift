import Cocoa
import ServiceManagement

// MARK: - 悬浮面板(无边框、透明、置顶、可拖动)
final class PetPanel: NSPanel {
    init(size: NSSize) {
        super.init(contentRect: NSRect(origin: .zero, size: size),
                   styleMask: [.borderless, .nonactivatingPanel],
                   backing: .buffered, defer: false)
        level = .floating
        isFloatingPanel = true
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
        hidesOnDeactivate = false
        isMovableByWindowBackground = true
    }
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

// MARK: - 宠物视图
final class PetView: NSView {
    private var frames: [NSImage] = []
    private var frameIndex = 0
    private var animTimer: Timer?
    private var mood: Mood = .happy
    private var skin: Skin
    private var scale: CGFloat
    private var offline = false
    var onRightClick: ((NSEvent) -> Void)?
    var onHoverChange: ((Bool) -> Void)?
    var onMoved: (() -> Void)?
    var onDragStart: (() -> Void)?

    init(skin: Skin, scale: CGFloat) {
        self.skin = skin
        self.scale = scale
        super.init(frame: NSRect(x: 0, y: 0, width: 16 * scale, height: 16 * scale))
        wantsLayer = true
        reloadFrames()
        let area = NSTrackingArea(rect: bounds,
                                  options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
                                  owner: self, userInfo: nil)
        addTrackingArea(area)
    }
    required init?(coder: NSCoder) { fatalError() }

    func setMood(_ m: Mood) {
        guard m != mood || frames.isEmpty else { return }
        mood = m
        reloadFrames()
    }

    func setSkin(_ s: Skin) {
        skin = s
        reloadFrames()
    }

    func setScale(_ s: CGFloat) {
        guard s != scale else { return }
        scale = s
        setFrameSize(NSSize(width: 16 * s, height: 16 * s))
        reloadFrames()
    }

    func setOffline(_ off: Bool) {
        guard off != offline else { return }
        offline = off
        needsDisplay = true
    }

    private func reloadFrames() {
        frames = skin.frames(for: mood, scale: scale)
        frameIndex = 0
        restartAnimation()
        needsDisplay = true
    }

    private func restartAnimation() {
        animTimer?.invalidate()
        // 慌张时抖得更快
        let interval = (mood == .panic) ? 0.25 : 0.6
        animTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            guard let self = self, !self.frames.isEmpty else { return }
            self.frameIndex = (self.frameIndex + 1) % self.frames.count
            self.needsDisplay = true
        }
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard !frames.isEmpty else { return }
        // 卡通图自带投影与立体光照，直接绘制即可
        frames[frameIndex].draw(in: bounds, from: .zero, operation: .sourceOver,
                                fraction: offline ? 0.45 : 1.0)
        if offline {
            let s = scale * 5
            let badge = NSRect(x: bounds.maxX - s - scale, y: bounds.maxY - s - scale, width: s, height: s)
            NSColor(srgbRed: 0.90, green: 0.25, blue: 0.20, alpha: 1).setFill()
            NSBezierPath(ovalIn: badge).fill()
            let txt = "!" as NSString
            let attrs: [NSAttributedString.Key: Any] = [
                .font: NSFont.boldSystemFont(ofSize: s * 0.72),
                .foregroundColor: NSColor.white,
            ]
            let sz = txt.size(withAttributes: attrs)
            txt.draw(at: NSPoint(x: badge.midX - sz.width/2, y: badge.midY - sz.height/2), withAttributes: attrs)
        }
    }

    override func mouseDown(with event: NSEvent) {
        onDragStart?()                      // 暂停 bob，避免和拖动冲突
        window?.performDrag(with: event)   // performDrag 同步阻塞至拖动结束
        onMoved?()                          // 拖动结束后更新基点并保存
    }
    override func rightMouseDown(with event: NSEvent) { onRightClick?(event) }
    override func mouseEntered(with event: NSEvent) { onHoverChange?(true) }
    override func mouseExited(with event: NSEvent)  { onHoverChange?(false) }
}

// MARK: - 信息气泡(悬停时显示用量)
final class BubblePanel: NSPanel {
    private let label = NSTextField(labelWithString: "")
    init() {
        super.init(contentRect: NSRect(x: 0, y: 0, width: 160, height: 80),
                   styleMask: [.borderless, .nonactivatingPanel],
                   backing: .buffered, defer: false)
        level = .floating
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]

        let bg = NSVisualEffectView(frame: .zero)
        bg.material = .hudWindow
        bg.state = .active
        bg.wantsLayer = true
        bg.layer?.cornerRadius = 10
        bg.layer?.masksToBounds = true
        bg.translatesAutoresizingMaskIntoConstraints = false

        label.font = .monospacedSystemFont(ofSize: 11, weight: .medium)
        label.textColor = .white
        label.maximumNumberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false

        contentView = bg
        bg.addSubview(label)
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: bg.leadingAnchor, constant: 10),
            label.trailingAnchor.constraint(equalTo: bg.trailingAnchor, constant: -10),
            label.topAnchor.constraint(equalTo: bg.topAnchor, constant: 8),
            label.bottomAnchor.constraint(equalTo: bg.bottomAnchor, constant: -8),
        ])
    }
    override var canBecomeKey: Bool { false }

    func update(text: String) {
        label.stringValue = text
        label.sizeToFit()
        let w = max(150, label.frame.width + 24)
        let h = label.frame.height + 18
        setContentSize(NSSize(width: w, height: h))
    }
}

// MARK: - App
final class AppDelegate: NSObject, NSApplicationDelegate {
    var petScale: CGFloat {
        get { CGFloat(UserDefaults.standard.object(forKey: "petScale") as? Int ?? 6) }
        set { UserDefaults.standard.set(Int(newValue), forKey: "petScale") }
    }
    var panel: PetPanel!
    var petView: PetView!
    var bubble: BubblePanel!
    var snapshot: UsageSnapshot?
    var refreshTimer: Timer?
    var lastError: String?
    var web: ClaudeWeb?
    var codexSnap: CodexSnapshot?
    var codexError: String?
    var relayAccounts: [RelayAccount] = RelayStore.load()
    var relaySnaps: [String: RelaySnapshot] = [:]
    var relayErrors: [String: String] = [:]
    var relayProbeHint: [String: Int] = [:]   // 缓存上次成功的探测下标
    var notifyLevel: [String: Int] = [:]      // 各源上次通知到的阈值等级(边沿触发)
    var petBase: NSPoint = .zero              // 逻辑位置(拖动/缩放后更新；bob 不动它)
    var bobTimer: Timer?
    var bobStart = Date()
    var bobPaused = false
    var currentMood: Mood = .happy
    var activityState: ActivityState = .idle
    var activityTimer: Timer?
    var claudeModel: String?                  // 缓存当前模型，避免每次悬停扫盘
    var codexModel: String?
    var currentSkin: Skin = Skins.byId(UserDefaults.standard.string(forKey: "skinId") ?? "dog")

    // 当前唯一数据源："claude" / "codex" / 中转账户 id（默认 Claude）
    var activeSource: String {
        get { UserDefaults.standard.string(forKey: "activeSource") ?? "claude" }
        set { UserDefaults.standard.set(newValue, forKey: "activeSource") }
    }
    var isClaude: Bool { activeSource == "claude" }
    var isCodex: Bool { activeSource == "codex" }
    var activeRelay: RelayAccount? { relayAccounts.first { $0.id == activeSource } }

    func applicationDidFinishLaunching(_ note: Notification) {
        NSApp.setActivationPolicy(.accessory)   // 不在 Dock 显示

        let side = 16 * petScale
        panel = PetPanel(size: NSSize(width: side, height: side))
        petView = PetView(skin: currentSkin, scale: petScale)
        panel.contentView = petView

        bubble = BubblePanel()

        petView.onRightClick = { [weak self] e in self?.showMenu(e) }
        petView.onHoverChange = { [weak self] hovering in self?.toggleBubble(hovering) }
        petView.onDragStart = { [weak self] in self?.bobPaused = true }
        petView.onMoved = { [weak self] in
            guard let self = self else { return }
            self.petBase = self.panel.frame.origin   // 用户拖到哪儿，基点就在哪儿
            self.bobPaused = false
            self.savePosition()
        }

        // 恢复上次位置，没有则放屏幕右下角
        if let x = UserDefaults.standard.object(forKey: "petX") as? Double,
           let y = UserDefaults.standard.object(forKey: "petY") as? Double {
            petBase = NSPoint(x: x, y: y)
        } else if let vf = NSScreen.main?.visibleFrame {
            petBase = NSPoint(x: vf.maxX - side - 40, y: vf.minY + 60)
        }
        panel.setFrameOrigin(petBase)
        panel.orderFront(nil)
        startBob()
        startActivityWatch()

        if isClaude { ensureWeb() }
        startRefreshing()
    }

    func ensureWeb() { if web == nil { web = ClaudeWeb() } }

    func savePosition() {
        UserDefaults.standard.set(Double(petBase.x), forKey: "petX")
        UserDefaults.standard.set(Double(petBase.y), forKey: "petY")
    }

    /// 切换宠物大小(保持基点位置)
    func applyScale(_ s: Int) {
        petScale = CGFloat(s)
        petView.setScale(petScale)
        panel.setContentSize(NSSize(width: 16 * petScale, height: 16 * petScale))
        panel.setFrameOrigin(petBase)
        savePosition()
    }

    // MARK: 闲置浮动(让宠物「呼吸」)
    func startBob() {
        bobTimer?.invalidate()
        bobStart = Date()
        bobTimer = Timer.scheduledTimer(withTimeInterval: 1.0/30.0, repeats: true) { [weak self] _ in
            self?.tickBob()
        }
    }
    func tickBob() {
        guard !bobPaused else { return }
        let t = Date().timeIntervalSince(bobStart)
        let unit = Double(petScale)
        // 活动状态优先(working/justDone)，否则按心情节奏
        let (amp, period, shake): (Double, Double, Double)
        switch activityState {
        case .working:
            // 工作中：快速点头 + 小幅左右晃(像在认真打字)
            (amp, period, shake) = (unit * 0.45, 0.40, unit * 0.18)
        case .justDone:
            // 刚结束：大幅跳动(开心庆祝)
            (amp, period, shake) = (unit * 0.95, 0.60, 0)
        case .idle:
            switch currentMood {
            case .happy:   (amp, period, shake) = (unit * 0.6, 1.4, 0)
            case .neutral: (amp, period, shake) = (unit * 0.4, 2.2, 0)
            case .worried: (amp, period, shake) = (unit * 0.5, 1.3, 0)
            case .panic:   (amp, period, shake) = (unit * 0.7, 0.35, unit*0.3)
            }
        }
        let dy = sin(t * 2 * .pi / period) * amp
        let dx = shake > 0 ? Double.random(in: -shake...shake) : 0
        panel.setFrameOrigin(NSPoint(x: petBase.x + dx, y: petBase.y + dy))
    }

    /// 每 2 秒扫一次会话日志的修改时间，缓存活动状态(避免 30Hz 命中文件系统)
    func startActivityWatch() {
        activityTimer?.invalidate()
        activityTimer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
            self?.activityState = Activity.currentState()
        }
    }

    // MARK: 刷新
    func startRefreshing() {
        refresh()
        refreshTimer?.invalidate()
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { [weak self] _ in
            self?.refresh()
        }
    }

    /// 只刷新当前选中的那一个数据源
    func refresh() {
        if isClaude {
            ensureWeb()
            web?.fetchUsage { [weak self] result in
                DispatchQueue.main.async {
                    guard let self = self else { return }
                    switch result {
                    case .success(let snap): self.lastError = nil; self.snapshot = snap
                    case .failure(let err):  self.lastError = err.localizedDescription
                    }
                    self.updateMood(); self.refreshBubbleIfVisible()
                }
            }
        } else if isCodex {
            CodexUsage.fetch { [weak self] result in
                DispatchQueue.main.async {
                    guard let self = self else { return }
                    switch result {
                    case .success(let snap): self.codexError = nil; self.codexSnap = snap
                    case .failure(let err):  self.codexError = err.localizedDescription
                    }
                    self.updateMood(); self.refreshBubbleIfVisible()
                }
            }
        } else if let acc = activeRelay {
            RelayAPI.fetch(acc, preferred: relayProbeHint[acc.id]) { [weak self] result, idx in
                DispatchQueue.main.async {
                    guard let self = self else { return }
                    switch result {
                    case .success(let snap):
                        self.relayErrors[acc.id] = nil; self.relaySnaps[acc.id] = snap
                        if let idx = idx { self.relayProbeHint[acc.id] = idx }   // 记住命中的探测
                    case .failure(let err):
                        self.relayErrors[acc.id] = err.localizedDescription
                    }
                    self.updateMood(); self.refreshBubbleIfVisible()
                }
            }
        }
        refreshModel()
    }

    /// 后台读取当前模型并缓存(避免在主线程/每次悬停扫盘)
    func refreshModel() {
        DispatchQueue.global(qos: .utility).async { [weak self] in
            guard let self = self else { return }
            let cm = self.isClaude ? ModelInfo.claude() : nil
            let xm = self.isCodex ? ModelInfo.codex() : nil
            DispatchQueue.main.async {
                self.claudeModel = cm; self.codexModel = xm
                self.refreshBubbleIfVisible()
            }
        }
    }

    /// 心情取当前数据源的用量；同时更新「掉线」状态
    func updateMood() {
        var v: Double = 0
        var offline = false
        var label = "Claude"
        if isClaude { v = snapshot?.maxUtilization ?? 0; offline = (lastError != nil) }
        else if isCodex { v = codexSnap?.maxUtilization ?? 0; offline = (codexError != nil); label = "Codex" }
        else if let acc = activeRelay { v = relaySnaps[acc.id]?.usedPercent ?? 0; offline = (relayErrors[acc.id] != nil); label = acc.name }
        currentMood = Mood.from(utilization: v)
        petView.setMood(currentMood)
        petView.setOffline(offline)
        if !offline { checkNotify(util: v, label: label) }
    }

    /// 边沿触发的阈值通知：每次跨入更高档位只提醒一次，掉回后自动重新武装
    func checkNotify(util: Double, label: String) {
        let key = activeSource
        let lvl = thresholdLevel(util)
        let last = notifyLevel[key] ?? 0
        if lvl > last {
            let fmt = lvl >= 2 ? L.t("notifCrit") : L.t("notifWarn")
            Notifier.send(title: L.t("notifTitle"), body: String(format: fmt, label, Int(util)))
        }
        notifyLevel[key] = lvl
    }

    // MARK: 气泡
    func toggleBubble(_ show: Bool) {
        if show {
            bubble.update(text: bubbleText())
            positionBubble()
            bubble.orderFront(nil)
        } else {
            bubble.orderOut(nil)
        }
    }
    func refreshBubbleIfVisible() {
        if bubble.isVisible { bubble.update(text: bubbleText()); positionBubble() }
    }
    func positionBubble() {
        let pf = panel.frame
        let bf = bubble.frame
        let x = pf.midX - bf.width / 2
        let y = pf.maxY + 6
        bubble.setFrameOrigin(NSPoint(x: x, y: y))
    }
    func bubbleText() -> String {
        let title: String, lines: [String]
        if isClaude {
            var t = "Claude"
            if let m = claudeModel { t += " · \(ModelInfo.pretty(m))" }
            title = t; lines = claudeLines()
        } else if isCodex {
            var t = "Codex"
            if let m = codexModel { t += " · \(ModelInfo.pretty(m))" }
            title = t; lines = codexLines()
        } else if let acc = activeRelay {
            title = acc.name; lines = relayLines(acc)
        } else {
            return L.t("noSource")
        }
        return ([title] + lines).joined(separator: "\n")
    }

    private func pct(_ v: Double) -> String { "\(Fmt.bar(v)) \(Int(v))%" }

    private func forecastLine(util: Double, isoReset: String?, window: Double) -> String? {
        guard let secs = secondsUntilReset(iso: isoReset), secs > 0 else { return nil }
        switch Forecast.compute(util: util, secondsUntilReset: secs, windowSeconds: window) {
        case .projected(let p): return String(format: L.t("pace"), p)
        case .exhausted(let eta): return String(format: L.t("runout"), durationText(eta))
        case .none: return nil
        }
    }

    private func claudeLines() -> [String] {
        if let e = lastError { return ["⚠️ \(e)"] }
        guard let s = snapshot else { return [L.t("loading")] }
        var l = ["\(L.t("w5h")) \(pct(s.fiveHour))",
                 "\(L.t("w7d")) \(pct(s.sevenDay))"]
        if let o = s.opus    { l.append("Opus  \(pct(o))") }
        if let so = s.sonnet { l.append("Sonn. \(pct(so))") }
        if let f = forecastLine(util: s.sevenDay, isoReset: s.sevenDayResets, window: Window.sevenDay) {
            l.append("↗ \(f)")
        }
        if let r = countdownISO(s.fiveHourResets) { l.append("\(L.t("reset")) \(r)") }
        return l
    }
    private func codexLines() -> [String] {
        guard let s = codexSnap else { return [codexError ?? L.t("loading")] }
        var l: [String] = []
        if let f = s.fiveHour { l.append("\(L.t("w5h")) \(pct(f))") }
        if let w = s.weekly   { l.append("\(L.t("week")) \(pct(w))") }
        if let r = countdownDate(s.fiveHourResets) { l.append("\(L.t("reset")) \(r)") }
        return l.isEmpty ? [L.t("noData")] : l
    }
    private func relayLines(_ acc: RelayAccount) -> [String] {
        if let e = relayErrors[acc.id] { return ["⚠️ \(e)"] }
        guard let s = relaySnaps[acc.id] else { return [L.t("loading")] }
        let c = s.currency
        var l: [String] = []
        if let u = s.usedPercent { l.append("\(L.t("usage")) \(pct(u))") }
        if let r = s.remaining, let t = s.total {
            l.append("\(L.t("bal")) \(Fmt.money(r, c)) / \(Fmt.money(t, c))")
        } else if let r = s.remaining {
            l.append("\(L.t("balance")) \(Fmt.money(r, c))")
        } else if let u = s.used {
            l.append("\(L.t("used")) \(Fmt.money(u, c))")
        }
        return l.isEmpty ? [L.t("noData")] : l
    }

    private func secondsUntilReset(iso: String?) -> Double? {
        guard let iso = iso else { return nil }
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let d = f.date(from: iso) ?? ISO8601DateFormatter().date(from: iso)
        return d?.timeIntervalSinceNow
    }
    private func durationText(_ secs: Double) -> String {
        let (h, m) = Fmt.hm(secs)
        return h > 0 ? String(format: L.t("hm"), h, m) : String(format: L.t("m"), m)
    }
    private func countdownISO(_ iso: String?) -> String? {
        guard let secs = secondsUntilReset(iso: iso) else { return nil }
        return secs <= 0 ? L.t("soon") : durationText(secs)
    }
    private func countdownDate(_ date: Date?) -> String? {
        guard let d = date else { return nil }
        let secs = d.timeIntervalSinceNow
        return secs <= 0 ? L.t("soon") : durationText(secs)
    }

    // MARK: 右键菜单
    func showMenu(_ event: NSEvent) {
        let menu = NSMenu()
        menu.addItem(withTitle: L.t("refresh"), action: #selector(menuRefresh), keyEquivalent: "r").target = self

        // 换形象 子菜单
        let skinItem = NSMenuItem(title: L.t("skin"), action: nil, keyEquivalent: "")
        let skinMenu = NSMenu()
        for (i, s) in Skins.all.enumerated() {
            let it = NSMenuItem(title: s.name, action: #selector(menuPickSkin(_:)), keyEquivalent: "")
            it.target = self
            it.tag = i
            it.state = (s.id == currentSkin.id) ? .on : .off
            skinMenu.addItem(it)
        }
        skinItem.submenu = skinMenu
        menu.addItem(skinItem)

        // 大小 子菜单
        let sizeItem = NSMenuItem(title: L.t("size"), action: nil, keyEquivalent: "")
        let sizeMenu = NSMenu()
        for (key, val) in [("size_l", 8), ("size_m", 6), ("size_s", 4)] {
            let it = NSMenuItem(title: L.t(key), action: #selector(menuPickSize(_:)), keyEquivalent: "")
            it.target = self; it.tag = val
            it.state = (Int(petScale) == val) ? .on : .off
            sizeMenu.addItem(it)
        }
        sizeItem.submenu = sizeMenu
        menu.addItem(sizeItem)

        // 数据源 子菜单(单选)
        let srcItem = NSMenuItem(title: L.t("source"), action: nil, keyEquivalent: "")
        let srcMenu = NSMenu()
        let cl = NSMenuItem(title: "Claude", action: #selector(menuPickClaude), keyEquivalent: "")
        cl.target = self; cl.state = isClaude ? .on : .off
        let cx = NSMenuItem(title: "Codex", action: #selector(menuPickCodex), keyEquivalent: "")
        cx.target = self; cx.state = isCodex ? .on : .off
        srcMenu.addItem(cl); srcMenu.addItem(cx)
        if !relayAccounts.isEmpty {
            srcMenu.addItem(.separator())
            for (i, acc) in relayAccounts.enumerated() {
                let it = NSMenuItem(title: acc.name, action: #selector(menuPickRelay(_:)), keyEquivalent: "")
                it.target = self; it.tag = i
                it.state = (activeSource == acc.id) ? .on : .off
                srcMenu.addItem(it)
            }
        }
        srcMenu.addItem(.separator())
        srcMenu.addItem(withTitle: L.t("addRelay"), action: #selector(menuAddRelay), keyEquivalent: "").target = self
        if !relayAccounts.isEmpty {
            let delItem = NSMenuItem(title: L.t("delRelay"), action: nil, keyEquivalent: "")
            let delMenu = NSMenu()
            for (i, acc) in relayAccounts.enumerated() {
                let it = NSMenuItem(title: acc.name, action: #selector(menuRemoveRelay(_:)), keyEquivalent: "")
                it.target = self; it.tag = i
                delMenu.addItem(it)
            }
            delItem.submenu = delMenu
            srcMenu.addItem(delItem)
        }
        srcItem.submenu = srcMenu
        menu.addItem(srcItem)

        menu.addItem(withTitle: L.t("login"), action: #selector(menuLogin), keyEquivalent: "l").target = self

        // 语言 子菜单
        let langItem = NSMenuItem(title: L.t("language"), action: nil, keyEquivalent: "")
        let langMenu = NSMenu()
        for (code, label) in [("auto", L.t("lang_auto")), ("zh", "中文"), ("en", "English")] {
            let it = NSMenuItem(title: label, action: #selector(menuPickLang(_:)), keyEquivalent: "")
            it.target = self; it.representedObject = code
            it.state = (L.lang == code) ? .on : .off
            langMenu.addItem(it)
        }
        langItem.submenu = langMenu
        menu.addItem(langItem)

        let autoTitle = (SMAppService.mainApp.status == .enabled) ? "✓ \(L.t("autostart"))" : L.t("autostart")
        menu.addItem(withTitle: autoTitle, action: #selector(menuToggleAutoStart), keyEquivalent: "").target = self
        menu.addItem(.separator())
        menu.addItem(withTitle: L.t("quit"), action: #selector(menuQuit), keyEquivalent: "q").target = self
        NSMenu.popUpContextMenu(menu, with: event, for: petView)
    }
    @objc func menuPickLang(_ sender: NSMenuItem) {
        if let code = sender.representedObject as? String { L.lang = code; refreshBubbleIfVisible() }
    }
    @objc func menuRefresh() { refresh() }
    @objc func menuLogin() { ensureWeb(); web?.showLogin() }
    private func switchSource(to id: String) {
        guard activeSource != id else { return }
        activeSource = id
        if id == "claude" { ensureWeb() }
        updateMood(); refreshBubbleIfVisible(); refresh()
    }
    @objc func menuPickSize(_ sender: NSMenuItem) { applyScale(sender.tag) }
    @objc func menuPickClaude() { switchSource(to: "claude") }
    @objc func menuPickCodex()  { switchSource(to: "codex") }
    @objc func menuPickRelay(_ sender: NSMenuItem) {
        guard sender.tag < relayAccounts.count else { return }
        switchSource(to: relayAccounts[sender.tag].id)
    }
    @objc func menuAddRelay() {
        let alert = NSAlert()
        alert.messageText = L.t("relayTitle")
        alert.informativeText = L.t("relayInfo")
        alert.addButton(withTitle: L.t("save"))
        alert.addButton(withTitle: L.t("cancel"))
        let v = NSView(frame: NSRect(x: 0, y: 0, width: 320, height: 96))
        let name = NSTextField(frame: NSRect(x: 0, y: 66, width: 320, height: 24))
        name.placeholderString = L.t("relayName")
        let url = NSTextField(frame: NSRect(x: 0, y: 35, width: 320, height: 24))
        url.placeholderString = L.t("relayURL")
        let key = NSTextField(frame: NSRect(x: 0, y: 4, width: 320, height: 24))
        key.placeholderString = L.t("relayKey")
        v.addSubview(name); v.addSubview(url); v.addSubview(key)
        alert.accessoryView = v
        NSApp.activate(ignoringOtherApps: true)
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        let n = name.stringValue.trimmingCharacters(in: .whitespaces)
        let u = url.stringValue.trimmingCharacters(in: .whitespaces)
        let k = key.stringValue.trimmingCharacters(in: .whitespaces)
        guard !n.isEmpty, !u.isEmpty, !k.isEmpty else { return }
        let acc = RelayAccount(name: n, baseURL: u, apiKey: k)
        relayAccounts.append(acc)
        RelayStore.save(relayAccounts)
        switchSource(to: acc.id)   // 添加后自动切到它
    }
    @objc func menuRemoveRelay(_ sender: NSMenuItem) {
        guard sender.tag < relayAccounts.count else { return }
        let acc = relayAccounts.remove(at: sender.tag)
        relaySnaps[acc.id] = nil; relayErrors[acc.id] = nil; relayProbeHint[acc.id] = nil
        RelayStore.remove(acc)        // 删除钥匙串里的 key
        RelayStore.save(relayAccounts)
        if activeSource == acc.id { switchSource(to: "claude") }   // 删的是当前源则回退
        else { refreshBubbleIfVisible() }
    }
    @objc func menuPickSkin(_ sender: NSMenuItem) {
        let s = Skins.all[sender.tag]
        currentSkin = s
        petView.setSkin(s)
        UserDefaults.standard.set(s.id, forKey: "skinId")
    }
    @objc func menuToggleAutoStart() {
        do {
            if SMAppService.mainApp.status == .enabled {
                try SMAppService.mainApp.unregister()
            } else {
                try SMAppService.mainApp.register()
            }
        } catch {
            let a = NSAlert()
            a.messageText = "设置开机自启失败"
            a.informativeText = error.localizedDescription
            a.runModal()
        }
    }
    @objc func menuQuit() { NSApp.terminate(nil) }
}
