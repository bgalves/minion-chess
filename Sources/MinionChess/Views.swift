import SwiftUI

struct BoardTheme {
    var light: Color, dark: Color, frame: Color
    static func named(_ n: String) -> BoardTheme {
        switch n {
        case "Marble": return BoardTheme(light: Color(white: 0.93), dark: Color(red: 0.55, green: 0.58, blue: 0.62), frame: Color(white: 0.3))
        case "Metal": return BoardTheme(light: Color(white: 0.8), dark: Color(white: 0.42), frame: Color(white: 0.15))
        case "Grass": return BoardTheme(light: Color(red: 0.72, green: 0.88, blue: 0.5), dark: Color(red: 0.3, green: 0.55, blue: 0.25), frame: Color(red: 0.2, green: 0.3, blue: 0.15))
        case "Fur": return BoardTheme(light: Color(red: 0.95, green: 0.8, blue: 0.62), dark: Color(red: 0.7, green: 0.45, blue: 0.3), frame: Color(red: 0.35, green: 0.2, blue: 0.12))
        default: return BoardTheme(light: Color(red: 0.93, green: 0.82, blue: 0.62), dark: Color(red: 0.62, green: 0.42, blue: 0.24), frame: Color(red: 0.32, green: 0.2, blue: 0.1))
        }
    }
}
let boardStyles = ["Wood", "Marble", "Metal", "Grass", "Fur"]
let pieceStyles = ["Classic", "Grey", "Green"]

struct BoardView: View {
    @ObservedObject var game: Game
    @State private var dragFrom: Int?
    @State private var dragPoint: CGPoint = .zero

