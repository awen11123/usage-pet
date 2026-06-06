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
    let body: NSColor
    let bodyDk: NSColor
    let ear: NSColor
    let earDk: NSColor
    let outline: NSColor
    let accent: NSColor      // 舌/重点色
    let cheek: NSColor       // 腮红
    let eyeMain: NSColor     // 眼睛主色
    let eyeShine: NSColor    // 眼睛高光
}

enum EarStyle {
    case floppy    // 垂耳(狗)
    case triangle  // 三角立耳(猫)
    case longUp    // 长立耳(兔)
    case horn      // 独角(怪兽)
}

struct Skin {
    let id: String
    let name: String
    let colors: CartoonColors
    let ears: EarStyle
    func frames(for mood: Mood, scale: CGFloat) -> [NSImage] {
        let side = 16 * scale
        return [0, 1].map { CartoonRenderer.image(skin: self, mood: mood, frame: $0, size: side) }
    }
}

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
        body: rgb(0.97,0.94,0.86), bodyDk: rgb(0.87,0.83,0.74),
        ear:  rgb(0.62,0.60,0.57), earDk:  rgb(0.50,0.48,0.46),
        outline: rgb(0.20,0.18,0.18), accent: rgb(0.97,0.62,0.66),
        cheek: NSColor(srgbRed: 1.0, green: 0.65, blue: 0.65, alpha: 0.80),
        eyeMain: rgb(0.13,0.11,0.10), eyeShine: .white)
    static let creamPlain = CartoonColors(
        body: rgb(0.97,0.95,0.88), bodyDk: rgb(0.87,0.84,0.75),
        ear:  rgb(0.94,0.92,0.84), earDk:  rgb(0.82,0.79,0.71),
        outline: rgb(0.22,0.20,0.20), accent: rgb(0.95,0.62,0.62),
        cheek: NSColor(srgbRed: 1.0, green: 0.65, blue: 0.65, alpha: 0.80),
        eyeMain: rgb(0.13,0.11,0.10), eyeShine: .white)
    static let orange = CartoonColors(
        body: rgb(0.94,0.58,0.34), bodyDk: rgb(0.82,0.44,0.22),
        ear:  rgb(0.94,0.58,0.34), earDk:  rgb(0.82,0.44,0.22),
        outline: rgb(0.30,0.16,0.10), accent: rgb(0.97,0.62,0.66),
        cheek: NSColor(srgbRed: 1.0, green: 0.50, blue: 0.50, alpha: 0.55),
        eyeMain: rgb(0.08,0.06,0.05), eyeShine: .white)
    static let black = CartoonColors(
        body: rgb(0.20,0.20,0.23), bodyDk: rgb(0.12,0.12,0.14),
        ear:  rgb(0.20,0.20,0.23), earDk:  rgb(0.12,0.12,0.14),
        outline: rgb(0.05,0.05,0.06), accent: rgb(0.95,0.45,0.55),
        cheek: NSColor(srgbRed: 0.95, green: 0.45, blue: 0.55, alpha: 0.55),
        eyeMain: rgb(0.55,0.85,0.45),
        eyeShine: .white)
    static let rabbit = CartoonColors(
        body: rgb(0.98,0.96,0.94), bodyDk: rgb(0.87,0.85,0.84),
        ear:  rgb(0.98,0.96,0.94), earDk:  rgb(0.95,0.62,0.66),
        outline: rgb(0.32,0.28,0.30), accent: rgb(0.95,0.62,0.66),
        cheek: NSColor(srgbRed: 1.0, green: 0.70, blue: 0.78, alpha: 0.85),
        eyeMain: rgb(0.20,0.16,0.18), eyeShine: .white)
    static let monster = CartoonColors(
        body: rgb(0.62,0.50,0.86), bodyDk: rgb(0.48,0.36,0.72),
        ear:  rgb(0.62,0.50,0.86), earDk:  rgb(0.48,0.36,0.72),
        outline: rgb(0.22,0.16,0.34), accent: rgb(0.95,0.62,0.72),
        cheek: NSColor(srgbRed: 1.0, green: 0.55, blue: 0.70, alpha: 0.65),
        eyeMain: rgb(0.10,0.08,0.16), eyeShine: .white)
}

