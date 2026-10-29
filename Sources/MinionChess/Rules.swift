import Foundation

enum Side: Int, Hashable { case white = 0, black = 1
    var opp: Side { self == .white ? .black : .white }
    var name: String { self == .white ? "White" : "Black" }
}

enum Kind: Int, CaseIterable, Hashable {
    case pawn, knight, bishop, rook, queen, king
    var letter: String { ["", "N", "B", "R", "Q", "K"][rawValue] }
    var name: String { ["pawn", "knight", "bishop", "rook", "queen", "king"][rawValue] }
    var value: Int { [100, 320, 330, 500, 900, 0][rawValue] }
}

struct Piece: Hashable { var kind: Kind; var side: Side }

enum Variant: String, CaseIterable, Identifiable {
    case normal = "Normal", crazyhouse = "Crazyhouse", losers = "Losers", suicide = "Suicide"
    var id: String { rawValue }
    var blurb: String {
        switch self {
        case .normal: return "Regular chess."
        case .crazyhouse: return "Captured pieces change sides and can be dropped back on the board."
        case .losers: return "Captures are compulsory. Lose all pieces except the king (or get mated/stalemated) to win."
        case .suicide: return "Captures are compulsory, the king is an ordinary piece. Lose everything to win."
        }
    }
    var royalKing: Bool { self != .suicide }
    var forcedCapture: Bool { self == .losers || self == .suicide }
}

struct Move: Hashable {
    var from: Int          // -1 for a drop
    var to: Int
    var promo: Kind? = nil
    var drop: Kind? = nil
    var isDrop: Bool { from < 0 }
}

enum Outcome: Equatable {
    case win(Side, String)
    case draw(String)
    var text: String {
        switch self {
        case .win(let s, let why): return "\(s.name) wins by \(why)!"
        case .draw(let why): return "Draw – \(why)"
        }
    }
    var pgnResult: String {
        switch self { case .win(.white, _): return "1-0"; case .win(.black, _): return "0-1"; case .draw: return "1/2-1/2" }
    }
}

func sqName(_ s: Int) -> String { String(UnicodeScalar(UInt8(97 + s % 8))) + String(s / 8 + 1) }
func sqIndex(_ name: String) -> Int? {
    let u = Array(name.utf8); guard u.count == 2, u[0] >= 97, u[0] <= 104, u[1] >= 49, u[1] <= 56 else { return nil }
    return Int(u[1] - 49) * 8 + Int(u[0] - 97)
}

struct Position {
    var b: [Piece?] = Array(repeating: nil, count: 64)
    var turn: Side = .white
    var castle: [Bool] = [true, true, true, true]   // wK wQ bK bQ
    var ep: Int? = nil
    var half = 0
    var full = 1
    var variant: Variant = .normal
    var pockets: [[Int]] = [[Int]](repeating: [Int](repeating: 0, count: 6), count: 2)
    var promoted: Set<Int> = []

    static func start(_ v: Variant) -> Position {
        var p = Position(); p.variant = v
        let back: [Kind] = [.rook, .knight, .bishop, .queen, .king, .bishop, .knight, .rook]
        for f in 0..<8 {
            p.b[f] = Piece(kind: back[f], side: .white); p.b[8 + f] = Piece(kind: .pawn, side: .white)
            p.b[48 + f] = Piece(kind: .pawn, side: .black); p.b[56 + f] = Piece(kind: back[f], side: .black)
        }
        if v == .suicide { p.castle = [false, false, false, false] }
        return p
    }

    var key: String {
        var s = ""
        for p in b { if let p = p { s += "\(p.side.rawValue)\(p.kind.rawValue)" } else { s += "." } }
        return s + "\(turn.rawValue)\(castle.map { $0 ? 1 : 0 })\(ep ?? -1)" + (variant == .crazyhouse ? "\(pockets)" : "")
    }

    // MARK: attacks
    static let knightD = [(1, 2), (2, 1), (2, -1), (1, -2), (-1, -2), (-2, -1), (-2, 1), (-1, 2)]
    static let kingD = [(1, 0), (1, 1), (0, 1), (-1, 1), (-1, 0), (-1, -1), (0, -1), (1, -1)]
    static let diagD = [(1, 1), (-1, 1), (-1, -1), (1, -1)]
    static let orthD = [(1, 0), (0, 1), (-1, 0), (0, -1)]

    @inline(__always) static func step(_ s: Int, _ df: Int, _ dr: Int) -> Int? {
        let f = s % 8 + df, r = s / 8 + dr
        return (f >= 0 && f < 8 && r >= 0 && r < 8) ? r * 8 + f : nil
    }