    var body: some View {
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height)
            let margin = side * 0.045
            let sq = (side - margin * 2) / 8
            let theme = BoardTheme.named(game.boardStyle)
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 8).fill(theme.frame)
                ForEach(0..<64, id: \.self) { s in
                    let (x, y) = pos(of: s, sq: sq, margin: margin)
                    Rectangle().fill(((s % 8 + s / 8) % 2 == 0) ? theme.dark : theme.light)
                        .frame(width: sq, height: sq).position(x: x, y: y)
                    if highlighted(s) { Rectangle().fill(Color.yellow.opacity(0.4)).frame(width: sq, height: sq).position(x: x, y: y) }
                    if game.pos.inCheck(game.pos.turn), game.pos.kingSquare(game.pos.turn) == s {
                        Circle().fill(RadialGradient(colors: [.red.opacity(0.8), .clear], center: .center, startRadius: 0, endRadius: sq * 0.6))
                            .frame(width: sq, height: sq).position(x: x, y: y)
                    }
                    if let p = game.pos.b[s], dragFrom != s {
                        MinionView(kind: p.kind, side: p.side, style: game.pieceStyle)
                            .frame(width: sq, height: sq).position(x: x, y: y).allowsHitTesting(false)
                    }
                    if targets.contains(s) {
                        Circle().fill(Color.green.opacity(0.55)).frame(width: sq * 0.28, height: sq * 0.28).position(x: x, y: y)
                    }
                }
                if game.showNotation { notation(sq: sq, margin: margin) }
                arrows(sq: sq, margin: margin)
                if let f = dragFrom, let p = game.pos.b[f] {
                    MinionView(kind: p.kind, side: p.side, style: game.pieceStyle)
                        .frame(width: sq * 1.2, height: sq * 1.2).position(dragPoint).allowsHitTesting(false)
                }
                if let pp = game.pendingPromotion { promotionPicker(pp, sq: sq).position(x: side / 2, y: side / 2) }
            }
            .frame(width: side, height: side)
            .contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance: 0)
                .onChanged { v in
                    if dragFrom == nil, let s = square(at: v.startLocation, sq: sq, margin: margin),
                       game.humanToMove, game.pendingPromotion == nil, game.pos.b[s]?.side == game.pos.turn,
                       game.selectedDrop == nil, hypot(v.translation.width, v.translation.height) > 4 {
                        dragFrom = s; game.selected = s
                    }
                    dragPoint = v.location
                }
                .onEnded { v in
                    let moved = hypot(v.translation.width, v.translation.height) > 4
                    if let f = dragFrom {
                        dragFrom = nil
                        if let t = square(at: v.location, sq: sq, margin: margin), t != f { game.attempt(from: f, to: t) }
                    } else if !moved, let s = square(at: v.startLocation, sq: sq, margin: margin) { game.tapSquare(s) }
                })
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .aspectRatio(1, contentMode: .fit)
    }

    private var targets: Set<Int> {
        if let d = game.selectedDrop { return Set(game.dropSquares(d)) }
        if let s = game.selected { return Set(game.destinations(from: s)) }
        return []
    }

    private func highlighted(_ s: Int) -> Bool { game.selected == s }

    private func pos(of s: Int, sq: CGFloat, margin: CGFloat) -> (CGFloat, CGFloat) {
        let f = s % 8, r = s / 8
        let col = game.flipped ? 7 - f : f, row = game.flipped ? r : 7 - r
        return (margin + sq * (CGFloat(col) + 0.5), margin + sq * (CGFloat(row) + 0.5))
    }

    private func square(at p: CGPoint, sq: CGFloat, margin: CGFloat) -> Int? {
        let col = Int(floor((p.x - margin) / sq)), row = Int(floor((p.y - margin) / sq))
        guard (0..<8).contains(col), (0..<8).contains(row) else { return nil }
        let f = game.flipped ? 7 - col : col, r = game.flipped ? row : 7 - row
        return r * 8 + f
    }

    private func notation(sq: CGFloat, margin: CGFloat) -> some View {
        ZStack {
            ForEach(0..<8, id: \.self) { i in
                let f = game.flipped ? 7 - i : i
                Text(String(UnicodeScalar(UInt8(97 + f)))).font(.system(size: margin * 0.55, weight: .medium)).foregroundColor(.white.opacity(0.85))
                    .position(x: margin + sq * (CGFloat(i) + 0.5), y: margin + sq * 8 + margin / 2)
                Text("\(game.flipped ? i + 1 : 8 - i)").font(.system(size: margin * 0.55, weight: .medium)).foregroundColor(.white.opacity(0.85))
                    .position(x: margin / 2, y: margin + sq * (CGFloat(i) + 0.5))
            }
        }
    }

    @ViewBuilder private func arrows(sq: CGFloat, margin: CGFloat) -> some View {
        if let h = game.hint { arrow(h, color: .blue, sq: sq, margin: margin) }
        if game.showLast, let l = game.lastMove { arrow(l, color: .orange, sq: sq, margin: margin) }
    }

    private func arrow(_ m: Move, color: Color, sq: CGFloat, margin: CGFloat) -> some View {
        let a = m.isDrop ? pos(of: m.to, sq: sq, margin: margin) : pos(of: m.from, sq: sq, margin: margin)
        let b = pos(of: m.to, sq: sq, margin: margin)
        return Path { p in
            guard a != b else { return }
            let dx = b.0 - a.0, dy = b.1 - a.1, len = hypot(dx, dy), ux = dx / len, uy = dy / len
            let head = sq * 0.3, tipX = b.0 - ux * sq * 0.1, tipY = b.1 - uy * sq * 0.1
            p.move(to: CGPoint(x: a.0, y: a.1)); p.addLine(to: CGPoint(x: tipX - ux * head, y: tipY - uy * head))
            p.move(to: CGPoint(x: tipX, y: tipY))
            p.addLine(to: CGPoint(x: tipX - ux * head - uy * head * 0.55, y: tipY - uy * head + ux * head * 0.55))
            p.addLine(to: CGPoint(x: tipX - ux * head + uy * head * 0.55, y: tipY - uy * head - ux * head * 0.55))
            p.closeSubpath()
        }
        .stroke(color.opacity(0.85), style: StrokeStyle(lineWidth: sq * 0.12, lineCap: .round))
        .overlay(Path { p in
            guard a != b else { return }
            let dx = b.0 - a.0, dy = b.1 - a.1, len = hypot(dx, dy), ux = dx / len, uy = dy / len
            let head = sq * 0.3, tipX = b.0 - ux * sq * 0.1, tipY = b.1 - uy * sq * 0.1
            p.move(to: CGPoint(x: tipX, y: tipY))
            p.addLine(to: CGPoint(x: tipX - ux * head - uy * head * 0.55, y: tipY - uy * head + ux * head * 0.55))
            p.addLine(to: CGPoint(x: tipX - ux * head + uy * head * 0.55, y: tipY - uy * head - ux * head * 0.55))
            p.closeSubpath()
        }.fill(color.opacity(0.85)))
        .allowsHitTesting(false)
    }

    private func promotionPicker(_ pp: (from: Int, to: Int), sq: CGFloat) -> some View {
        let kinds = game.legal.filter { $0.from == pp.from && $0.to == pp.to }.compactMap(\.promo)
        return VStack(spacing: 6) {
            Text("Promote to").font(.headline).foregroundColor(.white)
            HStack(spacing: 4) {
                ForEach(kinds, id: \.self) { k in
                    Button { game.promote(to: k) } label: {
                        MinionView(kind: k, side: game.pos.turn, style: game.pieceStyle).frame(width: sq, height: sq)
                    }.buttonStyle(.plain)
                }
            }
        }
        .padding(12).background(RoundedRectangle(cornerRadius: 12).fill(Color.black.opacity(0.8)))
    }
}

