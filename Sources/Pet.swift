import Cocoa

// MARK: - 心情状态(由用量百分比决定)
enum Mood: Int {
    case happy    // 0-50%
    case neutral  // 50-80%
    case worried  // 80-95%
    case panic    // 95%+

    static func from(utilization: Double) -> Mood {
        switch utilization {
        case ..<50:  return .happy
        case ..<80:  return .neutral
        case ..<95:  return .worried
        default:     return .panic
        }
    }
}

// MARK: - 形象
struct Skin {
    let id: String
    let name: String
    let palette: Palette
    let gridsFor: (Mood) -> [[String]]

    func frames(for mood: Mood, scale: CGFloat) -> [NSImage] {
        gridsFor(mood).map { PixelRenderer.image(from: $0, scale: scale, palette: palette) }
    }
}

enum Skins {
    static let all: [Skin] = [dog, orangeCat, blackCat, creamCat, rabbit, monster]
    static func byId(_ id: String) -> Skin { all.first { $0.id == id } ?? dog }

    // 覆盖整行
    private static func make(_ base: [String], _ overrides: [Int: String]) -> [String] {
        var g = base
        for (i, row) in overrides { if i >= 0 && i < g.count { g[i] = row } }
        return g
    }

    // ============================================================
    // 猫/兔/怪兽 通用脸：内容 12 字符，".o"+内容+"o."，脸在第 6-9 行
    // ============================================================
    private static func cFace(_ s: String) -> String {
        precondition(s.count == 12, "cFace 需 12 字符: \(s)")
        return ".o" + s + "o."
    }
    /// 基于给定身体底板，套用通用表情，返回某心情的两帧
    private static func catStyle(_ base: [String], _ mood: Mood) -> [[String]] {
        switch mood {
        case .happy:
            return [
                make(base, [7: cFace("fffeffffefff"), 8: cFace("fffffppfffff"), 9: cFace("ffffooooffff")]),
                make(base, [7: cFace("fffoffffofff"), 8: cFace("fffffppfffff"), 9: cFace("ffffooooffff")]),
            ]
        case .neutral:
            return [
                make(base, [7: cFace("fffeffffefff"), 8: cFace("fffffppfffff"), 9: cFace("fffffoofffff")]),
                make(base, [7: cFace("fffoffffofff"), 8: cFace("fffffppfffff"), 9: cFace("fffffoofffff")]),
            ]
        case .worried:
            return [
                make(base, [6: cFace("fffeffffefff"), 7: cFace("ffffffffffff"), 8: cFace("fffffppfffff"), 9: cFace("fffoofooffff")]),
                make(base, [6: cFace("fffeffffefff"), 7: cFace("ffffffffffff"), 8: cFace("fffffppfffff"), 9: cFace("ffoofoofffff")]),
            ]
        case .panic:
            return [
                make(base, [6: cFace("fffwffffwfff"), 7: cFace("fffeffffefff"), 8: cFace("fffffppffffs"), 9: cFace("fffxxxxxxfff")]),
                make(base, [6: cFace("fffwffffwfff"), 7: cFace("fffeffffefff"), 8: cFace("sffffppfffff"), 9: cFace("ffxxxxxxxxff")]),
            ]
        }
    }

    // ---- 通用底板(尖耳猫) ----
    private static let catBase: [String] = [
        "..o........o....", "..oo......oo....", "..ofo....ofo....",
        "..offooooooffo..", "..offffffffffo..", ".offffffffffffo.",
        ".offffffffffffo.", ".offffffffffffo.", ".offffffffffffo.",
        ".offffffffffffo.", ".ofbbffffffbbfo.", ".offbbbbbbbbffo.",
        "..offbbbbbbffo..", "..oFo.bbbb.oFo..", "...ooo....ooo...",
        "................",
    ]
    // ---- 兔子底板(立耳+粉内耳) ----
    private static let rabbitBase: [String] = make(catBase, [
        0: "...ooo...ooo....",
        1: "...opo...opo....",
        2: "...opo...opo....",
    ])
    // ---- 小怪兽底板(独角) ----
    private static let monsterBase: [String] = [
        ".......o........", "......ooo.......", ".....offfo......",
        "...offffffffo...", "..offffffffffo..", ".offffffffffffo.",
        ".offffffffffffo.", ".offffffffffffo.", ".offffffffffffo.",
        ".offffffffffffo.", ".offffffffffffo.", "..offffffffffo..",
        "...offffffffo...", "...oFo....oFo...", "...ooo....ooo...",
        "................",
    ]

