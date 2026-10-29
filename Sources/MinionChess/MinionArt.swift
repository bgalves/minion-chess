import SwiftUI

/// Original vector drawings of little yellow goggle-wearing henchmen, one costume per chess piece.
struct MinionPalette {
    var skin: Color, overalls: Color, accent: Color
    static func palette(style: String, side: Side) -> MinionPalette {
        if side == .white { return MinionPalette(skin: Color(red: 1, green: 0.84, blue: 0.1), overalls: Color(red: 0.2, green: 0.4, blue: 0.75), accent: Color(red: 0.95, green: 0.95, blue: 0.9)) }
        switch style {
        case "Grey": return MinionPalette(skin: Color(red: 0.62, green: 0.65, blue: 0.7), overalls: Color(red: 0.15, green: 0.15, blue: 0.2), accent: Color(red: 0.2, green: 0.2, blue: 0.25))
        case "Green": return MinionPalette(skin: Color(red: 0.45, green: 0.75, blue: 0.3), overalls: Color(red: 0.25, green: 0.2, blue: 0.35), accent: Color(red: 0.2, green: 0.3, blue: 0.2))
        default: return MinionPalette(skin: Color(red: 0.55, green: 0.32, blue: 0.75), overalls: Color(red: 0.18, green: 0.14, blue: 0.3), accent: Color(red: 0.25, green: 0.15, blue: 0.4))
        }
    }
}

struct MinionView: View {
    let kind: Kind
    let side: Side
    var style: String = "Classic"

    var body: some View {
        Canvas { ctx, size in draw(&ctx, size) }
            .shadow(color: .black.opacity(0.35), radius: 2, x: 1, y: 2)
    }

    private func scale() -> CGFloat { [0.6, 0.72, 0.76, 0.78, 0.8, 0.8][kind.rawValue] }
    private func eyes() -> Int { (kind == .pawn || kind == .knight) ? 1 : 2 }

