import Foundation

/// Original alpha-beta engine (iterative deepening, quiescence, MVV-LVA ordering). Not derived from sjeng.
final class Engine {
    private let mate = 100_000
    private var deadline = Date()
    private var maxDepth = 4
    private var stopFlag: () -> Bool = { false }
    private var timedOut = false
    private var nodes = 0

    static let levels: [(time: Double, depth: Int)] =
        [(0.1, 1), (0.2, 2), (0.4, 2), (0.7, 3), (1, 4), (2, 5), (3, 6), (5, 8), (8, 10), (12, 14)]

    func search(_ pos: Position, level: Int, seen: [String: Int], cancelled: @escaping () -> Bool) -> (move: Move, score: Int)? {
        let lv = Engine.levels[max(0, min(9, level - 1))]
        deadline = Date().addingTimeInterval(lv.time)
        maxDepth = lv.depth; stopFlag = cancelled; timedOut = false; nodes = 0
        let root = order(pos, pos.legalMoves())
        guard !root.isEmpty else { return nil }
        var best = root[0], bestScore = -mate
        var ordered = root
        for depth in 1...maxDepth {
            var curBest = ordered[0], curScore = -mate - 1
            var alpha = -mate - 1
            for m in ordered {
                let n = pos.applying(m)
                var s = -negamax(n, depth - 1, -mate - 1, -alpha, 1)
                if timedOut { break }
                if (seen[n.key] ?? 0) >= 2 && s > -100 { s = min(s, 0) }   // avoid walking into a threefold when ahead
                if s > curScore { curScore = s; curBest = m }
                alpha = max(alpha, s)
            }
            if timedOut { if depth == 1 { best = curBest }; break }
            best = curBest; bestScore = curScore
            ordered.removeAll { $0 == best }; ordered.insert(best, at: 0)
            if abs(bestScore) > mate - 100 { break }
        }
        return (best, bestScore)
    }

    private func tick() {
        nodes += 1
        if nodes & 1023 == 0, Date() > deadline || stopFlag() { timedOut = true }
    }

    private func negamax(_ pos: Position, _ depth: Int, _ alphaIn: Int, _ beta: Int, _ ply: Int) -> Int {
        tick(); if timedOut { return 0 }
        let legal = pos.legalMoves()
        if let o = pos.outcome(legal: legal) {
            switch o {
            case .draw: return 0
            case .win(let s, _): return s == pos.turn ? mate - ply : -mate + ply
            }
        }
        if depth <= 0 {
            return pos.variant.forcedCapture ? evaluate(pos) : quiesce(pos, alphaIn, beta, 0)
        }
        var alpha = alphaIn
        var best = -mate - 1
        for m in order(pos, legal) {
            let s = -negamax(pos.applying(m), depth - 1, -beta, -alpha, ply + 1)
            if timedOut { return 0 }
            if s > best { best = s }
            if best > alpha { alpha = best }
            if alpha >= beta { break }
        }
        return best
    }

    private func quiesce(_ pos: Position, _ alphaIn: Int, _ beta: Int, _ qd: Int) -> Int {
        tick(); if timedOut { return 0 }
        let stand = evaluate(pos)
        if qd >= 6 || stand >= beta { return stand }
        var alpha = max(alphaIn, stand)
        let caps = pos.legalMoves().filter { pos.isCapture($0) || $0.promo == .queen }
        for m in order(pos, caps) {
            let s = -quiesce(pos.applying(m), -beta, -alpha, qd + 1)
            if timedOut { return 0 }
            if s >= beta { return s }
            if s > alpha { alpha = s }
        }
        return alpha
    }

    private func order(_ pos: Position, _ moves: [Move]) -> [Move] {
        func score(_ m: Move) -> Int {
            var s = 0
            if let v = pos.b[m.to] { s += 10_000 + v.kind.value * 10 - (pos.b[m.from]?.kind.value ?? 0) / 10 }
            else if pos.isCapture(m) { s += 10_000 + 900 }
            if let p = m.promo { s += 8000 + p.value }
            if m.isDrop { s += 50 }
            return s
        }
        return moves.sorted { score($0) > score($1) }
    }

    // MARK: evaluation (side to move)
    private static let center: [Int] = (0..<64).map { s in
        let f = s % 8, r = s / 8
        let d = min(f, 7 - f) + min(r, 7 - r)
        return d * 6
    }

    func evaluate(_ pos: Position) -> Int {
        var v = 0
        let suicide = pos.variant == .suicide, anti = pos.variant.forcedCapture
        for s in 0..<64 {
            guard let p = pos.b[s] else { continue }
            let sign = p.side == .white ? 1 : -1
            let r = p.side == .white ? s / 8 : 7 - s / 8
            var val = p.kind == .king ? (suicide ? 250 : 0) : p.kind.value
            if anti {
                v += sign * val
            } else {
                switch p.kind {
                case .pawn: val += r * 8 + (Engine.center[s] / 3)
                case .knight, .bishop: val += Engine.center[s]
                case .king:
                    val += pos.b.count(where: { $0 != nil }) > 14 ? (r == 0 ? 15 : -25 * r) : Engine.center[s]
                default: break
                }
                v += sign * val
            }
        }
        if pos.variant == .crazyhouse {
            for side in 0..<2 { let sign = side == 0 ? 1 : -1
                for k in Kind.allCases where k != .king { v += sign * pos.pockets[side][k.rawValue] * (k.value * 9 / 10) } }
        }
        if anti { v = -v }       // losing chess: fewer pieces is better
        return pos.turn == .white ? v : -v
    }
}
