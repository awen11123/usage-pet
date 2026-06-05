import Cocoa

// MARK: - 心情(由用量百分比决定)
enum Mood: Int {
    case happy, neutral, worried, panic
    static func from(utilization: Double) -> Mood {
        switch utilization {
        case ..<50:  return .happy
        case ..<80:  return .neutral
        case ..<95:  return .worried
        default:     return .panic
        }
    }
}

// MARK: - 卡通配色
struct CartoonColors {
    let body: NSColor       // 主体
    let bodyDk: NSColor     // 主体暗部
    let ear: NSColor        // 耳朵
    let earDk: NSColor      // 耳朵暗部
    let outline: NSColor    // 描边
    let accent: NSColor     // 舌/重点色
    let cheek: NSColor      // 腮红
    let eyeMain: NSColor    // 眼睛主色(深色)
    let eyeShine: NSColor   // 眼睛高光(通常白)
}

enum EarStyle {
    case floppy    // 垂耳(狗)
    case triangle  // 三角立耳(猫)
    case longUp    // 长立耳(兔)
    case horn      // 独角(怪兽)
}

// MARK: - 形象(整合配色 + 耳型)
struct Skin {
    let id: String
    let name: String
    let colors: CartoonColors
    let ears: EarStyle
    func frames(for mood: Mood, scale: CGFloat) -> [NSImage] {
        let side = 16 * scale   // 跟原来面板大小保持一致
        return [0, 1].map { CartoonRenderer.image(skin: self, mood: mood, frame: $0, size: side) }
    }
}

// MARK: - 6 个形象
enum Skins {
    static let all: [Skin] = [dog, orangeCat, blackCat, creamCat, rabbit, monster]
    static func byId(_ id: String) -> Skin { all.first { $0.id == id } ?? dog }

    static let dog = Skin(id: "dog", name: "🐶 奶白小狗",
        colors: .creamWithGreyEars, ears: .floppy)
    static let orangeCat = Skin(id: "ocat", name: "🐱 橘猫",
        colors: .orange, ears: .triangle)
    static let blackCat = Skin(id: "bcat", name: "🐈‍⬛ 黑猫",
        colors: .black, ears: .triangle)
    static let creamCat = Skin(id: "ccat", name: "🐱 奶白猫",
        colors: .creamPlain, ears: .triangle)
    static let rabbit = Skin(id: "rabbit", name: "🐰 小兔",
        colors: .rabbit, ears: .longUp)
    static let monster = Skin(id: "monster", name: "👾 小怪兽",
        colors: .monster, ears: .horn)
}

private func rgb(_ r: Double, _ g: Double, _ b: Double) -> NSColor {
    NSColor(srgbRed: r, green: g, blue: b, alpha: 1)
}