    private func draw(_ ctx: inout GraphicsContext, _ size: CGSize) {
        let pal = MinionPalette.palette(style: style, side: side)
        let sc = scale()
        let h = size.height * 0.9 * sc, w = h * 0.5
        let cx = size.width / 2, bottom = size.height * 0.95
        let top = bottom - h
        let body = CGRect(x: cx - w / 2, y: top, width: w, height: h)
        let dark = Color.black.opacity(0.75)

        // accessories behind the body
        if kind == .king {   // cape
            var cape = Path()
            cape.move(to: CGPoint(x: cx - w * 0.5, y: top + h * 0.3))
            cape.addQuadCurve(to: CGPoint(x: cx - w * 0.75, y: bottom), control: CGPoint(x: cx - w * 0.7, y: top + h * 0.6))
            cape.addLine(to: CGPoint(x: cx + w * 0.75, y: bottom))
            cape.addQuadCurve(to: CGPoint(x: cx + w * 0.5, y: top + h * 0.3), control: CGPoint(x: cx + w * 0.7, y: top + h * 0.6))
            ctx.fill(cape, with: .color(Color(red: 0.75, green: 0.1, blue: 0.15)))
        }
        if kind == .queen {   // long hair
            let hair = Color(red: 0.35, green: 0.2, blue: 0.1)
            ctx.fill(Path(roundedRect: CGRect(x: cx - w * 0.62, y: top + h * 0.08, width: w * 1.24, height: h * 0.55), cornerRadius: w * 0.5), with: .color(hair))
        }

        // body capsule
        let cap = Path(roundedRect: body, cornerRadius: w / 2)
        ctx.fill(cap, with: .linearGradient(Gradient(colors: [pal.skin.opacity(1), pal.skin.opacity(0.78)]),
                                            startPoint: CGPoint(x: body.minX, y: body.minY), endPoint: CGPoint(x: body.maxX, y: body.maxY)))
        ctx.stroke(cap, with: .color(dark.opacity(0.5)), lineWidth: 1.2)

        // overalls
        var ov = Path()
        let oy = top + h * 0.58
        ov.move(to: CGPoint(x: body.minX, y: oy))
        ov.addLine(to: CGPoint(x: body.maxX, y: oy))
        ov.addLine(to: CGPoint(x: body.maxX, y: bottom - w / 2))
        ov.addArc(center: CGPoint(x: cx, y: bottom - w / 2), radius: w / 2, startAngle: .degrees(0), endAngle: .degrees(180), clockwise: false)
        ov.addLine(to: CGPoint(x: body.minX, y: oy))
        ctx.fill(ov, with: .color(pal.overalls))
        ctx.fill(Path(roundedRect: CGRect(x: cx - w * 0.22, y: oy + h * 0.06, width: w * 0.44, height: h * 0.1), cornerRadius: 2), with: .color(.black.opacity(0.25)))
        // straps
        ctx.stroke(Path { $0.move(to: CGPoint(x: body.minX + w * 0.1, y: oy + 2)); $0.addLine(to: CGPoint(x: body.minX + w * 0.3, y: oy - h * 0.1)) },
                   with: .color(pal.overalls), lineWidth: 2)
        ctx.stroke(Path { $0.move(to: CGPoint(x: body.maxX - w * 0.1, y: oy + 2)); $0.addLine(to: CGPoint(x: body.maxX - w * 0.3, y: oy - h * 0.1)) },
                   with: .color(pal.overalls), lineWidth: 2)

        // arms (queen/king raise one)
        let armY = top + h * 0.64
        ctx.fill(Path(ellipseIn: CGRect(x: body.minX - w * 0.14, y: armY, width: w * 0.26, height: h * 0.18)), with: .color(pal.skin))
        ctx.fill(Path(ellipseIn: CGRect(x: body.maxX - w * 0.12, y: armY, width: w * 0.26, height: h * 0.18)), with: .color(pal.skin))

        // goggles
        let gy = top + h * (kind == .pawn ? 0.24 : 0.28)
        let band = CGRect(x: body.minX - 1, y: gy - h * 0.025, width: w + 2, height: h * 0.05)
        ctx.fill(Path(band), with: .color(.black.opacity(0.85)))
        let n = eyes()
        let er = (n == 1 ? w * 0.34 : w * 0.25)
        for i in 0..<n {
            let ex = n == 1 ? cx : cx + (i == 0 ? -er * 1.05 : er * 1.05)
            let rim = CGRect(x: ex - er, y: gy - er, width: er * 2, height: er * 2)
            ctx.fill(Path(ellipseIn: rim), with: .color(Color(white: 0.7)))
            ctx.stroke(Path(ellipseIn: rim), with: .color(Color(white: 0.35)), lineWidth: 1.5)
            let eye = rim.insetBy(dx: er * 0.22, dy: er * 0.22)
            ctx.fill(Path(ellipseIn: eye), with: .color(.white))
            let pr = er * 0.32
            ctx.fill(Path(ellipseIn: CGRect(x: ex - pr * 0.8, y: gy - pr, width: pr * 2, height: pr * 2)), with: .color(Color(red: 0.3, green: 0.18, blue: 0.08)))
            ctx.fill(Path(ellipseIn: CGRect(x: ex - pr * 0.2, y: gy - pr * 0.6, width: pr * 0.7, height: pr * 0.7)), with: .color(.black))
        }

        // mouth
        let my = gy + er + h * 0.07
        var mouth = Path()
        mouth.move(to: CGPoint(x: cx - w * 0.18, y: my))
        mouth.addQuadCurve(to: CGPoint(x: cx + w * 0.18, y: my), control: CGPoint(x: cx, y: my + h * (kind == .king ? 0.02 : 0.07)))
        ctx.stroke(mouth, with: .color(dark), lineWidth: 1.5)
        if kind == .king {  // beard
            ctx.fill(Path(ellipseIn: CGRect(x: cx - w * 0.28, y: my + 2, width: w * 0.56, height: h * 0.1)), with: .color(.white.opacity(0.9)))
        }
        if kind == .queen {  // lashes + lips
            ctx.fill(Path(ellipseIn: CGRect(x: cx - w * 0.1, y: my - 1, width: w * 0.2, height: h * 0.035)), with: .color(Color(red: 0.85, green: 0.15, blue: 0.3)))
        }

        // headwear (the piece identity)
        let hy = top + 2
        switch kind {
        case .pawn:
            for dx in [-0.12, 0.0, 0.12] {
                ctx.stroke(Path { $0.move(to: CGPoint(x: cx + w * dx, y: hy + 2)); $0.addQuadCurve(to: CGPoint(x: cx + w * dx * 2.2, y: hy - h * 0.14), control: CGPoint(x: cx + w * dx * 0.5, y: hy - h * 0.1)) },
                           with: .color(.black.opacity(0.8)), lineWidth: 1.4)
            }
        case .knight:   // helmet with plume + visor
            var helm = Path(); helm.addArc(center: CGPoint(x: cx, y: top + w / 2), radius: w * 0.52, startAngle: .degrees(180), endAngle: .degrees(0), clockwise: false)
            helm.closeSubpath()
            ctx.fill(helm, with: .color(Color(white: 0.6))); ctx.stroke(helm, with: .color(.black.opacity(0.6)), lineWidth: 1.2)
            ctx.fill(Path(ellipseIn: CGRect(x: cx - w * 0.1, y: hy - h * 0.12, width: w * 0.5, height: h * 0.14)), with: .color(Color(red: 0.8, green: 0.1, blue: 0.1)))
            ctx.fill(Path(CGRect(x: cx - w * 0.5, y: top + w * 0.5 - 2, width: w, height: 3)), with: .color(Color(white: 0.4)))
        case .bishop:   // mitre
            var m = Path(); m.move(to: CGPoint(x: cx - w * 0.38, y: top + h * 0.1))
            m.addQuadCurve(to: CGPoint(x: cx, y: hy - h * 0.22), control: CGPoint(x: cx - w * 0.4, y: hy - h * 0.12))
            m.addQuadCurve(to: CGPoint(x: cx + w * 0.38, y: top + h * 0.1), control: CGPoint(x: cx + w * 0.4, y: hy - h * 0.12))
            m.closeSubpath()
            ctx.fill(m, with: .color(.white)); ctx.stroke(m, with: .color(.black.opacity(0.6)), lineWidth: 1.2)
            ctx.fill(Path(CGRect(x: cx - 1.5, y: hy - h * 0.16, width: 3, height: h * 0.18)), with: .color(Color(red: 0.9, green: 0.7, blue: 0.1)))
            ctx.fill(Path(CGRect(x: cx - w * 0.1, y: hy - h * 0.1, width: w * 0.2, height: 3)), with: .color(Color(red: 0.9, green: 0.7, blue: 0.1)))
        case .rook:     // stone tower hat
            let t = CGRect(x: cx - w * 0.42, y: hy - h * 0.14, width: w * 0.84, height: h * 0.2)
            ctx.fill(Path(t), with: .color(Color(white: 0.62))); ctx.stroke(Path(t), with: .color(.black.opacity(0.6)), lineWidth: 1.2)
            for i in 0..<3 {
                let bw = t.width / 5
                let r = CGRect(x: t.minX + bw * CGFloat(i * 2), y: t.minY - h * 0.05, width: bw, height: h * 0.05)
                ctx.fill(Path(r), with: .color(Color(white: 0.62))); ctx.stroke(Path(r), with: .color(.black.opacity(0.6)), lineWidth: 1)
            }
            ctx.fill(Path(CGRect(x: cx - w * 0.06, y: t.minY + h * 0.05, width: w * 0.12, height: h * 0.1)), with: .color(.black.opacity(0.5)))
        case .queen, .king:
            let gold = Color(red: 0.95, green: 0.72, blue: 0.12)
            let cw = w * 0.8, ch = h * 0.13
            var c = Path()
            c.move(to: CGPoint(x: cx - cw / 2, y: hy + 3))
            c.addLine(to: CGPoint(x: cx - cw / 2, y: hy - ch))
            c.addLine(to: CGPoint(x: cx - cw / 4, y: hy - ch * 0.4))
            c.addLine(to: CGPoint(x: cx, y: hy - ch * 1.3))
            c.addLine(to: CGPoint(x: cx + cw / 4, y: hy - ch * 0.4))
            c.addLine(to: CGPoint(x: cx + cw / 2, y: hy - ch))
            c.addLine(to: CGPoint(x: cx + cw / 2, y: hy + 3))
            c.closeSubpath()
            ctx.fill(c, with: .color(gold)); ctx.stroke(c, with: .color(.black.opacity(0.6)), lineWidth: 1.2)
            if kind == .king {
                ctx.fill(Path(CGRect(x: cx - 1.5, y: hy - ch * 2.1, width: 3, height: ch * 0.9)), with: .color(gold))
                ctx.fill(Path(CGRect(x: cx - 4, y: hy - ch * 1.8, width: 8, height: 3)), with: .color(gold))
            } else {
                ctx.fill(Path(ellipseIn: CGRect(x: cx - 3, y: hy - ch * 1.6, width: 6, height: 6)), with: .color(Color(red: 0.85, green: 0.1, blue: 0.3)))
                ctx.fill(Path(ellipseIn: CGRect(x: body.maxX - w * 0.05, y: top + h * 0.18, width: w * 0.3, height: w * 0.22)), with: .color(.pink))
            }
        }
    }
}
