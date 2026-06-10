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

func rgb(_ r: Double, _ g: Double, _ b: Double) -> NSColor {
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