// MARK: - 渲染器 (chibi 风：头大身小、大眼睛、点状腮红)
enum CartoonRenderer {
    static func image(skin: Skin, mood: Mood, frame: Int, size S: CGFloat) -> NSImage {
        let img = NSImage(size: NSSize(width: S, height: S))
        img.lockFocus()
        let c = skin.colors
        let lw = max(2, S * 0.024)
        func stroke(_ p: NSBezierPath, _ width: CGFloat = 0) {
            c.outline.setStroke(); p.lineWidth = width > 0 ? width : lw; p.stroke()
        }

        // 投影
        NSColor.black.withAlphaComponent(0.24).setFill()
        NSBezierPath(ovalIn: NSRect(x: S*0.20, y: S*0.02, width: S*0.60, height: S*0.06)).fill()

        // 小身体(几乎被头盖住，只露下半圈，看起来像个圆滚滚的小肚子)
        let bodyRect = NSRect(x: S*0.30, y: S*0.05, width: S*0.40, height: S*0.30)
        let bp = NSBezierPath(ovalIn: bodyRect)
        c.body.setFill(); bp.fill()
        NSGraphicsContext.current!.saveGraphicsState()
        bp.addClip(); c.bodyDk.setFill()
        NSBezierPath(rect: NSRect(x: 0, y: S*0.05, width: S, height: S*0.08)).fill()
        NSGraphicsContext.current!.restoreGraphicsState()
        stroke(bp)

        // 两只小爪子(短短的、可爱)
        for x in [S*0.36, S*0.56] {
            let p = NSBezierPath(ovalIn: NSRect(x: x, y: S*0.03, width: S*0.08, height: S*0.06))
            c.body.setFill(); p.fill(); stroke(p)
        }

        // 耳朵(先画，被头部覆盖根部)
        drawEars(style: skin.ears, c: c, S: S, stroke: stroke)

        // 大头(占整个画布约 70%)
        let headRect = NSRect(x: S*0.10, y: S*0.25, width: S*0.80, height: S*0.66)
        let head = NSBezierPath(ovalIn: headRect)
        c.body.setFill(); head.fill()
        NSGraphicsContext.current!.saveGraphicsState()
        head.addClip()
        // 头顶大块白色高光(突出 chibi 圆润感)
        let hi = NSBezierPath(ovalIn: NSRect(x: S*0.20, y: S*0.75, width: S*0.34, height: S*0.13))
        NSColor.white.withAlphaComponent(0.40).setFill(); hi.fill()
        // 头下沿暗部
        c.bodyDk.withAlphaComponent(0.50).setFill()
        NSBezierPath(rect: NSRect(x: 0, y: S*0.25, width: S, height: S*0.08)).fill()
        NSGraphicsContext.current!.restoreGraphicsState()
        stroke(head)

        // 圆点腮红(小且圆，chibi 灵魂)
        let cheekR: CGFloat = S * 0.05
        c.cheek.setFill()
        NSBezierPath(ovalIn: NSRect(x: S*0.22, y: S*0.42, width: cheekR*2, height: cheekR*2)).fill()
        NSBezierPath(ovalIn: NSRect(x: S*0.68, y: S*0.42, width: cheekR*2, height: cheekR*2)).fill()

        // 超大眼睛(chibi 核心)
        let eyeY = S * 0.56
        drawEyes(at: eyeY, mood: mood, frame: frame, c: c, S: S, lw: lw)

        // 小鼻子(更小，居中)
        let noseR = S * 0.035
        let nose = NSBezierPath(ovalIn: NSRect(x: S*0.50 - noseR, y: S*0.46, width: noseR*2, height: noseR*2 * 0.85))
        c.outline.setFill(); nose.fill()

        // 嘴
        drawMouth(mood: mood, frame: frame, c: c, S: S, lw: lw, stroke: stroke)

        // 慌张专属：汗滴
        if mood == .panic {
            let dx: CGFloat = frame == 0 ? S*0.84 : S*0.14
            let dy: CGFloat = S*0.72
            let drop = NSBezierPath()
            drop.move(to: NSPoint(x: dx, y: dy + S*0.06))
            drop.curve(to: NSPoint(x: dx - S*0.028, y: dy - S*0.02),
                       controlPoint1: NSPoint(x: dx - S*0.025, y: dy + S*0.06),
                       controlPoint2: NSPoint(x: dx - S*0.045, y: dy + S*0.02))
            drop.curve(to: NSPoint(x: dx + S*0.028, y: dy - S*0.02),
                       controlPoint1: NSPoint(x: dx - S*0.01, y: dy - S*0.045),
                       controlPoint2: NSPoint(x: dx + S*0.01, y: dy - S*0.045))
            drop.curve(to: NSPoint(x: dx, y: dy + S*0.06),
                       controlPoint1: NSPoint(x: dx + S*0.045, y: dy + S*0.02),
                       controlPoint2: NSPoint(x: dx + S*0.025, y: dy + S*0.06))
            drop.close()
            rgb(0.40,0.70,0.98).setFill(); drop.fill()
            stroke(drop, lw*0.5)
        }

        img.unlockFocus()
        return img
    }

