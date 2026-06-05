import Cocoa

// 调色板：字符 -> 颜色。'.' 与空格(及未定义字符)表示透明。
typealias Palette = [Character: NSColor]

enum PixelRenderer {
    /// 把字符网格渲染成 NSImage。每个字符 = scale×scale 像素方块。
    /// 行长度不一致时按最大宽度右侧补透明。
    static func image(from grid: [String], scale: CGFloat, palette: Palette) -> NSImage {
        let cols = grid.map { $0.count }.max() ?? 0
        let h = grid.count
        let img = NSImage(size: NSSize(width: CGFloat(cols) * scale, height: CGFloat(h) * scale))
        img.lockFocus()
        let ctx = NSGraphicsContext.current!.cgContext
        ctx.interpolationQuality = .none
        ctx.setShouldAntialias(false)
        for (r, line) in grid.enumerated() {
            for (c, ch) in line.enumerated() {
                guard let color = palette[ch] else { continue }   // 未定义=透明
                let rect = NSRect(x: CGFloat(c) * scale,
                                  y: CGFloat(h - 1 - r) * scale,
                                  width: scale, height: scale)
                color.setFill()
                ctx.fill(rect)
            }
        }
        img.unlockFocus()
        return img
    }
}

// 便捷构造颜色
func rgb(_ r: Double, _ g: Double, _ b: Double) -> NSColor {
    NSColor(srgbRed: r, green: g, blue: b, alpha: 1)
}
