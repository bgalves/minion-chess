import Foundation

func perft(_ p: Position, _ d: Int) -> Int {
    if d == 0 { return 1 }
    let l = p.legalMoves()
    if d == 1 { return l.count }
    return l.reduce(0) { $0 + perft(p.applying($1), d - 1) }
}

func runSelfTest() {
    let s = Position.start(.normal)
    print("perft start d1-4:", (1...4).map { perft(s, $0) }, "expected [20, 400, 8902, 197281]")
    // Kiwipete-like castling/ep stress via scripted game: Scholar's mate
    var p = s
    for t in ["e4", "e5", "Qh5", "Nc6", "Bc4", "Nf6", "Qxf7#"] {
        let lg = p.legalMoves()
        guard let m = lg.first(where: { p.san($0, legal: lg) == t }) else { print("FAIL san", t); return }
        p = p.applying(m)
    }
    print("scholar mate:", p.outcome(legal: p.legalMoves())?.text ?? "none")
    for v in [Variant.crazyhouse, .losers, .suicide] {
        let e = Engine(); var q = Position.start(v); var n = 0
        while n < 30, let r = e.search(q, level: 2, seen: [:], cancelled: { false }), q.outcome(legal: q.legalMoves()) == nil {
            q = q.applying(r.move); n += 1 }
        print(v.rawValue, "self-play plies:", n, q.outcome(legal: q.legalMoves())?.text ?? "ongoing")
    }
}

import SwiftUI
@MainActor func renderPieces(to path: String) {
    let v = VStack(spacing: 0) {
        ForEach([Side.white, .black], id: \.self) { s in
            HStack(spacing: 0) { ForEach(Kind.allCases, id: \.self) { k in
                MinionView(kind: k, side: s).frame(width: 140, height: 140)
                    .background((k.rawValue + s.rawValue) % 2 == 0 ? Color(red: 0.62, green: 0.42, blue: 0.24) : Color(red: 0.93, green: 0.82, blue: 0.62)) } }
        }
    }
    let r = ImageRenderer(content: v); r.scale = 1
    if let img = r.nsImage, let tiff = img.tiffRepresentation, let rep = NSBitmapImageRep(data: tiff), let png = rep.representation(using: .png, properties: [:]) {
        try? png.write(to: URL(fileURLWithPath: path))
    }
}

@MainActor func renderIcon(to path: String) {
    let v = ZStack {
        RoundedRectangle(cornerRadius: 180).fill(LinearGradient(colors: [Color(red: 0.93, green: 0.82, blue: 0.62), Color(red: 0.62, green: 0.42, blue: 0.24)], startPoint: .top, endPoint: .bottom))
        HStack(spacing: -150) {
            MinionView(kind: .king, side: .white).frame(width: 600, height: 600)
            MinionView(kind: .queen, side: .black).frame(width: 600, height: 600)
        }.offset(y: 30)
    }.frame(width: 1024, height: 1024)
    let r = ImageRenderer(content: v); r.scale = 1
    if let img = r.nsImage, let tiff = img.tiffRepresentation, let rep = NSBitmapImageRep(data: tiff), let png = rep.representation(using: .png, properties: [:]) {
        try? png.write(to: URL(fileURLWithPath: path))
    }
}
