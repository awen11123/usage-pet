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
    private let scale: CGFloat
    var onRightClick: ((NSEvent) -> Void)?
    var onHoverChange: ((Bool) -> Void)?

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
        frames[frameIndex].draw(in: bounds)
    }

    override func mouseDown(with event: NSEvent) {
        window?.performDrag(with: event)   // 拖动整个面板
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
    let scale: CGFloat = 6
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

        let side = 16 * scale
        panel = PetPanel(size: NSSize(width: side, height: side))
        petView = PetView(skin: currentSkin, scale: scale)
        panel.contentView = petView

        bubble = BubblePanel()

        petView.onRightClick = { [weak self] e in self?.showMenu(e) }
        petView.onHoverChange = { [weak self] hovering in self?.toggleBubble(hovering) }

        // 放到屏幕右下角
        if let vf = NSScreen.main?.visibleFrame {
            panel.setFrameOrigin(NSPoint(x: vf.maxX - side - 40, y: vf.minY + 60))
        }
        panel.orderFront(nil)

        if isClaude { ensureWeb() }
        startRefreshing()
    }

    func ensureWeb() { if web == nil { web = ClaudeWeb() } }

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
            RelayAPI.fetch(acc) { [weak self] result in
                DispatchQueue.main.async {
                    guard let self = self else { return }
                    switch result {
                    case .success(let snap): self.relayErrors[acc.id] = nil; self.relaySnaps[acc.id] = snap
                    case .failure(let err):  self.relayErrors[acc.id] = err.localizedDescription
                    }
                    self.updateMood(); self.refreshBubbleIfVisible()
                }
            }
        }
    }

    /// 心情取当前数据源的用量
    func updateMood() {
        var v: Double = 0
        if isClaude { v = snapshot?.maxUtilization ?? 0 }
        else if isCodex { v = codexSnap?.maxUtilization ?? 0 }
        else if let acc = activeRelay { v = relaySnaps[acc.id]?.usedPercent ?? 0 }
        petView.setMood(Mood.from(utilization: v))
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
    private func bar(_ v: Double) -> String {
        let n = max(0, min(10, Int((v / 100.0 * 10).rounded())))
        return String(repeating: "█", count: n) + String(repeating: "░", count: 10 - n)
    }
    func bubbleText() -> String {
        let title: String, lines: [String]
        if isClaude {
            var t = "Claude"
            if let m = ModelInfo.claude() { t += " · \(ModelInfo.pretty(m))" }
            title = t; lines = claudeLines()
        } else if isCodex {
            var t = "Codex"
            if let m = ModelInfo.codex() { t += " · \(ModelInfo.pretty(m))" }
            title = t; lines = codexLines()
        } else if let acc = activeRelay {
            title = acc.name; lines = relayLines(acc)
        } else {
            return "未选择数据源\n右键 → 数据源"
        }
        return ([title] + lines).joined(separator: "\n")
    }

    private func claudeLines() -> [String] {
        if let e = lastError { return ["⚠️ \(e)"] }
        guard let s = snapshot else { return ["加载中…"] }
        var l = ["5小时 \(bar(s.fiveHour)) \(Int(s.fiveHour))%",
                 "7天   \(bar(s.sevenDay)) \(Int(s.sevenDay))%"]
        if let o = s.opus    { l.append("Opus  \(bar(o)) \(Int(o))%") }
        if let so = s.sonnet { l.append("Sonn. \(bar(so)) \(Int(so))%") }
        if let r = countdown(fromISO: s.fiveHourResets) { l.append("重置 \(r)") }
        return l
    }
    private func codexLines() -> [String] {
        guard let s = codexSnap else { return [codexError ?? "加载中…"] }
        var l: [String] = []
        if let f = s.fiveHour { l.append("5小时 \(bar(f)) \(Int(f))%") }
        if let w = s.weekly   { l.append("周    \(bar(w)) \(Int(w))%") }
        if let r = countdown(date: s.fiveHourResets) { l.append("重置 \(r)") }
        return l.isEmpty ? ["无数据"] : l
    }
    private func relayLines(_ acc: RelayAccount) -> [String] {
        if let e = relayErrors[acc.id] { return ["⚠️ \(e)"] }
        guard let s = relaySnaps[acc.id] else { return ["加载中…"] }
        func money(_ v: Double) -> String { String(format: "%.2f", v) }
        var l: [String] = []
        if let u = s.usedPercent { l.append("用量 \(bar(u)) \(Int(u))%") }
        if let r = s.remaining, let t = s.total {
            l.append("余 $\(money(r)) / $\(money(t))")
        } else if let u = s.used {
            l.append("已用 $\(money(u))")
        }
        return l.isEmpty ? ["无数据"] : l
    }

    private func countdown(fromISO iso: String?) -> String? {
        guard let iso = iso else { return nil }
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let d = f.date(from: iso) ?? ISO8601DateFormatter().date(from: iso)
        return countdown(date: d)
    }
    private func countdown(date: Date?) -> String? {
        guard let d = date else { return nil }
        let secs = d.timeIntervalSinceNow
        if secs <= 0 { return "即将刷新" }
        let h = Int(secs) / 3600, m = (Int(secs) % 3600) / 60
        return h > 0 ? "\(h)小时\(m)分后" : "\(m)分后"
    }

    // MARK: 右键菜单
    func showMenu(_ event: NSEvent) {
        let menu = NSMenu()
        menu.addItem(withTitle: "立即刷新", action: #selector(menuRefresh), keyEquivalent: "r").target = self

        // 换形象 子菜单
        let skinItem = NSMenuItem(title: "换形象", action: nil, keyEquivalent: "")
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

        // 数据源 子菜单(单选)
        let srcItem = NSMenuItem(title: "数据源", action: nil, keyEquivalent: "")
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
        srcMenu.addItem(withTitle: "添加中转 API…", action: #selector(menuAddRelay), keyEquivalent: "").target = self
        if !relayAccounts.isEmpty {
            let delItem = NSMenuItem(title: "删除中转 API", action: nil, keyEquivalent: "")
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

        menu.addItem(withTitle: "登录 / 重新登录 Claude…", action: #selector(menuLogin), keyEquivalent: "l").target = self
        let autoTitle = (SMAppService.mainApp.status == .enabled) ? "✓ 开机自启动" : "开机自启动"
        menu.addItem(withTitle: autoTitle, action: #selector(menuToggleAutoStart), keyEquivalent: "").target = self
        menu.addItem(.separator())
        menu.addItem(withTitle: "退出", action: #selector(menuQuit), keyEquivalent: "q").target = self
        NSMenu.popUpContextMenu(menu, with: event, for: petView)
    }
    @objc func menuRefresh() { refresh() }
    @objc func menuLogin() { ensureWeb(); web?.showLogin() }
    private func switchSource(to id: String) {
        guard activeSource != id else { return }
        activeSource = id
        if id == "claude" { ensureWeb() }
        updateMood(); refreshBubbleIfVisible(); refresh()
    }
    @objc func menuPickClaude() { switchSource(to: "claude") }
    @objc func menuPickCodex()  { switchSource(to: "codex") }
    @objc func menuPickRelay(_ sender: NSMenuItem) {
        guard sender.tag < relayAccounts.count else { return }
        switchSource(to: relayAccounts[sender.tag].id)
    }
    @objc func menuAddRelay() {
        let alert = NSAlert()
        alert.messageText = "添加中转 API"
        alert.informativeText = "填写中转服务的名称、Base URL 和 API Key。\n会查询 /v1/dashboard/billing 接口显示余额。"
        alert.addButton(withTitle: "保存")
        alert.addButton(withTitle: "取消")
        let v = NSView(frame: NSRect(x: 0, y: 0, width: 320, height: 96))
        let name = NSTextField(frame: NSRect(x: 0, y: 66, width: 320, height: 24))
        name.placeholderString = "名称（如：我的中转）"
        let url = NSTextField(frame: NSRect(x: 0, y: 35, width: 320, height: 24))
        url.placeholderString = "Base URL（如 https://api.example.com）"
        let key = NSTextField(frame: NSRect(x: 0, y: 4, width: 320, height: 24))
        key.placeholderString = "API Key（sk-…）"
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
        relaySnaps[acc.id] = nil; relayErrors[acc.id] = nil
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