struct PocketView: View {
    @ObservedObject var game: Game
    let side: Side
    var body: some View {
        HStack(spacing: 6) {
            Text("\(side.name) pocket").font(.caption).foregroundColor(.secondary)
            ForEach([Kind.queen, .rook, .bishop, .knight, .pawn], id: \.self) { k in
                let n = game.pos.pockets[side.rawValue][k.rawValue]
                Button { if game.humanToMove && game.pos.turn == side { game.selected = nil; game.selectedDrop = (game.selectedDrop == k ? nil : k) } } label: {
                    ZStack(alignment: .bottomTrailing) {
                        MinionView(kind: k, side: side, style: game.pieceStyle).frame(width: 38, height: 38).opacity(n > 0 ? 1 : 0.25)
                        if n > 0 { Text("\(n)").font(.caption2.bold()).padding(2).background(Circle().fill(.red)).foregroundColor(.white) }
                    }
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(game.selectedDrop == k && game.pos.turn == side ? Color.green : .clear, lineWidth: 2))
                }.buttonStyle(.plain).disabled(n == 0)
            }
        }
        .frame(height: 42)
    }
}

struct NewGameSheet: View {
    @ObservedObject var game: Game
    @Environment(\.dismiss) var dismiss
    @State private var variant: Variant = .normal
    @State private var mode: PlayerMode = .humanVsComputer
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Start a new game?").font(.title2.bold())
            Picker("Players", selection: $mode) { ForEach(PlayerMode.allCases) { Text($0.title).tag($0) } }
            Picker("Style of play", selection: $variant) { ForEach(Variant.allCases) { Text($0.rawValue).tag($0) } }
            Text(variant.blurb).font(.callout).foregroundColor(.secondary).frame(height: 40, alignment: .topLeading)
            StrengthSlider(game: game)
            HStack { Spacer()
                Button("Cancel") { dismiss() }.keyboardShortcut(.cancelAction)
                Button("Start") { game.newGame(variant: variant, mode: mode); dismiss() }.keyboardShortcut(.defaultAction)
            }
        }
        .padding(20).frame(width: 420)
    }
}