extension CartoonColors {
    static let creamWithGreyEars = CartoonColors(
        body: rgb(0.97,0.94,0.86), bodyDk: rgb(0.85,0.81,0.72),
        ear:  rgb(0.62,0.60,0.57), earDk:  rgb(0.50,0.48,0.46),
        outline: rgb(0.20,0.18,0.18), accent: rgb(0.97,0.65,0.68),
        cheek: NSColor(srgbRed: 1.0, green: 0.78, blue: 0.78, alpha: 0.85),
        eyeMain: rgb(0.15,0.13,0.12), eyeShine: .white)
    static let creamPlain = CartoonColors(
        body: rgb(0.97,0.95,0.88), bodyDk: rgb(0.86,0.83,0.74),
        ear:  rgb(0.94,0.92,0.84), earDk:  rgb(0.82,0.79,0.71),
        outline: rgb(0.22,0.20,0.20), accent: rgb(0.95,0.62,0.62),
        cheek: NSColor(srgbRed: 1.0, green: 0.78, blue: 0.78, alpha: 0.85),
        eyeMain: rgb(0.15,0.13,0.12), eyeShine: .white)
    static let orange = CartoonColors(
        body: rgb(0.93,0.55,0.32), bodyDk: rgb(0.80,0.42,0.22),
        ear:  rgb(0.93,0.55,0.32), earDk:  rgb(0.80,0.42,0.22),
        outline: rgb(0.30,0.16,0.10), accent: rgb(0.97,0.65,0.68),
        cheek: NSColor(srgbRed: 1.0, green: 0.55, blue: 0.55, alpha: 0.55),
        eyeMain: rgb(0.10,0.08,0.06), eyeShine: .white)
    static let black = CartoonColors(
        body: rgb(0.18,0.18,0.21), bodyDk: rgb(0.10,0.10,0.12),
        ear:  rgb(0.18,0.18,0.21), earDk:  rgb(0.10,0.10,0.12),
        outline: rgb(0.05,0.05,0.06), accent: rgb(0.95,0.45,0.55),
        cheek: NSColor(srgbRed: 0.95, green: 0.45, blue: 0.55, alpha: 0.45),
        eyeMain: rgb(0.55,0.85,0.45),                            // 黑猫绿眼
        eyeShine: .white)
    static let rabbit = CartoonColors(
        body: rgb(0.98,0.96,0.94), bodyDk: rgb(0.86,0.84,0.83),
        ear:  rgb(0.98,0.96,0.94), earDk:  rgb(0.95,0.62,0.66),  // 兔耳内粉
        outline: rgb(0.32,0.28,0.30), accent: rgb(0.95,0.62,0.66),
        cheek: NSColor(srgbRed: 1.0, green: 0.78, blue: 0.82, alpha: 0.75),
        eyeMain: rgb(0.20,0.16,0.18), eyeShine: .white)
    static let monster = CartoonColors(
        body: rgb(0.62,0.50,0.86), bodyDk: rgb(0.48,0.36,0.72),
        ear:  rgb(0.62,0.50,0.86), earDk:  rgb(0.48,0.36,0.72),
        outline: rgb(0.22,0.16,0.34), accent: rgb(0.95,0.62,0.72),
        cheek: NSColor(srgbRed: 1.0, green: 0.65, blue: 0.75, alpha: 0.60),
        eyeMain: rgb(0.12,0.10,0.16), eyeShine: .white)
}