    private static func drawEars(style: EarStyle, c: CartoonColors, S: CGFloat,
                                 stroke: (NSBezierPath, CGFloat) -> Void) {
        switch style {
        case .floppy:
            for (cx, sign) in [(S*0.20, -1.0), (S*0.80, 1.0)] as [(CGFloat, CGFloat)] {
                let p = NSBezierPath()
                let top = NSPoint(x: cx, y: S*0.82)
                p.move(to: top)
                p.curve(to: NSPoint(x: cx + sign * S*0.13, y: S*0.34),
                        controlPoint1: NSPoint(x: cx + sign * S*0.10, y: S*0.82),
                        controlPoint2: NSPoint(x: cx + sign * S*0.18, y: S*0.55))
                p.curve(to: top,
                        controlPoint1: NSPoint(x: cx + sign * S*0.06, y: S*0.30),
                        controlPoint2: NSPoint(x: cx + sign * 0.02 * S, y: S*0.55))
                p.close()
                c.ear.setFill(); p.fill()
                NSGraphicsContext.current!.saveGraphicsState()
                p.addClip(); c.earDk.setFill()
                NSBezierPath(rect: NSRect(x: 0, y: S*0.32, width: S, height: S*0.10)).fill()
                NSGraphicsContext.current!.restoreGraphicsState()
                stroke(p, 0)
            }
        case .triangle:
            for (cx, sign) in [(S*0.24, -1.0), (S*0.76, 1.0)] as [(CGFloat, CGFloat)] {
                let p = NSBezierPath()
                p.move(to: NSPoint(x: cx + sign * S*0.10, y: S*0.98))
                p.line(to: NSPoint(x: cx - sign * S*0.05, y: S*0.70))
                p.line(to: NSPoint(x: cx + sign * S*0.15, y: S*0.76))
                p.close()
                c.ear.setFill(); p.fill()
                // 内耳粉色
                let inner = NSBezierPath()
                inner.move(to: NSPoint(x: cx + sign * S*0.07, y: S*0.90))
                inner.line(to: NSPoint(x: cx, y: S*0.74))
                inner.line(to: NSPoint(x: cx + sign * S*0.10, y: S*0.76))
                inner.close()
                c.accent.withAlphaComponent(0.80).setFill(); inner.fill()
                stroke(p, 0)
            }
        case .longUp:
            for (cx, _) in [(S*0.32, -1.0), (S*0.68, 1.0)] as [(CGFloat, CGFloat)] {
                let p = NSBezierPath(ovalIn: NSRect(
                    x: cx - S*0.07, y: S*0.62,
                    width: S*0.14, height: S*0.36))
                c.ear.setFill(); p.fill()
                let inner = NSBezierPath(ovalIn: NSRect(
                    x: cx - S*0.035, y: S*0.66, width: S*0.07, height: S*0.26))
                c.earDk.setFill(); inner.fill()
                stroke(p, 0)
            }
        case .horn:
            let p = NSBezierPath()
            p.move(to: NSPoint(x: S*0.44, y: S*0.86))
            p.line(to: NSPoint(x: S*0.50, y: S*1.00))
            p.line(to: NSPoint(x: S*0.56, y: S*0.86))
            p.close()
            c.accent.setFill(); p.fill()
            stroke(p, 0)
        }
    }