    func isAttacked(_ sq: Int, by side: Side) -> Bool {
        let pd = side == .white ? -1 : 1
        for df in [-1, 1] { if let s = Position.step(sq, df, pd), let p = b[s], p.side == side, p.kind == .pawn { return true } }
        for (df, dr) in Position.knightD { if let s = Position.step(sq, df, dr), let p = b[s], p.side == side, p.kind == .knight { return true } }
        for (df, dr) in Position.kingD { if let s = Position.step(sq, df, dr), let p = b[s], p.side == side, p.kind == .king { return true } }
        for (df, dr) in Position.diagD {
            var c = sq
            while let s = Position.step(c, df, dr) { c = s
                if let p = b[s] { if p.side == side && (p.kind == .bishop || p.kind == .queen) { return true }; break } }
        }
        for (df, dr) in Position.orthD {
            var c = sq
            while let s = Position.step(c, df, dr) { c = s
                if let p = b[s] { if p.side == side && (p.kind == .rook || p.kind == .queen) { return true }; break } }
        }
        return false
    }

    func kingSquare(_ side: Side) -> Int? { b.firstIndex { $0 == Piece(kind: .king, side: side) } }
    func inCheck(_ side: Side) -> Bool {
        guard variant.royalKing, let k = kingSquare(side) else { return false }
        return isAttacked(k, by: side.opp)
    }

    func isCapture(_ m: Move) -> Bool {
        if m.isDrop { return false }
        if b[m.to] != nil { return true }
        return b[m.from]?.kind == .pawn && m.to == ep
    }

    // MARK: generation
    func pseudoMoves() -> [Move] {
        var out: [Move] = []; out.reserveCapacity(48)
        let me = turn
        for s in 0..<64 {
            guard let p = b[s], p.side == me else { continue }
            let f = s % 8, r = s / 8
            switch p.kind {
            case .pawn:
                let d = me == .white ? 1 : -1
                let last = me == .white ? 7 : 0, startR = me == .white ? 1 : 6
                func add(_ to: Int) {
                    if to / 8 == last {
                        var ks: [Kind] = [.queen, .rook, .bishop, .knight]
                        if variant == .suicide { ks.append(.king) }
                        for k in ks { out.append(Move(from: s, to: to, promo: k)) }
                    } else { out.append(Move(from: s, to: to)) }
                }
                if let o = Position.step(s, 0, d), b[o] == nil {
                    add(o)
                    if r == startR, let o2 = Position.step(s, 0, 2 * d), b[o2] == nil { out.append(Move(from: s, to: o2)) }
                }
                for df in [-1, 1] { if let t = Position.step(s, df, d) {
                    if let q = b[t], q.side != me { add(t) } else if t == ep, b[t] == nil { out.append(Move(from: s, to: t)) } } }
            case .knight, .king:
                for (df, dr) in (p.kind == .knight ? Position.knightD : Position.kingD) {
                    if let t = Position.step(s, df, dr), b[t]?.side != me { out.append(Move(from: s, to: t)) } }
                if p.kind == .king && variant != .suicide {
                    let base = me == .white ? 0 : 56, ci = me == .white ? 0 : 2
                    if s == base + 4 && !isAttacked(s, by: me.opp) {
                        if castle[ci], b[base + 7] == Piece(kind: .rook, side: me), b[base + 5] == nil, b[base + 6] == nil,
                           !isAttacked(base + 5, by: me.opp) { out.append(Move(from: s, to: base + 6)) }
                        if castle[ci + 1], b[base] == Piece(kind: .rook, side: me), b[base + 1] == nil, b[base + 2] == nil, b[base + 3] == nil,
                           !isAttacked(base + 3, by: me.opp) { out.append(Move(from: s, to: base + 2)) }
                    }
                }
            case .bishop, .rook, .queen:
                var dirs: [(Int, Int)] = []
                if p.kind != .rook { dirs += Position.diagD }
                if p.kind != .bishop { dirs += Position.orthD }
                for (df, dr) in dirs {
                    var c = s
                    while let t = Position.step(c, df, dr) { c = t
                        if let q = b[t] { if q.side != me { out.append(Move(from: s, to: t)) }; break }
                        out.append(Move(from: s, to: t)) }
                }
            }
            _ = f
        }
        if variant == .crazyhouse {
            for k in Kind.allCases where k != .king && pockets[me.rawValue][k.rawValue] > 0 {
                for s in 0..<64 where b[s] == nil {
                    if k == .pawn && (s / 8 == 0 || s / 8 == 7) { continue }
                    out.append(Move(from: -1, to: s, drop: k))
                }
            }
        }
        return out
    }

    func legalMoves() -> [Move] {
        var out: [Move] = []
        for m in pseudoMoves() {
            if variant.royalKing {
                let n = applying(m)
                if let k = n.kingSquare(turn), n.isAttacked(k, by: turn.opp) { continue }
            }
            out.append(m)
        }
        if variant.forcedCapture {
            let caps = out.filter { isCapture($0) }
            if !caps.isEmpty { return caps }
        }
        return out
    }