// MARK: - 渲染器
enum CartoonRenderer {
    static func image(skin: Skin, mood: Mood, frame: Int, size: CGFloat) -> NSImage {
        let img = NSImage(size: NSSize(width: size, height: size))
        img.lockFocus()
        let c = skin.colors
        let lw = max(2, size * 0.022)
        // 工具
        func setStroke() { c.outline.setStroke() }
        func stroke(_ p: NSBezierPath, _ width: CGFloat = 0) {
            setStroke(); p.lineWidth = width > 0 ? width : lw; p.stroke()
        }
        // 投影
        NSColor.black.withAlphaComponent(0.22).setFill()
        NSBezierPath(ovalIn: NSRect(x: size*0.20, y: size*0.03, width: size*0.60, height: size*0.07)).fill()

        // 身体
        let bodyRect = NSRect(x: size*0.22, y: size*0.08, width: size*0.56, height: size*0.46)
        let bp = NSBezierPath(roundedRect: bodyRect, xRadius: size*0.18, yRadius: size*0.18)
        c.body.setFill(); bp.fill()
        NSGraphicsContext.current!.saveGraphicsState()
        bp.addClip(); c.bodyDk.setFill()
        NSBezierPath(rect: NSRect(x: 0, y: size*0.08, width: size, height: size*0.14)).fill()
        NSGraphicsContext.current!.restoreGraphicsState()
        stroke(bp)

        // 爪子
        for x in [size*0.30, size*0.58] {
            let p = NSBezierPath(ovalIn: NSRect(x: x, y: size*0.05, width: size*0.12, height: size*0.08))
            c.body.setFill(); p.fill(); stroke(p)
        }

        // 耳朵
        drawEars(style: skin.ears, c: c, size: size, stroke: stroke)

        // 头
        let headRect = NSRect(x: size*0.18, y: size*0.36, width: size*0.64, height: size*0.50)
        let head = NSBezierPath(ovalIn: headRect)
        c.body.setFill(); head.fill()
        NSGraphicsContext.current!.saveGraphicsState()
        head.addClip()
        // 头顶高光
        NSColor.white.withAlphaComponent(0.32).setFill()
        NSBezierPath(ovalIn: NSRect(x: size*0.26, y: size*0.72, width: size*0.30, height: size*0.13)).fill()
        // 头下沿暗部
        c.bodyDk.withAlphaComponent(0.55).setFill()
        NSBezierPath(rect: NSRect(x: 0, y: size*0.34, width: size, height: size*0.08)).fill()
        NSGraphicsContext.current!.restoreGraphicsState()
        stroke(head)

        // 腮红
        c.cheek.setFill()
        NSBezierPath(ovalIn: NSRect(x: size*0.22, y: size*0.46, width: size*0.10, height: size*0.07)).fill()
        NSBezierPath(ovalIn: NSRect(x: size*0.68, y: size*0.46, width: size*0.10, height: size*0.07)).fill()

        // 眼睛
        let eyeY = size * 0.62
        drawEyes(at: eyeY, mood: mood, frame: frame, c: c, size: size, lw: lw)

        // 鼻子
        let nose = NSBezierPath()
        nose.move(to: NSPoint(x: size*0.50, y: size*0.46))
        nose.curve(to: NSPoint(x: size*0.43, y: size*0.54),
                   controlPoint1: NSPoint(x: size*0.45, y: size*0.46),
                   controlPoint2: NSPoint(x: size*0.42, y: size*0.50))
        nose.curve(to: NSPoint(x: size*0.57, y: size*0.54),
                   controlPoint1: NSPoint(x: size*0.46, y: size*0.57),
                   controlPoint2: NSPoint(x: size*0.54, y: size*0.57))
        nose.curve(to: NSPoint(x: size*0.50, y: size*0.46),
                   controlPoint1: NSPoint(x: size*0.58, y: size*0.50),
                   controlPoint2: NSPoint(x: size*0.55, y: size*0.46))
        nose.close(); c.outline.setFill(); nose.fill()

        // 嘴
        drawMouth(mood: mood, frame: frame, c: c, size: size, lw: lw, stroke: stroke)

        // 慌张专属：汗滴(右上)
        if mood == .panic {
            let dx: CGFloat = frame == 0 ? size*0.78 : size*0.20
            let dy: CGFloat = size*0.70
            let drop = NSBezierPath()
            drop.move(to: NSPoint(x: dx, y: dy + size*0.06))
            drop.curve(to: NSPoint(x: dx - size*0.025, y: dy - size*0.02),
                       controlPoint1: NSPoint(x: dx - size*0.025, y: dy + size*0.06),
                       controlPoint2: NSPoint(x: dx - size*0.04, y: dy + size*0.02))
            drop.curve(to: NSPoint(x: dx + size*0.025, y: dy - size*0.02),
                       controlPoint1: NSPoint(x: dx - size*0.01, y: dy - size*0.04),
                       controlPoint2: NSPoint(x: dx + size*0.01, y: dy - size*0.04))
            drop.curve(to: NSPoint(x: dx, y: dy + size*0.06),
                       controlPoint1: NSPoint(x: dx + size*0.04, y: dy + size*0.02),
                       controlPoint2: NSPoint(x: dx + size*0.025, y: dy + size*0.06))
            drop.close()
            rgb(0.40,0.70,0.98).setFill(); drop.fill()
            stroke(drop, lw*0.5)
        }

        img.unlockFocus()
        return img
    }