    private static func drawEyes(at eyeY: CGFloat, mood: Mood, frame: Int,
                                 c: CartoonColors, S: CGFloat, lw: CGFloat) {
        let lx = S * 0.36, rx = S * 0.64
        // 眨眼：第二帧，happy/neutral 时
        if frame == 1 && (mood == .happy || mood == .neutral) {
            for cx in [lx, rx] {
                let p = NSBezierPath()
                p.move(to: NSPoint(x: cx - S*0.07, y: eyeY + S*0.01))
                p.curve(to: NSPoint(x: cx + S*0.07, y: eyeY + S*0.01),
                        controlPoint1: NSPoint(x: cx - S*0.03, y: eyeY - S*0.04),
                        controlPoint2: NSPoint(x: cx + S*0.03, y: eyeY - S*0.04))
                c.outline.setStroke(); p.lineWidth = lw; p.stroke()
            }
            return
        }
        for cx in [lx, rx] {
            switch mood {
            case .panic:
                // 大瞪眼(白圈 + 黑/绿瞳 + 高光)
                let r = S * 0.085
                let rect = NSRect(x: cx - r, y: eyeY - r, width: r*2, height: r*2)
                NSColor.white.setFill(); NSBezierPath(ovalIn: rect).fill()
                c.outline.setStroke(); let p = NSBezierPath(ovalIn: rect); p.lineWidth = lw*0.85; p.stroke()
                // 瞳孔(偏小，更慌张)
                let pr = r * 0.45
                c.eyeMain.setFill()
                NSBezierPath(ovalIn: NSRect(x: cx - pr, y: eyeY - pr, width: pr*2, height: pr*2)).fill()
                // 小高光
                let sr = pr * 0.4
                NSColor.white.setFill()
                NSBezierPath(ovalIn: NSRect(x: cx - sr*0.3, y: eyeY + sr*0.5, width: sr*1.5, height: sr*1.5)).fill()
            case .worried:
                // 略小、略向上(担心)
                let r = S * 0.075
                c.eyeMain.setFill()
                NSBezierPath(ovalIn: NSRect(x: cx - r, y: eyeY - r*0.9, width: r*2, height: r*2)).fill()
                NSColor.white.setFill()
                NSBezierPath(ovalIn: NSRect(x: cx - r*0.30, y: eyeY + r*0.25, width: r*0.85, height: r*0.85)).fill()
                // 第二个小高光
                NSBezierPath(ovalIn: NSRect(x: cx + r*0.30, y: eyeY - r*0.15, width: r*0.35, height: r*0.35)).fill()
            default:
                // chibi 大眼：大黑球 + 双高光
                let r = S * 0.085
                c.eyeMain.setFill()
                NSBezierPath(ovalIn: NSRect(x: cx - r, y: eyeY - r, width: r*2, height: r*2)).fill()
                // 主高光(左上)
                NSColor.white.setFill()
                NSBezierPath(ovalIn: NSRect(x: cx - r*0.45, y: eyeY + r*0.20, width: r*0.85, height: r*0.85)).fill()
                // 副高光(右下，小)
                NSBezierPath(ovalIn: NSRect(x: cx + r*0.25, y: eyeY - r*0.55, width: r*0.35, height: r*0.35)).fill()
            }
        }
    }

    private static func drawMouth(mood: Mood, frame: Int, c: CartoonColors,
                                  S: CGFloat, lw: CGFloat,
                                  stroke: (NSBezierPath, CGFloat) -> Void) {
        let mouthY = S * 0.40
        switch mood {
        case .happy:
            // 大笑 + 舌头
            let m = NSBezierPath()
            m.move(to: NSPoint(x: S*0.42, y: mouthY))
            m.curve(to: NSPoint(x: S*0.58, y: mouthY),
                    controlPoint1: NSPoint(x: S*0.45, y: mouthY - S*0.07),
                    controlPoint2: NSPoint(x: S*0.55, y: mouthY - S*0.07))
            m.line(to: NSPoint(x: S*0.42, y: mouthY))
            m.close(); c.outline.setFill(); m.fill()
            let tongue = NSBezierPath(ovalIn: NSRect(x: S*0.46, y: mouthY - S*0.06, width: S*0.08, height: S*0.04))
            c.accent.setFill(); tongue.fill()
        case .neutral:
            let m = NSBezierPath()
            m.move(to: NSPoint(x: S*0.45, y: mouthY))
            m.curve(to: NSPoint(x: S*0.55, y: mouthY),
                    controlPoint1: NSPoint(x: S*0.47, y: mouthY - S*0.025),
                    controlPoint2: NSPoint(x: S*0.53, y: mouthY - S*0.025))
            stroke(m, 0)
        case .worried:
            let m = NSBezierPath()
            m.move(to: NSPoint(x: S*0.42, y: mouthY))
            m.curve(to: NSPoint(x: S*0.50, y: mouthY),
                    controlPoint1: NSPoint(x: S*0.45, y: mouthY + S*0.020),
                    controlPoint2: NSPoint(x: S*0.47, y: mouthY - S*0.025))
            m.curve(to: NSPoint(x: S*0.58, y: mouthY),
                    controlPoint1: NSPoint(x: S*0.53, y: mouthY + S*0.020),
                    controlPoint2: NSPoint(x: S*0.55, y: mouthY - S*0.025))
            stroke(m, 0)
        case .panic:
            // 张开椭圆嘴
            let w: CGFloat = frame == 0 ? S*0.16 : S*0.20
            let h: CGFloat = frame == 0 ? S*0.10 : S*0.08
            let m = NSBezierPath(ovalIn: NSRect(x: S*0.50 - w/2, y: mouthY - h*0.6, width: w, height: h))
            rgb(0.90,0.25,0.20).setFill(); m.fill()
            stroke(m, 0)
        }
    }
}