    // ============================================================
    // 小狗(垂耳) 专用脸：内容 9 字符
    // ============================================================
    private static func dFace(_ s: String) -> String {
        precondition(s.count == 9, "dFace 需 9 字符: \(s)")
        return ".oo" + s + "o..."
    }
    private static let dogBase: [String] = [
        "................", "....oooooo......", "..ggoffffoogg...",
        ".gggffffffggg...", ".oggffffffggo...", ".oofffffffffo...",
        ".oofffffffffo...", ".oggfffffffgo...", "..offffffffo....",
        "..offffffffo....", "..obffffffbo....", "...obbffbbo.....",
        "...obbffbbo.....", "...oFo.oFo......", "...ooo.ooo......",
        "................",
    ]
    private static func dogStyle(_ mood: Mood) -> [[String]] {
        let b = dogBase
        switch mood {
        case .happy:
            return [ make(b, [5: dFace("fefffffef"), 8: dFace("fffeeefff"), 9: dFace("fffpppfff")]),
                     make(b, [5: dFace("fofffffof"), 8: dFace("fffeeefff"), 9: dFace("fffpppfff")]) ]
        case .neutral:
            return [ make(b, [5: dFace("fefffffef"), 8: dFace("fffeeefff"), 9: dFace("ffffoffff")]),
                     make(b, [5: dFace("fofffffof"), 8: dFace("fffeeefff"), 9: dFace("ffffoffff")]) ]
        case .worried:
            return [ make(b, [5: dFace("fefffffef"), 8: dFace("fffeeefff"), 9: dFace("ffoooooff")]),
                     make(b, [5: dFace("fefffffef"), 8: dFace("fffeeefff"), 9: dFace("fffooooff")]) ]
        case .panic:
            return [ make(b, [4: ".oggffffffggos..", 5: dFace("fwfffffwf"), 6: dFace("fefffffef"), 8: dFace("fffeeefff"), 9: dFace("ffxxxxxff")]),
                     make(b, [4: "soggffffffggo...", 5: dFace("fwfffffwf"), 6: dFace("fefffffef"), 8: dFace("fffeeefff"), 9: dFace("fxxxxxxxf")]) ]
        }
    }

    // ============================================================
    // 调色板
    // ============================================================
    private static let pOrange: Palette = [
        "o": rgb(0.20,0.13,0.10), "f": rgb(0.85,0.47,0.34), "F": rgb(0.78,0.40,0.28),
        "b": rgb(0.98,0.92,0.86), "p": rgb(0.95,0.62,0.62), "e": rgb(0.12,0.09,0.08),
        "w": .white, "s": rgb(0.40,0.70,0.98), "x": rgb(0.90,0.25,0.20),
    ]
    private static let pBlack: Palette = [
        "o": rgb(0.08,0.08,0.10), "f": rgb(0.20,0.20,0.23), "F": rgb(0.13,0.13,0.16),
        "b": rgb(0.34,0.34,0.38), "p": rgb(0.85,0.45,0.55), "e": rgb(0.55,0.85,0.45),
        "w": .white, "s": rgb(0.40,0.70,0.98), "x": rgb(0.95,0.35,0.30),
    ]
    private static let pCream: Palette = [
        "o": rgb(0.30,0.28,0.26), "f": rgb(0.96,0.93,0.86), "F": rgb(0.82,0.80,0.76),
        "b": rgb(0.99,0.98,0.96), "p": rgb(0.95,0.62,0.62), "e": rgb(0.15,0.13,0.12),
        "w": .white, "s": rgb(0.40,0.70,0.98), "x": rgb(0.90,0.25,0.20),
    ]
    private static let pDog: Palette = [
        "o": rgb(0.28,0.26,0.25), "f": rgb(0.96,0.93,0.86), "F": rgb(0.82,0.80,0.76),
        "b": rgb(0.99,0.98,0.96), "g": rgb(0.64,0.62,0.59), "p": rgb(0.95,0.62,0.62),
        "e": rgb(0.15,0.13,0.12), "w": .white, "s": rgb(0.40,0.70,0.98), "x": rgb(0.90,0.25,0.20),
    ]
    private static let pRabbit: Palette = [
        "o": rgb(0.32,0.28,0.30), "f": rgb(0.97,0.95,0.93), "F": rgb(0.85,0.83,0.82),
        "b": rgb(1.0,0.99,0.98), "p": rgb(0.95,0.62,0.66), "e": rgb(0.20,0.16,0.18),
        "w": .white, "s": rgb(0.40,0.70,0.98), "x": rgb(0.90,0.30,0.30),
    ]
    private static let pMonster: Palette = [
        "o": rgb(0.22,0.16,0.34), "f": rgb(0.58,0.46,0.82), "F": rgb(0.48,0.36,0.72),
        "b": rgb(0.72,0.62,0.92), "p": rgb(0.95,0.62,0.72), "e": rgb(0.12,0.10,0.16),
        "w": .white, "s": rgb(0.40,0.70,0.98), "x": rgb(0.95,0.35,0.45),
    ]

    // ============================================================
    // 形象注册
    // ============================================================
    static let dog       = Skin(id: "dog",    name: "🐶 奶白小狗", palette: pDog,     gridsFor: { dogStyle($0) })
    static let orangeCat = Skin(id: "ocat",   name: "🐱 橘猫",     palette: pOrange,  gridsFor: { catStyle(catBase, $0) })
    static let blackCat  = Skin(id: "bcat",   name: "🐈‍⬛ 黑猫",   palette: pBlack,   gridsFor: { catStyle(catBase, $0) })
    static let creamCat  = Skin(id: "ccat",   name: "🐱 奶白猫",   palette: pCream,   gridsFor: { catStyle(catBase, $0) })
    static let rabbit    = Skin(id: "rabbit", name: "🐰 小兔",     palette: pRabbit,  gridsFor: { catStyle(rabbitBase, $0) })
    static let monster   = Skin(id: "monster",name: "👾 小怪兽",   palette: pMonster, gridsFor: { catStyle(monsterBase, $0) })
}