    // MARK: apply
    func applying(_ m: Move) -> Position {
        var n = self
        let me = turn
        n.ep = nil
        if let k = m.drop {
            n.b[m.to] = Piece(kind: k, side: me)
            n.pockets[me.rawValue][k.rawValue] -= 1
            n.half += 1
        } else {
            let p = b[m.from]!
            var captured = b[m.to]
            if p.kind == .pawn && m.to == ep && captured == nil {
                let cs = m.to + (me == .white ? -8 : 8); captured = b[cs]; n.b[cs] = nil
            }
            n.b[m.from] = nil
            n.b[m.to] = Piece(kind: m.promo ?? p.kind, side: me)
            let wasPromoted = n.promoted.contains(m.from)
            n.promoted.remove(m.from)
            if wasPromoted { n.promoted.insert(m.to) }
            if m.promo != nil && variant == .crazyhouse { n.promoted.insert(m.to) }
            if let c = captured {
                if variant == .crazyhouse {
                    let k: Kind = promoted.contains(m.to) ? .pawn : c.kind
                    n.pockets[me.rawValue][k.rawValue] += 1
                }
                n.promoted.remove(m.to)
            }
            if p.kind == .king && variant != .suicide && abs(m.to - m.from) == 2 {
                let base = me == .white ? 0 : 56
                if m.to == base + 6 { n.b[base + 5] = n.b[base + 7]; n.b[base + 7] = nil }
                else { n.b[base + 3] = n.b[base]; n.b[base] = nil }
            }
            if p.kind == .pawn && abs(m.to - m.from) == 16 { n.ep = (m.to + m.from) / 2 }
            if p.kind == .pawn || captured != nil { n.half = 0 } else { n.half += 1 }
            if p.kind == .king { if me == .white { n.castle[0] = false; n.castle[1] = false } else { n.castle[2] = false; n.castle[3] = false } }
            for s in [m.from, m.to] { switch s { case 0: n.castle[1] = false; case 7: n.castle[0] = false
                case 56: n.castle[3] = false; case 63: n.castle[2] = false; case 4: n.castle[0] = false; n.castle[1] = false
                case 60: n.castle[2] = false; n.castle[3] = false; default: break } }
        }
        if me == .black { n.full += 1 }
        n.turn = me.opp
        return n
    }

    // MARK: outcome
    func outcome(legal: [Move]) -> Outcome? {
        func count(_ s: Side) -> (all: Int, nonKing: Int) {
            var a = 0, nk = 0
            for p in b { if let p = p, p.side == s { a += 1; if p.kind != .king { nk += 1 } } }
            return (a, nk)
        }
        switch variant {
        case .suicide:
            for s in [Side.white, .black] where count(s).all == 0 { return .win(s, "losing every piece") }
            if legal.isEmpty { return .win(turn, "being stalemated") }
        case .losers:
            for s in [Side.white, .black] where count(s).nonKing == 0 { return .win(s, "losing every piece") }
            if legal.isEmpty { return .win(turn, inCheck(turn) ? "being checkmated" : "being stalemated") }
        default:
            if legal.isEmpty { return inCheck(turn) ? .win(turn.opp, "checkmate") : .draw("stalemate") }
            if variant == .normal && insufficientMaterial() { return .draw("insufficient material") }
        }
        if half >= 100 { return .draw("the fifty-move rule") }
        return nil
    }

    func insufficientMaterial() -> Bool {
        var minors: [(Kind, Int, Side)] = []
        for (i, p) in b.enumerated() { guard let p = p else { continue }
            switch p.kind { case .king: continue
            case .knight, .bishop: minors.append((p.kind, i, p.side))
            default: return false } }
        if minors.count <= 1 { return true }
        if minors.count == 2, minors[0].0 == .bishop, minors[1].0 == .bishop, minors[0].2 != minors[1].2 {
            return ((minors[0].1 % 8 + minors[0].1 / 8) & 1) == ((minors[1].1 % 8 + minors[1].1 / 8) & 1)
        }
        return false
    }

    // MARK: SAN
    func san(_ m: Move, legal: [Move]) -> String {
        var s = ""
        if let d = m.drop { s = (d == .pawn ? "P" : d.letter) + "@" + sqName(m.to) }
        else {
            let p = b[m.from]!
            if p.kind == .king && variant != .suicide && abs(m.to - m.from) == 2 { s = m.to > m.from ? "O-O" : "O-O-O" }
            else {
                let cap = isCapture(m)
                if p.kind == .pawn { if cap { s += String(sqName(m.from).first!) } }
                else {
                    s += p.kind.letter
                    let others = legal.filter { $0.from != m.from && $0.to == m.to && b[$0.from]?.kind == p.kind && !$0.isDrop }
                    if !others.isEmpty {
                        let sameFile = others.contains { $0.from % 8 == m.from % 8 }
                        let sameRank = others.contains { $0.from / 8 == m.from / 8 }
                        let n = sqName(m.from)
                        if !sameFile { s += String(n.first!) } else if !sameRank { s += String(n.last!) } else { s += n }
                    }
                }
                if cap { s += "x" }
                s += sqName(m.to)
                if let pr = m.promo { s += "=" + pr.letter }
            }
        }
        if variant.royalKing {
            let n = applying(m)
            if n.inCheck(n.turn) { s += n.legalMoves().isEmpty ? "#" : "+" }
        }
        return s
    }
}