    private static func drawEars(style: EarStyle, c: CartoonColors, size: CGFloat,
                                 stroke: (NSBezierPath, CGFloat) -> Void) {
        switch style {
        case .floppy:
            for (cx, sign) in [(size*0.30, -1.0), (size*0.70, 1.0)] as [(CGFloat, CGFloat)] {
                let p = NSBezierPath()
                let top = NSPoint(x: cx, y: size*0.78)
                p.move(to: top)
                p.curve(to: NSPoint(x: cx + sign * size*0.16, y: size*0.42),
                        controlPoint1: NSPoint(x: cx + sign * size*0.12, y: size*0.78),
                        controlPoint2: NSPoint(x: cx + sign * size*0.20, y: size*0.60))
                p.curve(to: top,
                        controlPoint1: NSPoint(x: cx + sign * size*0.08, y: size*0.38),
                        controlPoint2: NSPoint(x: cx, y: size*0.60))
                p.close()
                c.ear.setFill(); p.fill()
                NSGraphicsContext.current!.saveGraphicsState()
                p.addClip(); c.earDk.setFill()
                NSBezierPath(rect: NSRect(x: 0, y: size*0.40, width: size, height: size*0.10)).fill()
                NSGraphicsContext.current!.restoreGraphicsState()
                stroke(p, 0)
            }
        case .triangle:
            for (cx, sign) in [(size*0.30, -1.0), (size*0.70, 1.0)] as [(CGFloat, CGFloat)] {
                let p = NSBezierPath()
                p.move(to: NSPoint(x: cx + sign * size*0.10, y: size*0.92))
                p.line(to: NSPoint(x: cx - sign * size*0.05, y: size*0.68))
                p.line(to: NSPoint(x: cx + sign * size*0.13, y: size*0.74))
                p.close()
                c.ear.setFill(); p.fill()
                // 内耳粉色小三角
                let inner = NSBezierPath()
                inner.move(to: NSPoint(x: cx + sign * size*0.07, y: size*0.85))
                inner.line(to: NSPoint(x: cx - sign * size*0.01, y: size*0.72))
                inner.line(to: NSPoint(x: cx + sign * size*0.09, y: size*0.74))
                inner.close()
                c.accent.withAlphaComponent(0.85).setFill(); inner.fill()
                stroke(p, 0)
            }
        case .longUp:
            for (cx, sign) in [(size*0.34, -1.0), (size*0.66, 1.0)] as [(CGFloat, CGFloat)] {
                let _ = sign
                let p = NSBezierPath(ovalIn: NSRect(
                    x: cx - size*0.06, y: size*0.66,
                    width: size*0.12, height: size*0.30))
                c.ear.setFill(); p.fill()
                // 兔耳内粉色
                let inner = NSBezierPath(ovalIn: NSRect(
                    x: cx - size*0.03, y: size*0.70, width: size*0.06, height: size*0.22))
                c.earDk.setFill(); inner.fill()
                stroke(p, 0)
            }
        case .horn:
            let p = NSBezierPath()
            p.move(to: NSPoint(x: size*0.46, y: size*0.82))
            p.line(to: NSPoint(x: size*0.50, y: size*0.96))
            p.line(to: NSPoint(x: size*0.54, y: size*0.82))
            p.close()
            c.accent.setFill(); p.fill()
            stroke(p, 0)
        }
    }

