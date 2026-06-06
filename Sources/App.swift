import Cocoa
import ServiceManagement

// MARK: - 悬浮面板(无边框、透明、置顶、可拖动)
final class PetPanel: NSPanel {
    var onMouseDown: (() -> Void)?
    var onMouseUp: (() -> Void)?

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
        isMovable = true
        // mouseDownCanMoveWindow 依赖此开关才生效
        isMovableByWindowBackground = true
    }
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    /// 在事件分发的最上层截获 mouseDown/Up：mouseDownCanMoveWindow 让
    /// 系统接管真正的拖动，但 view 的 mouseDown 就不再调用了——只有这里能
    /// 准确知道用户开始/结束拖动，从而暂停/恢复浮动。
    override func sendEvent(_ event: NSEvent) {
        switch event.type {
        case .leftMouseDown: onMouseDown?()
        case .leftMouseUp:   onMouseUp?()
        default: break
        }
        super.sendEvent(event)
    }
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
    private var activity: ActivityState = .idle
    private var bubbleAnimTimer: Timer?
    private var bubbleDotPhase: Int = 0   // 0/1/2 控制 "." ".." "..."
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

    private var savedActivityBeforeDrag: ActivityState?

    func pauseAnimDuringDrag() {
        // 停掉所有触发 needsDisplay 的定时器，避免拖动中频繁重绘导致抖动
        animTimer?.invalidate(); animTimer = nil
        bubbleAnimTimer?.invalidate(); bubbleAnimTimer = nil
        savedActivityBeforeDrag = activity
    }
    func resumeAnimDuringDrag() {}   // 兼容旧名字，无操作
    func resumeAnimAfterDrag() {
        restartAnimation()
        if let s = savedActivityBeforeDrag {
            activity = .idle      // 强制先重置，再 setActivity 才会启动思考定时器
            setActivity(s)
            savedActivityBeforeDrag = nil
        }
    }

    func setActivity(_ s: ActivityState) {
        guard s != activity else { return }
        activity = s
        // 思考状态下让 "..." 跳动
        bubbleAnimTimer?.invalidate()
        if s == .thinking {
            bubbleAnimTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
                guard let self = self else { return }
                self.bubbleDotPhase = (self.bubbleDotPhase + 1) % 3
                self.needsDisplay = true
            }
        }
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
        // 铺一层近透明的背景，让整个面板矩形都能接收点击(否则透明角落会穿透到桌面)
        NSColor(white: 0, alpha: 0.02).setFill()
        bounds.fill()
        // 卡通图自带投影与立体光照，直接绘制即可
        frames[frameIndex].draw(in: bounds, from: .zero, operation: .sourceOver,
                                fraction: offline ? 0.45 : 1.0)
        // 思考气泡(...) 显示在右上方
        if !offline && activity == .thinking { drawThinkingBubble() }
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

    /// 思考气泡：右上方圆角矩形 + 三个点(高对比度，在任何形象上都看得清)
    private func drawThinkingBubble() {
        let s = scale
        let bw = s * 4.6, bh = s * 2.4
        let bx = bounds.maxX - bw - s * 0.5
        let by = bounds.maxY - bh - s * 0.5
        let rect = NSRect(x: bx, y: by, width: bw, height: bh)
        // 深底白点：在所有毛色上都对比强烈
        let path = NSBezierPath(roundedRect: rect, xRadius: bh*0.5, yRadius: bh*0.5)
        NSColor(srgbRed: 0.10, green: 0.10, blue: 0.13, alpha: 0.94).setFill()
        path.fill()
        NSColor(srgbRed: 0.96, green: 0.96, blue: 0.98, alpha: 0.95).setStroke()
        path.lineWidth = max(1.2, s * 0.14)
        path.stroke()
        // 三个点(白色，按 phase 高亮)
        let dotR = s * 0.32
        let cy = rect.midY
        let xs = [rect.midX - dotR * 3, rect.midX, rect.midX + dotR * 3]
        for (i, x) in xs.enumerated() {
            let alpha: CGFloat = (i <= bubbleDotPhase) ? 1.0 : 0.30
            NSColor(white: 1.0, alpha: alpha).setFill()
            NSBezierPath(ovalIn: NSRect(x: x - dotR, y: cy - dotR, width: dotR*2, height: dotR*2)).fill()
        }
    }

    /// 告诉系统：点这个视图等于点窗口背景，让 macOS 接管拖动(完全无抖动)。
    override var mouseDownCanMoveWindow: Bool { true }

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
    /// 提醒阈值(warn%, crit%)
    var alertThresholds: (warn: Double, crit: Double) {
        get {
            let w = UserDefaults.standard.object(forKey: "warnPct") as? Double ?? 80
            let c = UserDefaults.standard.object(forKey: "critPct") as? Double ?? 95
            return (w, c)
        }
        set {
            UserDefaults.standard.set(newValue.warn, forKey: "warnPct")
            UserDefaults.standard.set(newValue.crit, forKey: "critPct")
        }
    }
    /// 刷新间隔(秒)，默认 300=5分钟
    var refreshInterval: TimeInterval {
        get { TimeInterval(UserDefaults.standard.object(forKey: "refreshSec") as? Int ?? 300) }
        set { UserDefaults.standard.set(Int(newValue), forKey: "refreshSec"); startRefreshing() }
    }
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
        // 拖动通过 PetView.mouseDownCanMoveWindow 让系统接管(完全无抖动)；
        // 在 panel 的 sendEvent 截获 mouseDown/Up 来暂停/恢复浮动定时器。
        panel.onMouseDown = { [weak self] in
            self?.bobTimer?.invalidate()
            self?.bobTimer = nil
            self?.bobPaused = true
            self?.petView.pauseAnimDuringDrag()
        }
        panel.onMouseUp = { [weak self] in
            guard let self = self else { return }
            self.petBase = self.panel.frame.origin
            self.bobPaused = false
            self.savePosition()
            self.startBob()
            self.petView.resumeAnimAfterDrag()
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
        // (垂直振幅, 周期, 水平随机抖动, 水平平滑摆动)
        let amp, period, hShake, hSway: Double
        switch activityState {
        case .thinking:
            // Claude 在思考：缓慢左右摇头 + 几乎不上下(像在沉思)
            amp = unit * 0.18; period = 1.1; hShake = 0; hSway = unit * 0.40
        case .working:
            // 你/工具在动作：快速点头 + 小幅左右抖
            amp = unit * 0.50; period = 0.40; hShake = unit * 0.15; hSway = 0
        case .justDone:
            // 刚结束：大幅度跳动(松口气)
            amp = unit * 0.95; period = 0.60; hShake = 0; hSway = 0
        case .idle:
            hShake = (currentMood == .panic) ? unit * 0.30 : 0
            hSway = 0
            switch currentMood {
            case .happy:   amp = unit * 0.6; period = 1.4
            case .neutral: amp = unit * 0.4; period = 2.2
            case .worried: amp = unit * 0.5; period = 1.3
            case .panic:   amp = unit * 0.7; period = 0.35
            }
        }
        let phase = t * 2 * .pi / period
        let dy = sin(phase) * amp
        let dxJit = hShake > 0 ? Double.random(in: -hShake...hShake) : 0
        let dxSway = hSway != 0 ? sin(phase + .pi/2) * hSway : 0
        panel.setFrameOrigin(NSPoint(x: petBase.x + dxJit + dxSway, y: petBase.y + dy))
    }

    /// 每 2 秒扫一次会话日志，缓存活动状态(避免 30Hz 命中文件系统)
    func startActivityWatch() {
        activityTimer?.invalidate()
        activityTimer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            let s = Activity.currentState()
            if s != self.activityState {
                self.activityState = s
                self.petView.setActivity(s)   // 触发思考气泡重绘
            }
        }
    }

    // MARK: 刷新
    func startRefreshing() {
        refresh()
        refreshTimer?.invalidate()
        refreshTimer = Timer.scheduledTimer(withTimeInterval: refreshInterval, repeats: true) { [weak self] _ in
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
                    case .success(let snap):
                        self.lastError = nil; self.snapshot = snap
                        History.record(source: "claude", h: snap.fiveHour, w: snap.sevenDay)
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
                    case .success(let snap):
                        self.codexError = nil; self.codexSnap = snap
                        History.record(source: "codex", h: snap.fiveHour ?? 0, w: snap.weekly ?? 0)
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
                        if let p = snap.usedPercent {
                            History.record(source: acc.id, h: p, w: snap.remaining ?? 0)
                        }
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
        let (warn, crit) = alertThresholds
        let lvl = thresholdLevel(util, warn: warn, crit: crit)
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

    private func claudeLines() -> [String] {
        if let e = lastError { return ["⚠️ \(e)"] }
        guard let s = snapshot else { return [L.t("loading")] }
        var l = ["\(L.t("w5h")) \(pct(s.fiveHour))",
                 "\(L.t("w7d")) \(pct(s.sevenDay))"]
        if let o = s.opus    { l.append("Opus  \(pct(o))") }
        if let so = s.sonnet { l.append("Sonn. \(pct(so))") }
        if let r = countdownISO(s.fiveHourResets) { l.append("\(L.t("reset")) \(r)") }
        if let sp = sparklineFor("claude") { l.append("7d \(sp)") }
        return l
    }
    private func codexLines() -> [String] {
        guard let s = codexSnap else { return [codexError ?? L.t("loading")] }
        var l: [String] = []
        if let f = s.fiveHour { l.append("\(L.t("w5h")) \(pct(f))") }
        if let w = s.weekly   { l.append("\(L.t("week")) \(pct(w))") }
        if let r = countdownDate(s.fiveHourResets) { l.append("\(L.t("reset")) \(r)") }
        if let sp = sparklineFor("codex") { l.append("7d \(sp)") }
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
        if let sp = sparklineFor(acc.id) { l.append("7d \(sp)") }
        return l.isEmpty ? [L.t("noData")] : l
    }

    /// 取该数据源的 sparkline 文本(7天)；样本太少返回 nil
    private func sparklineFor(_ source: String) -> String? {
        let samples = History.samples(source: source)
        guard samples.count >= 2 else { return nil }
        return Sparkline.text(samples.map { $0.h }, width: 12)
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

        // 提醒阈值 子菜单
        let thItem = NSMenuItem(title: L.t("threshold"), action: nil, keyEquivalent: "")
        let thMenu = NSMenu()
        let (curW, curC) = alertThresholds
        for (k, w, c) in [("th_strict", 60.0, 80.0), ("th_default", 80.0, 95.0), ("th_relax", 90.0, 98.0)] {
            let it = NSMenuItem(title: L.t(k), action: #selector(menuPickThreshold(_:)), keyEquivalent: "")
            it.target = self; it.representedObject = "\(w),\(c)"
            it.state = (abs(w - curW) < 0.1 && abs(c - curC) < 0.1) ? .on : .off
            thMenu.addItem(it)
        }
        thItem.submenu = thMenu
        menu.addItem(thItem)

        // 刷新间隔 子菜单
        let intItem = NSMenuItem(title: L.t("interval"), action: nil, keyEquivalent: "")
        let intMenu = NSMenu()
        for (k, sec) in [("i_1m", 60), ("i_3m", 180), ("i_5m", 300), ("i_15m", 900)] {
            let it = NSMenuItem(title: L.t(k), action: #selector(menuPickInterval(_:)), keyEquivalent: "")
            it.target = self; it.tag = sec
            it.state = (Int(refreshInterval) == sec) ? .on : .off
            intMenu.addItem(it)
        }
        intItem.submenu = intMenu
        menu.addItem(intItem)

        let autoTitle = (SMAppService.mainApp.status == .enabled) ? "✓ \(L.t("autostart"))" : L.t("autostart")
        menu.addItem(withTitle: autoTitle, action: #selector(menuToggleAutoStart), keyEquivalent: "").target = self
        menu.addItem(.separator())
        menu.addItem(withTitle: L.t("about"), action: #selector(menuAbout), keyEquivalent: "").target = self
        menu.addItem(withTitle: L.t("quit"), action: #selector(menuQuit), keyEquivalent: "q").target = self
        NSMenu.popUpContextMenu(menu, with: event, for: petView)
    }
    @objc func menuPickLang(_ sender: NSMenuItem) {
        if let code = sender.representedObject as? String { L.lang = code; refreshBubbleIfVisible() }
    }
    @objc func menuPickThreshold(_ sender: NSMenuItem) {
        guard let s = sender.representedObject as? String else { return }
        let parts = s.split(separator: ",").compactMap { Double($0) }
        if parts.count == 2 {
            alertThresholds = (parts[0], parts[1])
            // 重置通知等级，让下次重新评估
            notifyLevel.removeAll()
            updateMood(); refreshBubbleIfVisible()
        }
    }
    @objc func menuPickInterval(_ sender: NSMenuItem) {
        refreshInterval = TimeInterval(sender.tag)
    }
    @objc func menuAbout() {
        let a = NSAlert()
        a.messageText = L.t("aboutTitle")
        a.informativeText = L.t("aboutBody") + "\n\nhttps://github.com/awen11123/usage-pet"
        a.addButton(withTitle: L.t("openRepo"))
        a.addButton(withTitle: L.t("ok"))
        NSApp.activate(ignoringOtherApps: true)
        if a.runModal() == .alertFirstButtonReturn {
            NSWorkspace.shared.open(URL(string: "https://github.com/awen11123/usage-pet")!)
        }
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