struct StrengthSlider: View {
    @ObservedObject var game: Game
    var body: some View {
        VStack(alignment: .leading) {
            HStack { Text("Faster"); Slider(value: Binding(get: { Double(game.level) }, set: { game.level = Int($0) }), in: 1...10, step: 1); Text("Stronger") }
            let lv = Engine.levels[game.level - 1]
            Text("Computer thinks up to \(lv.time < 1 ? String(format: "%.1f", lv.time) : String(Int(lv.time))) s / \(lv.depth) moves ahead")
                .font(.caption).foregroundColor(.secondary)
        }
    }
}

struct SettingsView: View {
    @ObservedObject var game: Game
    var body: some View {
        Form {
            Picker("Board", selection: game.binding(\.boardStyle)) { ForEach(boardStyles, id: \.self) { Text($0) } }
            Picker("Dark minions", selection: game.binding(\.pieceStyle)) { ForEach(pieceStyles, id: \.self) { Text($0) } }
            Toggle("Show edge notation", isOn: game.binding(\.showNotation))
            Toggle("Speak computer moves", isOn: game.binding(\.speakComputer))
            Toggle("Speak human moves", isOn: game.binding(\.speakHuman))
            StrengthSlider(game: game)
        }.padding(20).frame(width: 420)
    }
}

extension Game {
    func binding<T>(_ kp: ReferenceWritableKeyPath<Game, T>) -> Binding<T> {
        Binding(get: { self[keyPath: kp] }, set: { self.objectWillChange.send(); self[keyPath: kp] = $0 })
    }
}

struct ContentView: View {
    @ObservedObject var game: Game
    @State private var showNew = false
    var body: some View {
        HStack(spacing: 0) {
            VStack(spacing: 4) {
                if game.variant == .crazyhouse { PocketView(game: game, side: game.flipped ? .white : .black) }
                BoardView(game: game).padding(10)
                if game.variant == .crazyhouse { PocketView(game: game, side: game.flipped ? .black : .white) }
            }
            .frame(minWidth: 480, minHeight: 520)
            VStack(alignment: .leading, spacing: 10) {
                Text(game.statusText).font(.headline).fixedSize(horizontal: false, vertical: true)
                Text("\(game.variant.rawValue) • \(game.mode.title)").font(.caption).foregroundColor(.secondary)
                if let n = game.notice { Text(n).font(.callout).foregroundColor(.orange) }
                HStack {
                    Button("New") { showNew = true }
                    Button("Hint") { game.requestHint() }.disabled(!game.humanToMove)
                    Button("Undo") { game.undo() }.disabled(game.moves.isEmpty)
                }
                HStack {
                    Button("Last Move") { game.showLastMove() }.disabled(game.moves.isEmpty)
                    Button("Draw?") { game.offerDraw() }.disabled(game.outcome != nil)
                    Button("Resign") { game.resign() }.disabled(game.outcome != nil)
                }
                Divider()
                Text("Game Log").font(.subheadline.bold())
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 2) {
                            ForEach(0..<((game.sans.count + 1) / 2), id: \.self) { i in
                                HStack {
                                    Text("\(i + 1).").foregroundColor(.secondary).frame(width: 30, alignment: .trailing)
                                    Text(game.sans[2 * i]).frame(width: 70, alignment: .leading)
                                    Text(2 * i + 1 < game.sans.count ? game.sans[2 * i + 1] : "").frame(width: 70, alignment: .leading)
                                }.font(.system(.body, design: .monospaced)).id(i)
                            }
                        }
                    }
                    .onChange(of: game.sans.count) { _ in proxy.scrollTo((game.sans.count - 1) / 2, anchor: .bottom) }
                }
            }
            .padding(14).frame(width: 260)
        }
        .sheet(isPresented: $showNew) { NewGameSheet(game: game) }
        .onReceive(NotificationCenter.default.publisher(for: .newGame)) { _ in showNew = true }
    }
}

extension Notification.Name { static let newGame = Notification.Name("MinionChess.newGame") }