    private static func drawEyes(at eyeY: CGFloat, mood: Mood, frame: Int,
                                 c: CartoonColors, size: CGFloat, lw: CGFloat) {
        let lx = size * 0.38, rx = size * 0.62
        // 眨眼帧：happy/neutral 第二帧闭眼
        if frame == 1 && (mood == .happy || mood == .neutral) {
            for cx in [lx, rx] {
                let p = NSBezierPath()
                p.move(to: NSPoint(x: cx - size*0.05, y: eyeY))
                p.curve(to: NSPoint(x: cx + size*0.05, y: eyeY),
                        controlPoint1: NSPoint(x: cx - size*0.02, y: eyeY - size*0.025),
                        controlPoint2: NSPoint(x: cx + size*0.02, y: eyeY - size*0.025))
                c.outline.setStroke(); p.lineWidth = lw; p.stroke()
            }
            return
        }
        for cx in [lx, rx] {
            switch mood {
            case .panic:
                let r = size * 0.07
                let rect = NSRect(x: cx - r, y: eyeY - r, width: r*2, height: r*2)
                NSColor.white.setFill(); NSBezierPath(ovalIn: rect).fill()
                c.outline.setStroke(); let p = NSBezierPath(ovalIn: rect); p.lineWidth = lw*0.7; p.stroke()
                let r2 = r * 0.5
                c.outline.setFill()
                NSBezierPath(ovalIn: NSRect(x: cx - r2, y: eyeY - r2, width: r2*2, height: r2*2)).fill()
            default:
                let r = size * (mood == .worried ? 0.045 : 0.052)
                c.eyeMain.setFill()
                NSBezierPath(ovalIn: NSRect(x: cx - r, y: eyeY - r, width: r*2, height: r*2)).fill()
                // 高光
                c.eyeShine.setFill()
                NSBezierPath(ovalIn: NSRect(x: cx - r*0.35, y: eyeY + r*0.25, width: r*0.7, height: r*0.7)).fill()
            }
        }
    }

    private static func drawMouth(mood: Mood, frame: Int, c: CartoonColors,
                                  size: CGFloat, lw: CGFloat,
                                  stroke: (NSBezierPath, CGFloat) -> Void) {
        let mouthY = size * 0.40
        switch mood {
        case .happy:
            // 大笑 + 舌头
            let m = NSBezierPath()
            m.move(to: NSPoint(x: size*0.36, y: mouthY))
            m.curve(to: NSPoint(x: size*0.64, y: mouthY),
                    controlPoint1: NSPoint(x: size*0.42, y: mouthY - size*0.10),
                    controlPoint2: NSPoint(x: size*0.58, y: mouthY - size*0.10))
            m.line(to: NSPoint(x: size*0.36, y: mouthY))
            m.close(); c.outline.setFill(); m.fill()
            let tongue = NSBezierPath(ovalIn: NSRect(x: size*0.42, y: mouthY - size*0.09, width: size*0.16, height: size*0.07))
            c.accent.setFill(); tongue.fill()
        case .neutral:
            let m = NSBezierPath()
            m.move(to: NSPoint(x: size*0.42, y: mouthY))
            m.curve(to: NSPoint(x: size*0.58, y: mouthY),
                    controlPoint1: NSPoint(x: size*0.46, y: mouthY - size*0.04),
                    controlPoint2: NSPoint(x: size*0.54, y: mouthY - size*0.04))
            stroke(m, 0)
        case .worried:
            let m = NSBezierPath()
            m.move(to: NSPoint(x: size*0.40, y: mouthY))
            m.curve(to: NSPoint(x: size*0.50, y: mouthY),
                    controlPoint1: NSPoint(x: size*0.43, y: mouthY + size*0.025),
                    controlPoint2: NSPoint(x: size*0.47, y: mouthY - size*0.03))
            m.curve(to: NSPoint(x: size*0.60, y: mouthY),
                    controlPoint1: NSPoint(x: size*0.53, y: mouthY + size*0.025),
                    controlPoint2: NSPoint(x: size*0.57, y: mouthY - size*0.03))
            stroke(m, 0)
        case .panic:
            // 张开红嘴(frame=0 椭圆, frame=1 更扁，制造抖动)
            let w: CGFloat = frame == 0 ? size*0.20 : size*0.24
            let h: CGFloat = frame == 0 ? size*0.12 : size*0.09
            let m = NSBezierPath(ovalIn: NSRect(x: size*0.50 - w/2, y: mouthY - h*0.7, width: w, height: h))
            rgb(0.90,0.25,0.20).setFill(); m.fill()
            stroke(m, 0)
        }
    }
}
