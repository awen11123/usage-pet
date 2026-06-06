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

// MARK: - 物种(决定耳型/鼻嘴/胡须/身体花纹)
enum Species {
    case dog, cat, rabbit, monster
    case calico         // 三花猫
    case shiba          // 柴犬
    case hamster        // 仓鼠
    case panda          // 熊猫
    case penguin        // 企鹅
    case frog           // 青蛙
    case fox            // 狐狸
}

// MARK: - 配色
struct CartoonColors {
    let body: NSColor
    let bodyDk: NSColor
    let ear: NSColor
    let earDk: NSColor
    let outline: NSColor
    let accent: NSColor       // 舌/重点色
    let cheek: NSColor
    let eyeMain: NSColor
    let eyeShine: NSColor
    /// 副色：三花猫的橘斑、柴犬的白脸、狐狸/企鹅的白肚等
    var secondary: NSColor = NSColor.clear
}

struct Skin {
    let id: String
    let name: String
    let colors: CartoonColors
    let species: Species
    func frames(for mood: Mood, scale: CGFloat) -> [NSImage] {
        let side = 16 * scale
        return [0, 1].map { CartoonRenderer.image(skin: self, mood: mood, frame: $0, size: side) }
    }
}

private func rgb(_ r: Double, _ g: Double, _ b: Double) -> NSColor {
    NSColor(srgbRed: r, green: g, blue: b, alpha: 1)
}

// MARK: - 全部 13 个形象
enum Skins {
    static let all: [Skin] = [
        dog, shiba, orangeCat, blackCat, creamCat, calico, fox,
        rabbit, hamster, panda, penguin, frog, monster
    ]
    static func byId(_ id: String) -> Skin { all.first { $0.id == id } ?? dog }

    static let dog       = Skin(id: "dog",     name: "🐶 奶白小狗", colors: .creamDogPalette,     species: .dog)
    static let shiba     = Skin(id: "shiba",   name: "🐕 柴犬",     colors: .shibaPalette,        species: .shiba)
    static let orangeCat = Skin(id: "ocat",    name: "🐱 橘猫",     colors: .orangeCatPalette,    species: .cat)
    static let blackCat  = Skin(id: "bcat",    name: "🐈‍⬛ 黑猫",   colors: .blackCatPalette,     species: .cat)
    static let creamCat  = Skin(id: "ccat",    name: "🐱 奶白猫",   colors: .creamCatPalette,     species: .cat)
    static let calico    = Skin(id: "calico",  name: "🐱 三花猫",   colors: .calicoPalette,       species: .calico)
    static let fox       = Skin(id: "fox",     name: "🦊 小狐狸",   colors: .foxPalette,          species: .fox)
    static let rabbit    = Skin(id: "rabbit",  name: "🐰 小兔",     colors: .rabbitPalette,       species: .rabbit)
    static let hamster   = Skin(id: "hamster", name: "🐹 仓鼠",     colors: .hamsterPalette,      species: .hamster)
    static let panda     = Skin(id: "panda",   name: "🐼 熊猫",     colors: .pandaPalette,        species: .panda)
    static let penguin   = Skin(id: "penguin", name: "🐧 企鹅",     colors: .penguinPalette,      species: .penguin)
    static let frog      = Skin(id: "frog",    name: "🐸 青蛙",     colors: .frogPalette,         species: .frog)
    static let monster   = Skin(id: "monster", name: "👾 小怪兽",   colors: .monsterPalette,      species: .monster)
}

