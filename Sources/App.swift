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
    var currentSkin: Skin = Skins.byId(UserDefaults.standard.string(forKey: "skinId") ?? "dog")

    // 数据源开关(默认只开 Claude)
    var claudeEnabled: Bool {
        get { UserDefaults.standard.object(forKey: "claudeEnabled") as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: "claudeEnabled") }
    }
    var codexEnabled: Bool {
        get { UserDefaults.standard.object(forKey: "codexEnabled") as? Bool ?? false }
        set { UserDefaults.standard.set(newValue, forKey: "codexEnabled") }
    }

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

        if claudeEnabled { ensureWeb() }
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

    func refresh() {
        if claudeEnabled {
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
        }
        if codexEnabled {
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
        }
    }

    /// 心情取已启用数据源中最紧张的用量
    func updateMood() {
        var vals: [Double] = []
        if claudeEnabled, let s = snapshot   { vals.append(s.maxUtilization) }
        if codexEnabled,  let s = codexSnap  { vals.append(s.maxUtilization) }
        petView.setMood(Mood.from(utilization: vals.max() ?? 0))
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
        if !claudeEnabled && !codexEnabled { return "未启用数据源\n右键 → 数据源" }
        let both = claudeEnabled && codexEnabled
        let pad = both ? "  " : ""        // 双数据源时缩进并加标题
        var lines: [String] = []

        if claudeEnabled {
            if both { lines.append("◆ Claude") }
            if let e = lastError {
                lines.append("\(pad)⚠️ \(e)")
            } else if let s = snapshot {
                lines.append("\(pad)5小时 \(bar(s.fiveHour)) \(Int(s.fiveHour))%")
                lines.append("\(pad)7天   \(bar(s.sevenDay)) \(Int(s.sevenDay))%")
                if let o = s.opus    { lines.append("\(pad)Opus  \(bar(o)) \(Int(o))%") }
                if let so = s.sonnet { lines.append("\(pad)Sonn. \(bar(so)) \(Int(so))%") }
                if let r = countdown(fromISO: s.fiveHourResets) { lines.append("\(pad)重置 \(r)") }
            } else {
                lines.append("\(pad)加载中…")
            }
        }

        if codexEnabled {
            if both { lines.append(""); lines.append("◆ Codex") }
            if let s = codexSnap {
                if let f = s.fiveHour { lines.append("\(pad)5小时 \(bar(f)) \(Int(f))%") }
                if let w = s.weekly   { lines.append("\(pad)周    \(bar(w)) \(Int(w))%") }
                if let r = countdown(date: s.fiveHourResets) { lines.append("\(pad)重置 \(r)") }
            } else {
                lines.append("\(pad)\(codexError ?? "加载中…")")
            }
        }

        return lines.joined(separator: "\n")
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

        // 数据源 子菜单
        let srcItem = NSMenuItem(title: "数据源", action: nil, keyEquivalent: "")
        let srcMenu = NSMenu()
        let cl = NSMenuItem(title: "Claude", action: #selector(menuToggleClaude), keyEquivalent: "")
        cl.target = self; cl.state = claudeEnabled ? .on : .off
        let cx = NSMenuItem(title: "Codex", action: #selector(menuToggleCodex), keyEquivalent: "")
        cx.target = self; cx.state = codexEnabled ? .on : .off
        srcMenu.addItem(cl); srcMenu.addItem(cx)
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
    @objc func menuToggleClaude() {
        claudeEnabled.toggle()
        if !claudeEnabled { snapshot = nil; lastError = nil }
        refresh(); updateMood(); refreshBubbleIfVisible()
    }
    @objc func menuToggleCodex() {
        codexEnabled.toggle()
        if !codexEnabled { codexSnap = nil; codexError = nil }
        refresh(); updateMood(); refreshBubbleIfVisible()
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