// MARK: - 13 套配色
extension CartoonColors {
    static let creamDogPalette = CartoonColors(
        body: rgb(0.97,0.94,0.86), bodyDk: rgb(0.87,0.83,0.74),
        ear:  rgb(0.62,0.60,0.57), earDk:  rgb(0.50,0.48,0.46),
        outline: rgb(0.20,0.18,0.18), accent: rgb(0.97,0.62,0.66),
        cheek: NSColor(srgbRed:1.0,green:0.65,blue:0.65,alpha:0.80),
        eyeMain: rgb(0.13,0.11,0.10), eyeShine: .white)
    static let shibaPalette = CartoonColors(
        body: rgb(0.93,0.60,0.32), bodyDk: rgb(0.78,0.46,0.20),
        ear:  rgb(0.93,0.60,0.32), earDk:  rgb(0.78,0.46,0.20),
        outline: rgb(0.25,0.14,0.08), accent: rgb(0.97,0.62,0.66),
        cheek: NSColor(srgbRed:1.0,green:0.50,blue:0.50,alpha:0.55),
        eyeMain: rgb(0.08,0.06,0.05), eyeShine: .white,
        secondary: rgb(0.99,0.96,0.91))     // 白脸
    static let orangeCatPalette = CartoonColors(
        body: rgb(0.94,0.58,0.34), bodyDk: rgb(0.82,0.44,0.22),
        ear:  rgb(0.94,0.58,0.34), earDk:  rgb(0.82,0.44,0.22),
        outline: rgb(0.30,0.16,0.10), accent: rgb(0.97,0.62,0.66),
        cheek: NSColor(srgbRed:1.0,green:0.50,blue:0.50,alpha:0.55),
        eyeMain: rgb(0.08,0.06,0.05), eyeShine: .white)
    static let blackCatPalette = CartoonColors(
        body: rgb(0.20,0.20,0.23), bodyDk: rgb(0.12,0.12,0.14),
        ear:  rgb(0.20,0.20,0.23), earDk:  rgb(0.12,0.12,0.14),
        outline: rgb(0.05,0.05,0.06), accent: rgb(0.95,0.45,0.55),
        cheek: NSColor(srgbRed:0.95,green:0.45,blue:0.55,alpha:0.55),
        eyeMain: rgb(0.55,0.85,0.45), eyeShine: .white)
    static let creamCatPalette = CartoonColors(
        body: rgb(0.97,0.95,0.88), bodyDk: rgb(0.87,0.84,0.75),
        ear:  rgb(0.94,0.92,0.84), earDk:  rgb(0.82,0.79,0.71),
        outline: rgb(0.22,0.20,0.20), accent: rgb(0.95,0.62,0.62),
        cheek: NSColor(srgbRed:1.0,green:0.65,blue:0.65,alpha:0.80),
        eyeMain: rgb(0.13,0.11,0.10), eyeShine: .white)
    static let calicoPalette = CartoonColors(
        body: rgb(0.97,0.95,0.88), bodyDk: rgb(0.87,0.84,0.75),
        ear:  rgb(0.94,0.58,0.34), earDk:  rgb(0.82,0.44,0.22),
        outline: rgb(0.22,0.18,0.16), accent: rgb(0.95,0.55,0.62),
        cheek: NSColor(srgbRed:1.0,green:0.65,blue:0.65,alpha:0.75),
        eyeMain: rgb(0.13,0.11,0.10), eyeShine: .white,
        secondary: rgb(0.30,0.22,0.18))    // 黑色斑块
    static let foxPalette = CartoonColors(
        body: rgb(0.92,0.50,0.20), bodyDk: rgb(0.78,0.38,0.12),
        ear:  rgb(0.92,0.50,0.20), earDk:  rgb(0.30,0.16,0.10),
        outline: rgb(0.28,0.14,0.06), accent: rgb(0.97,0.62,0.66),
        cheek: NSColor(srgbRed:1.0,green:0.50,blue:0.50,alpha:0.50),
        eyeMain: rgb(0.10,0.07,0.05), eyeShine: .white,
        secondary: rgb(0.99,0.96,0.91))    // 白胸/白下巴
    static let rabbitPalette = CartoonColors(
        body: rgb(0.98,0.96,0.94), bodyDk: rgb(0.87,0.85,0.84),
        ear:  rgb(0.98,0.96,0.94), earDk:  rgb(0.95,0.62,0.66),
        outline: rgb(0.32,0.28,0.30), accent: rgb(0.95,0.62,0.66),
        cheek: NSColor(srgbRed:1.0,green:0.70,blue:0.78,alpha:0.85),
        eyeMain: rgb(0.20,0.16,0.18), eyeShine: .white)
    static let hamsterPalette = CartoonColors(
        body: rgb(0.95,0.75,0.45), bodyDk: rgb(0.78,0.58,0.28),
        ear:  rgb(0.95,0.75,0.45), earDk:  rgb(0.95,0.62,0.55),
        outline: rgb(0.25,0.16,0.08), accent: rgb(0.97,0.62,0.66),
        cheek: NSColor(srgbRed:1.0,green:0.55,blue:0.55,alpha:0.65),
        eyeMain: rgb(0.13,0.10,0.08), eyeShine: .white,
        secondary: rgb(0.99,0.97,0.92))    // 白肚
    static let pandaPalette = CartoonColors(
        body: rgb(0.97,0.96,0.93), bodyDk: rgb(0.84,0.83,0.80),
        ear:  rgb(0.18,0.18,0.20), earDk:  rgb(0.10,0.10,0.12),
        outline: rgb(0.12,0.10,0.10), accent: rgb(0.95,0.55,0.55),
        cheek: NSColor(srgbRed:1.0,green:0.60,blue:0.60,alpha:0.70),
        eyeMain: rgb(0.10,0.08,0.08), eyeShine: .white,
        secondary: rgb(0.18,0.18,0.20))    // 黑色眼圈
    static let penguinPalette = CartoonColors(
        body: rgb(0.20,0.22,0.30), bodyDk: rgb(0.12,0.14,0.20),
        ear:  rgb(0.20,0.22,0.30), earDk:  rgb(0.12,0.14,0.20),
        outline: rgb(0.08,0.08,0.12), accent: rgb(0.97,0.65,0.18),  // 橙喙色
        cheek: NSColor(srgbRed:0.95,green:0.45,blue:0.55,alpha:0.50),
        eyeMain: rgb(0.10,0.08,0.10), eyeShine: .white,
        secondary: rgb(0.99,0.97,0.94))    // 白肚
    static let frogPalette = CartoonColors(
        body: rgb(0.50,0.78,0.38), bodyDk: rgb(0.36,0.62,0.26),
        ear:  rgb(0.50,0.78,0.38), earDk:  rgb(0.36,0.62,0.26),
        outline: rgb(0.10,0.20,0.08), accent: rgb(0.95,0.55,0.55),
        cheek: NSColor(srgbRed:1.0,green:0.55,blue:0.55,alpha:0.50),
        eyeMain: rgb(0.10,0.08,0.08), eyeShine: .white,
        secondary: rgb(0.92,0.95,0.78))    // 浅黄绿肚
    static let monsterPalette = CartoonColors(
        body: rgb(0.62,0.50,0.86), bodyDk: rgb(0.48,0.36,0.72),
        ear:  rgb(0.62,0.50,0.86), earDk:  rgb(0.48,0.36,0.72),
        outline: rgb(0.22,0.16,0.34), accent: rgb(0.95,0.62,0.72),
        cheek: NSColor(srgbRed:1.0,green:0.55,blue:0.70,alpha:0.65),
        eyeMain: rgb(0.10,0.08,0.16), eyeShine: .white)
}

// MARK: - 渲染器 (chibi 风：头大身小、大眼睛、点状腮红)
private func bodyLuminance(_ c: NSColor) -> CGFloat {
    let rgb = c.usingColorSpace(.sRGB) ?? c
    return (rgb.redComponent + rgb.greenComponent + rgb.blueComponent) / 3
}

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

        // 小身体
        let bodyRect = NSRect(x: S*0.30, y: S*0.05, width: S*0.40, height: S*0.30)
        let bp = NSBezierPath(ovalIn: bodyRect)
        c.body.setFill(); bp.fill()
        NSGraphicsContext.current!.saveGraphicsState()
        bp.addClip(); c.bodyDk.setFill()
        NSBezierPath(rect: NSRect(x: 0, y: S*0.05, width: S, height: S*0.08)).fill()
        // 白肚区(企鹅/仓鼠等需要)
        if hasBelly(skin.species) {
            c.secondary.setFill()
            NSBezierPath(ovalIn: NSRect(x: S*0.34, y: S*0.06, width: S*0.32, height: S*0.24)).fill()
        }
        NSGraphicsContext.current!.restoreGraphicsState()
        stroke(bp)

        // 爪子
        for x in [S*0.36, S*0.56] {
            let p = NSBezierPath(ovalIn: NSRect(x: x, y: S*0.03, width: S*0.08, height: S*0.06))
            c.body.setFill(); p.fill(); stroke(p)
        }

        // 耳朵(先画，被头盖住根部)
        drawEars(species: skin.species, c: c, S: S, stroke: stroke)

        // 大头
        let headRect = NSRect(x: S*0.10, y: S*0.25, width: S*0.80, height: S*0.66)
        let head = NSBezierPath(ovalIn: headRect)
        c.body.setFill(); head.fill()
        NSGraphicsContext.current!.saveGraphicsState()
        head.addClip()
        // 头顶高光
        let hi = NSBezierPath(ovalIn: NSRect(x: S*0.20, y: S*0.75, width: S*0.34, height: S*0.13))
        NSColor.white.withAlphaComponent(0.38).setFill(); hi.fill()
        // 头下沿暗部
        c.bodyDk.withAlphaComponent(0.50).setFill()
        NSBezierPath(rect: NSRect(x: 0, y: S*0.25, width: S, height: S*0.08)).fill()
        // 物种花纹(柴犬白脸、狐狸白脸、熊猫黑眼圈、三花斑、企鹅白脸…)
        drawHeadPatches(species: skin.species, c: c, S: S)
        NSGraphicsContext.current!.restoreGraphicsState()
        stroke(head)

        // 腮红(根据花纹避开位置)
        drawCheeks(species: skin.species, c: c, S: S)

        // 眼睛
        drawEyes(species: skin.species, mood: mood, frame: frame, c: c, S: S, lw: lw)

        // 鼻子
        drawNose(species: skin.species, c: c, S: S, lw: lw)

        // 嘴
        drawMouth(species: skin.species, mood: mood, frame: frame, c: c, S: S, lw: lw, stroke: stroke)

        // 物种额外特征(胡须/门牙等)
        drawExtras(species: skin.species, mood: mood, c: c, S: S, lw: lw)

        // 慌张专属：汗滴
        if mood == .panic {
            drawSweat(frame: frame, S: S, lw: lw, stroke: stroke)
        }

        img.unlockFocus()
        return img
    }

    // MARK: 是否绘制白肚
    private static func hasBelly(_ s: Species) -> Bool {
        switch s {
        case .penguin, .hamster, .panda, .fox: return true
        default: return false
        }
    }

    // MARK: 耳朵
    private static func drawEars(species: Species, c: CartoonColors, S: CGFloat,
                                 stroke: (NSBezierPath, CGFloat) -> Void) {
        switch species {
        case .dog:
            // 垂耳
            floppyEars(c: c, S: S, stroke: stroke)
        case .shiba:
            // 尖立耳(比猫更竖直且白脸内耳粉)
            for (cx, sign) in [(S*0.22, -1.0), (S*0.78, 1.0)] as [(CGFloat, CGFloat)] {
                let p = NSBezierPath()
                p.move(to: NSPoint(x: cx + sign * S*0.08, y: S*0.98))
                p.line(to: NSPoint(x: cx - sign * S*0.03, y: S*0.74))
                p.line(to: NSPoint(x: cx + sign * S*0.12, y: S*0.80))
                p.close()
                c.body.setFill(); p.fill()
                let inner = NSBezierPath()
                inner.move(to: NSPoint(x: cx + sign * S*0.055, y: S*0.92))
                inner.line(to: NSPoint(x: cx, y: S*0.78))
                inner.line(to: NSPoint(x: cx + sign * S*0.07, y: S*0.80))
                inner.close()
                NSColor(srgbRed: 0.95, green: 0.55, blue: 0.55, alpha: 0.7).setFill(); inner.fill()
                stroke(p, 0)
            }
        case .cat, .calico, .fox:
            triangleEars(c: c, S: S, stroke: stroke)
        case .rabbit:
            longUpEars(c: c, S: S, stroke: stroke)
        case .monster:
            hornEar(c: c, S: S, stroke: stroke)
        case .hamster:
            // 小圆耳
            for cx in [S*0.26, S*0.74] {
                let r = NSBezierPath(ovalIn: NSRect(x: cx - S*0.05, y: S*0.78, width: S*0.10, height: S*0.10))
                c.body.setFill(); r.fill()
                let inner = NSBezierPath(ovalIn: NSRect(x: cx - S*0.025, y: S*0.80, width: S*0.05, height: S*0.06))
                NSColor(srgbRed: 0.95, green: 0.55, blue: 0.55, alpha: 0.7).setFill(); inner.fill()
                stroke(r, 0)
            }
        case .panda:
            // 黑色大圆耳
            for cx in [S*0.20, S*0.80] {
                let r = NSBezierPath(ovalIn: NSRect(x: cx - S*0.09, y: S*0.78, width: S*0.18, height: S*0.18))
                c.ear.setFill(); r.fill(); stroke(r, 0)
            }
        case .penguin, .frog:
            break   // 无耳
        }
    }

    private static func floppyEars(c: CartoonColors, S: CGFloat,
                                   stroke: (NSBezierPath, CGFloat) -> Void) {
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
    }

    private static func triangleEars(c: CartoonColors, S: CGFloat,
                                     stroke: (NSBezierPath, CGFloat) -> Void) {
        for (cx, sign) in [(S*0.24, -1.0), (S*0.76, 1.0)] as [(CGFloat, CGFloat)] {
            let p = NSBezierPath()
            p.move(to: NSPoint(x: cx + sign * S*0.10, y: S*0.98))
            p.line(to: NSPoint(x: cx - sign * S*0.05, y: S*0.70))
            p.line(to: NSPoint(x: cx + sign * S*0.15, y: S*0.76))
            p.close()
            c.ear.setFill(); p.fill()
            let inner = NSBezierPath()
            inner.move(to: NSPoint(x: cx + sign * S*0.07, y: S*0.90))
            inner.line(to: NSPoint(x: cx, y: S*0.74))
            inner.line(to: NSPoint(x: cx + sign * S*0.10, y: S*0.76))
            inner.close()
            c.accent.withAlphaComponent(0.80).setFill(); inner.fill()
            stroke(p, 0)
        }
    }

    private static func longUpEars(c: CartoonColors, S: CGFloat,
                                   stroke: (NSBezierPath, CGFloat) -> Void) {
        for cx in [S*0.32, S*0.68] {
            let p = NSBezierPath(ovalIn: NSRect(x: cx - S*0.07, y: S*0.62, width: S*0.14, height: S*0.36))
            c.ear.setFill(); p.fill()
            let inner = NSBezierPath(ovalIn: NSRect(x: cx - S*0.035, y: S*0.66, width: S*0.07, height: S*0.26))
            c.earDk.setFill(); inner.fill()
            stroke(p, 0)
        }
    }

    private static func hornEar(c: CartoonColors, S: CGFloat,
                                stroke: (NSBezierPath, CGFloat) -> Void) {
        let p = NSBezierPath()
        p.move(to: NSPoint(x: S*0.44, y: S*0.86))
        p.line(to: NSPoint(x: S*0.50, y: S*1.00))
        p.line(to: NSPoint(x: S*0.56, y: S*0.86))
        p.close()
        c.accent.setFill(); p.fill()
        stroke(p, 0)
    }

    // MARK: 头部花纹(被裁剪在头形内)
    private static func drawHeadPatches(species: Species, c: CartoonColors, S: CGFloat) {
        switch species {
        case .shiba, .fox:
            // 白脸/白下巴：大椭圆覆盖下半脸
            c.secondary.setFill()
            NSBezierPath(ovalIn: NSRect(x: S*0.20, y: S*0.27, width: S*0.60, height: S*0.40)).fill()
        case .panda:
            // 黑色眼圈(两块斜向椭圆)
            c.secondary.setFill()
            let lp = NSBezierPath(ovalIn: NSRect(x: S*0.21, y: S*0.49, width: S*0.20, height: S*0.18))
            let rp = NSBezierPath(ovalIn: NSRect(x: S*0.59, y: S*0.49, width: S*0.20, height: S*0.18))
            lp.fill(); rp.fill()
        case .penguin:
            // 白脸面具
            c.secondary.setFill()
            NSBezierPath(ovalIn: NSRect(x: S*0.18, y: S*0.30, width: S*0.64, height: S*0.42)).fill()
        case .calico:
            // 三花橘斑(头右上一块、左额一块)
            c.ear.setFill()   // 橘色
            NSBezierPath(ovalIn: NSRect(x: S*0.58, y: S*0.68, width: S*0.22, height: S*0.18)).fill()
            NSBezierPath(ovalIn: NSRect(x: S*0.16, y: S*0.55, width: S*0.16, height: S*0.14)).fill()
            // 黑斑
            c.secondary.setFill()
            NSBezierPath(ovalIn: NSRect(x: S*0.42, y: S*0.74, width: S*0.16, height: S*0.12)).fill()
        case .hamster:
            // 浅色脸/肚区
            c.secondary.setFill()
            NSBezierPath(ovalIn: NSRect(x: S*0.22, y: S*0.30, width: S*0.56, height: S*0.32)).fill()
        case .frog:
            // 浅黄绿下颌
            c.secondary.setFill()
            NSBezierPath(ovalIn: NSRect(x: S*0.20, y: S*0.27, width: S*0.60, height: S*0.30)).fill()
        default: break
        }
    }

    // MARK: 腮红
    private static func drawCheeks(species: Species, c: CartoonColors, S: CGFloat) {
        // 仓鼠：鼓鼓的大腮帮子(更圆更亮)
        if species == .hamster {
            c.cheek.setFill()
            NSBezierPath(ovalIn: NSRect(x: S*0.16, y: S*0.40, width: S*0.14, height: S*0.10)).fill()
            NSBezierPath(ovalIn: NSRect(x: S*0.70, y: S*0.40, width: S*0.14, height: S*0.10)).fill()
            return
        }
        // 企鹅/青蛙：不画腮红(造型不需要)
        if species == .penguin || species == .frog { return }
        let r: CGFloat = S * 0.05
        c.cheek.setFill()
        NSBezierPath(ovalIn: NSRect(x: S*0.22, y: S*0.42, width: r*2, height: r*2)).fill()
        NSBezierPath(ovalIn: NSRect(x: S*0.68, y: S*0.42, width: r*2, height: r*2)).fill()
    }

    // MARK: 眼睛
    private static func drawEyes(species: Species, mood: Mood, frame: Int,
                                 c: CartoonColors, S: CGFloat, lw: CGFloat) {
        let lx = S * 0.36, rx = S * 0.64
        // 青蛙：鼓眼(在头顶)
        if species == .frog {
            let eyeY = S * 0.78
            for cx in [S*0.32, S*0.68] {
                let r = S * 0.10
                NSColor.white.setFill()
                NSBezierPath(ovalIn: NSRect(x: cx-r, y: eyeY-r, width: r*2, height: r*2)).fill()
                c.outline.setStroke()
                let bd = NSBezierPath(ovalIn: NSRect(x: cx-r, y: eyeY-r, width: r*2, height: r*2))
                bd.lineWidth = lw*0.7; bd.stroke()
                if frame == 1 && mood == .happy { continue }
                let pr = r * 0.45
                c.eyeMain.setFill()
                NSBezierPath(ovalIn: NSRect(x: cx-pr, y: eyeY-pr*0.8, width: pr*2, height: pr*2)).fill()
            }
            return
        }
        let eyeY = S * 0.56
        // 眨眼帧
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
                let r = S * 0.085
                let rect = NSRect(x: cx - r, y: eyeY - r, width: r*2, height: r*2)
                NSColor.white.setFill(); NSBezierPath(ovalIn: rect).fill()
                c.outline.setStroke(); let p = NSBezierPath(ovalIn: rect); p.lineWidth = lw*0.85; p.stroke()
                let pr = r * 0.45
                c.eyeMain.setFill()
                NSBezierPath(ovalIn: NSRect(x: cx - pr, y: eyeY - pr, width: pr*2, height: pr*2)).fill()
                let sr = pr * 0.4
                NSColor.white.setFill()
                NSBezierPath(ovalIn: NSRect(x: cx - sr*0.3, y: eyeY + sr*0.5, width: sr*1.5, height: sr*1.5)).fill()
            case .worried:
                let r = S * 0.075
                c.eyeMain.setFill()
                NSBezierPath(ovalIn: NSRect(x: cx - r, y: eyeY - r*0.9, width: r*2, height: r*2)).fill()
                NSColor.white.setFill()
                NSBezierPath(ovalIn: NSRect(x: cx - r*0.30, y: eyeY + r*0.25, width: r*0.85, height: r*0.85)).fill()
                NSBezierPath(ovalIn: NSRect(x: cx + r*0.30, y: eyeY - r*0.15, width: r*0.35, height: r*0.35)).fill()
            default:
                let r = S * 0.085
                c.eyeMain.setFill()
                NSBezierPath(ovalIn: NSRect(x: cx - r, y: eyeY - r, width: r*2, height: r*2)).fill()
                NSColor.white.setFill()
                NSBezierPath(ovalIn: NSRect(x: cx - r*0.45, y: eyeY + r*0.20, width: r*0.85, height: r*0.85)).fill()
                NSBezierPath(ovalIn: NSRect(x: cx + r*0.25, y: eyeY - r*0.55, width: r*0.35, height: r*0.35)).fill()
            }
        }
    }

    // MARK: 鼻子
    private static func drawNose(species: Species, c: CartoonColors, S: CGFloat, lw: CGFloat) {
        switch species {
        case .dog, .shiba, .fox, .panda, .hamster:
            let r = S * 0.035
            let p = NSBezierPath(ovalIn: NSRect(x: S*0.50 - r, y: S*0.46, width: r*2, height: r*1.7))
            c.outline.setFill(); p.fill()
        case .cat, .calico:
            let p = NSBezierPath()
            p.move(to: NSPoint(x: S*0.46, y: S*0.485))
            p.line(to: NSPoint(x: S*0.54, y: S*0.485))
            p.line(to: NSPoint(x: S*0.50, y: S*0.44))
            p.close()
            c.accent.setFill(); p.fill()
            c.outline.setStroke(); p.lineWidth = lw*0.55; p.stroke()
        case .rabbit:
            let p = NSBezierPath()
            p.move(to: NSPoint(x: S*0.50, y: S*0.44))
            p.curve(to: NSPoint(x: S*0.46, y: S*0.49),
                    controlPoint1: NSPoint(x: S*0.47, y: S*0.44),
                    controlPoint2: NSPoint(x: S*0.46, y: S*0.47))
            p.line(to: NSPoint(x: S*0.50, y: S*0.475))
            p.line(to: NSPoint(x: S*0.54, y: S*0.49))
            p.curve(to: NSPoint(x: S*0.50, y: S*0.44),
                    controlPoint1: NSPoint(x: S*0.54, y: S*0.47),
                    controlPoint2: NSPoint(x: S*0.53, y: S*0.44))
            p.close()
            c.accent.setFill(); p.fill()
            c.outline.setStroke(); p.lineWidth = lw*0.5; p.stroke()
        case .monster:
            let r = S * 0.028
            let p = NSBezierPath(ovalIn: NSRect(x: S*0.50 - r, y: S*0.46, width: r*2, height: r*2))
            c.outline.setFill(); p.fill()
        case .penguin:
            // 橙色三角喙(尖端朝下)
            let p = NSBezierPath()
            p.move(to: NSPoint(x: S*0.42, y: S*0.50))
            p.line(to: NSPoint(x: S*0.58, y: S*0.50))
            p.line(to: NSPoint(x: S*0.50, y: S*0.36))
            p.close()
            c.accent.setFill(); p.fill()
            c.outline.setStroke(); p.lineWidth = lw*0.6; p.stroke()
            // 喙中线
            let mid = NSBezierPath()
            mid.move(to: NSPoint(x: S*0.42, y: S*0.50))
            mid.line(to: NSPoint(x: S*0.58, y: S*0.50))
            mid.lineWidth = lw*0.4; mid.stroke()
        case .frog:
            // 两个小鼻孔
            c.outline.setFill()
            NSBezierPath(ovalIn: NSRect(x: S*0.47, y: S*0.55, width: S*0.018, height: S*0.018)).fill()
            NSBezierPath(ovalIn: NSRect(x: S*0.515, y: S*0.55, width: S*0.018, height: S*0.018)).fill()
        }
    }

    // MARK: 嘴
    private static func drawMouth(species: Species, mood: Mood, frame: Int, c: CartoonColors,
                                  S: CGFloat, lw: CGFloat,
                                  stroke: (NSBezierPath, CGFloat) -> Void) {
        let mouthY = S * 0.40
        // 企鹅嘴融入喙，不画
        if species == .penguin { return }
        // 青蛙嘴：宽大跨脸
        if species == .frog {
            let m = NSBezierPath()
            switch mood {
            case .happy:
                m.move(to: NSPoint(x: S*0.22, y: S*0.46))
                m.curve(to: NSPoint(x: S*0.78, y: S*0.46),
                        controlPoint1: NSPoint(x: S*0.36, y: S*0.32),
                        controlPoint2: NSPoint(x: S*0.64, y: S*0.32))
                stroke(m, lw*1.1)
            case .panic:
                let r = NSRect(x: S*0.36, y: S*0.36, width: S*0.28, height: S*0.10)
                rgb(0.90,0.25,0.20).setFill()
                NSBezierPath(ovalIn: r).fill()
                stroke(NSBezierPath(ovalIn: r), 0)
            default:
                m.move(to: NSPoint(x: S*0.28, y: S*0.44))
                m.curve(to: NSPoint(x: S*0.72, y: S*0.44),
                        controlPoint1: NSPoint(x: S*0.40, y: S*0.38),
                        controlPoint2: NSPoint(x: S*0.60, y: S*0.38))
                stroke(m, lw*0.9)
            }
            return
        }
        switch mood {
        case .happy:
            switch species {
            case .cat, .calico, .fox:
                let m = NSBezierPath()
                m.move(to: NSPoint(x: S*0.42, y: mouthY))
                m.curve(to: NSPoint(x: S*0.50, y: mouthY - S*0.005),
                        controlPoint1: NSPoint(x: S*0.45, y: mouthY - S*0.035),
                        controlPoint2: NSPoint(x: S*0.475, y: mouthY - S*0.035))
                m.curve(to: NSPoint(x: S*0.58, y: mouthY),
                        controlPoint1: NSPoint(x: S*0.525, y: mouthY - S*0.035),
                        controlPoint2: NSPoint(x: S*0.55, y: mouthY - S*0.035))
                stroke(m, lw * 0.9)
            case .rabbit:
                let m = NSBezierPath()
                m.move(to: NSPoint(x: S*0.46, y: mouthY))
                m.line(to: NSPoint(x: S*0.50, y: mouthY - S*0.025))
                m.line(to: NSPoint(x: S*0.54, y: mouthY))
                stroke(m, lw * 0.9)
            case .hamster:
                let m = NSBezierPath()
                m.move(to: NSPoint(x: S*0.46, y: mouthY - S*0.01))
                m.curve(to: NSPoint(x: S*0.54, y: mouthY - S*0.01),
                        controlPoint1: NSPoint(x: S*0.48, y: mouthY - S*0.03),
                        controlPoint2: NSPoint(x: S*0.52, y: mouthY - S*0.03))
                stroke(m, lw * 0.8)
            default:
                let m = NSBezierPath()
                m.move(to: NSPoint(x: S*0.42, y: mouthY))
                m.curve(to: NSPoint(x: S*0.58, y: mouthY),
                        controlPoint1: NSPoint(x: S*0.45, y: mouthY - S*0.07),
                        controlPoint2: NSPoint(x: S*0.55, y: mouthY - S*0.07))
                m.line(to: NSPoint(x: S*0.42, y: mouthY))
                m.close(); c.outline.setFill(); m.fill()
                let tongue = NSBezierPath(ovalIn: NSRect(x: S*0.46, y: mouthY - S*0.06, width: S*0.08, height: S*0.04))
                c.accent.setFill(); tongue.fill()
            }
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
            let w: CGFloat = frame == 0 ? S*0.16 : S*0.20
            let h: CGFloat = frame == 0 ? S*0.10 : S*0.08
            let m = NSBezierPath(ovalIn: NSRect(x: S*0.50 - w/2, y: mouthY - h*0.6, width: w, height: h))
            rgb(0.90,0.25,0.20).setFill(); m.fill()
            stroke(m, 0)
        }
    }

    // MARK: 物种额外特征
    private static func drawExtras(species: Species, mood: Mood,
                                   c: CartoonColors, S: CGFloat, lw: CGFloat) {
        switch species {
        case .cat, .calico, .fox:
            // 猫胡须
            let wW: CGFloat = max(1, S * 0.012)
            let bL = bodyLuminance(c.body)
            let wc = bL < 0.4 ? NSColor(white: 0.88, alpha: 0.95)
                              : NSColor(white: 0.32, alpha: 0.85)
            wc.setStroke()
            for sign in [-1.0, 1.0] as [CGFloat] {
                for dyFactor in [-1.4, 0.0, 1.4] {
                    let p = NSBezierPath()
                    let baseY = S * 0.46
                    let x1 = S*0.50 + sign * S*0.06
                    let x2 = S*0.50 + sign * S*0.20
                    p.move(to: NSPoint(x: x1, y: baseY + S * 0.012 * CGFloat(dyFactor)))
                    p.line(to: NSPoint(x: x2, y: baseY + S * 0.018 * CGFloat(dyFactor)))
                    p.lineWidth = wW; p.stroke()
                }
            }
        case .rabbit:
            // 兔门牙(慌张除外)
            if mood != .panic {
                let tw = S * 0.038, th = S * 0.055
                let ty = S * 0.40 - th - S*0.005
                NSColor.white.setFill()
                for dx in [-1.0, 1.0] as [CGFloat] {
                    let r = NSRect(x: S*0.50 + dx * S*0.003 + (dx < 0 ? -tw : 0),
                                   y: ty, width: tw, height: th)
                    let p = NSBezierPath(roundedRect: r, xRadius: S*0.01, yRadius: S*0.01)
                    p.fill()
                    c.outline.setStroke(); p.lineWidth = lw*0.45; p.stroke()
                }
            }
            // 小胡须
            let bL = bodyLuminance(c.body)
            let wc = bL < 0.4 ? NSColor(white: 0.85, alpha: 0.85)
                              : NSColor(white: 0.40, alpha: 0.80)
            wc.setStroke()
            for sign in [-1.0, 1.0] as [CGFloat] {
                for dyf in [-0.8, 0.8] as [CGFloat] {
                    let p = NSBezierPath()
                    let baseY = S * 0.46
                    p.move(to: NSPoint(x: S*0.50 + sign * S*0.08, y: baseY + S*0.010*dyf))
                    p.line(to: NSPoint(x: S*0.50 + sign * S*0.18, y: baseY + S*0.018*dyf))
                    p.lineWidth = max(1, S * 0.010); p.stroke()
                }
            }
        default: break
        }
    }

    private static func drawSweat(frame: Int, S: CGFloat, lw: CGFloat,
                                  stroke: (NSBezierPath, CGFloat) -> Void) {
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
}
