import SwiftUI
import AppKit
import AVFoundation

enum PlayerMode: Int, CaseIterable, Identifiable {
    case humanVsComputer, computerVsHuman, computerVsComputer, humanVsHuman
    var id: Int { rawValue }
    var title: String { ["Person vs. Computer", "Computer vs. Person", "Computer vs. Computer", "Person vs. Person"][rawValue] }
    var whiteHuman: Bool { self == .humanVsComputer || self == .humanVsHuman }
    var blackHuman: Bool { self == .computerVsHuman || self == .humanVsHuman }
}

@MainActor
final class Game: ObservableObject {
    @Published var pos = Position.start(.normal)
    @Published var history: [Position] = [Position.start(.normal)]
    @Published var moves: [Move] = []
    @Published var sans: [String] = []
    @Published var outcome: Outcome?
    @Published var mode: PlayerMode = .humanVsComputer
    @Published var selected: Int?
    @Published var selectedDrop: Kind?
    @Published var hint: Move?
    @Published var showLast = false
    @Published var thinking = false
    @Published var notice: String?
    @Published var pendingPromotion: (from: Int, to: Int)?
    @Published var legal: [Move] = []

    @AppStorage("level") var level = 5
    @AppStorage("speakComputer") var speakComputer = true
    @AppStorage("speakHuman") var speakHuman = false
    @AppStorage("boardStyle") var boardStyle = "Wood"
    @AppStorage("pieceStyle") var pieceStyle = "Classic"
    @AppStorage("showNotation") var showNotation = true

    private let engine = Engine()
    private var generation = 0
    private let speech = AVSpeechSynthesizer()
    private var tags: [String: String] = [:]

    var variant: Variant { pos.variant }
    var flipped: Bool { mode == .computerVsHuman }
    var humanToMove: Bool { outcome == nil && (pos.turn == .white ? mode.whiteHuman : mode.blackHuman) }
    var lastMove: Move? { moves.last }
    var canUndo: Bool { !moves.isEmpty && !thinkingBlocksUndo }
    private var thinkingBlocksUndo: Bool { false }

    init() { refresh() }

    private func refresh() {
        legal = pos.legalMoves()
        outcome = pos.outcome(legal: legal)
        if outcome == nil, repetitionCount() >= 3 { outcome = .draw("threefold repetition") }
    }

    private func repetitionCount() -> Int { history.filter { $0.key == pos.key }.count }
    private var seenKeys: [String: Int] {
        var d: [String: Int] = [:]; for p in history { d[p.key, default: 0] += 1 }; return d
    }

    var statusText: String {
        if let o = outcome { return o.text }
        if thinking { return "Computer is thinking…" }
        let side = pos.turn.name + " to move"
        return pos.inCheck(pos.turn) ? side + " – check!" : side
    }

    // MARK: game lifecycle
    func newGame(variant: Variant, mode: PlayerMode) {
        generation += 1
        self.mode = mode
        pos = Position.start(variant); history = [pos]; moves = []; sans = []
        selected = nil; selectedDrop = nil; hint = nil; showLast = false; thinking = false; notice = nil; tags = [:]
        refresh(); engineMoveIfNeeded()
    }

    func undo() {
        guard !moves.isEmpty else { return }
        generation += 1; thinking = false
        repeat {
            moves.removeLast(); sans.removeLast(); history.removeLast()
        } while !moves.isEmpty && !(history.last!.turn == .white ? mode.whiteHuman : mode.blackHuman)
        pos = history.last!; selected = nil; selectedDrop = nil; hint = nil; refresh()
        engineMoveIfNeeded()
    }

    func resign() {
        guard outcome == nil else { return }
        generation += 1; thinking = false
        let loser: Side = mode.whiteHuman && !mode.blackHuman ? .white : mode.blackHuman && !mode.whiteHuman ? .black : pos.turn
        outcome = .win(loser.opp, "resignation")
    }

    func offerDraw() {
        guard outcome == nil else { return }
        let me = pos
        let level = self.level
        let seen = seenKeys
        if mode == .humanVsHuman { outcome = .draw("agreement"); return }
        notice = "Draw offered…"
        Task.detached { [engine] in
            let r = engine.search(me, level: min(level, 4), seen: seen, cancelled: { false })
            let score = r?.score ?? 0
            await MainActor.run {
                // engine's score is for the side to move; accept if it does not think it is better
                let engineIsToMove = !self.humanToMove
                let engineScore = engineIsToMove ? score : -score
                if engineScore <= 30 { self.outcome = .draw("agreement"); self.notice = nil }
                else { self.notice = "Your opponent declined the draw." }
            }
        }
    }

    // MARK: input
    func tapSquare(_ s: Int) {
        guard humanToMove, pendingPromotion == nil else { return }
        hint = nil
        if let d = selectedDrop {
            let m = Move(from: -1, to: s, drop: d)
            if legal.contains(m) { play(m, human: true) } else { illegal() }
            selectedDrop = nil; return
        }
        if let f = selected {
            if f == s { selected = nil; return }
            if legal.contains(where: { $0.from == f && $0.to == s }) { attempt(from: f, to: s); return }
            if pos.b[s]?.side == pos.turn { selected = s; return }
            selected = nil; illegal(); return
        }
        if pos.b[s]?.side == pos.turn, legal.contains(where: { $0.from == s }) { selected = s }
    }

    func attempt(from f: Int, to t: Int) {
        selected = nil
        let cands = legal.filter { $0.from == f && $0.to == t }
        if cands.isEmpty { illegal(); return }
        if cands.count > 1, cands[0].promo != nil { pendingPromotion = (f, t); return }
        play(cands[0], human: true)
    }

    func promote(to k: Kind) {
        guard let p = pendingPromotion else { return }
        pendingPromotion = nil
        play(Move(from: p.from, to: p.to, promo: k), human: true)
    }

    func destinations(from s: Int) -> [Int] { legal.filter { $0.from == s }.map(\.to) }
    func dropSquares(_ k: Kind) -> [Int] { legal.filter { $0.drop == k }.map(\.to) }

    private func illegal() { notice = "Illegal Move!"
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in if self?.notice == "Illegal Move!" { self?.notice = nil } } }

    func play(_ m: Move, human: Bool) {
        guard legal.contains(m) else { return }
        let text = san(for: m)
        let spoken = spokenText(m)
        pos = pos.applying(m)
        history.append(pos); moves.append(m); sans.append(text)
        selected = nil; selectedDrop = nil; hint = nil; notice = nil
        refresh()
        if (human && speakHuman) || (!human && speakComputer) { say(spoken) }
        engineMoveIfNeeded()
    }

    private func san(for m: Move) -> String { history[history.count - 1].san(m, legal: legal) }

    private func spokenText(_ m: Move) -> String {
        if let d = m.drop { return "Drop \(d.name) at \(sqName(m.to))" }
        let p = pos.b[m.from]!
        if p.kind == .king && variant != .suicide && abs(m.to - m.from) == 2 { return m.to > m.from ? "Castle kingside" : "Castle queenside" }
        return "\(p.kind.name.capitalized) \(sqName(m.from)) \(pos.isCapture(m) ? "takes" : "to") \(sqName(m.to))"
    }

    private func say(_ t: String) {
        let u = AVSpeechUtterance(string: t); u.rate = 0.5
        speech.speak(u)
    }

    // MARK: engine
    func engineMoveIfNeeded() {
        guard outcome == nil, !humanToMove else { return }
        generation += 1
        let gen = generation, p = pos, lvl = level, seen = seenKeys
        thinking = true
        Task.detached { [engine] in
            let r = engine.search(p, level: lvl, seen: seen, cancelled: { false })
            await MainActor.run {
                guard gen == self.generation else { return }
                self.thinking = false
                if let r = r {
                    // brief pause so computer-vs-computer is watchable
                    DispatchQueue.main.asyncAfter(deadline: .now() + (self.mode == .computerVsComputer ? 0.4 : 0.05)) {
                        guard gen == self.generation else { return }
                        self.play(r.move, human: false)
                    }
                }
            }
        }
    }

    func requestHint() {
        guard humanToMove else { return }
        let p = pos, seen = seenKeys, gen = generation
        notice = "Thinking of a hint…"
        Task.detached { [engine] in
            let r = engine.search(p, level: 6, seen: seen, cancelled: { false })
            await MainActor.run {
                guard gen == self.generation else { return }
                self.hint = r?.move; self.notice = nil
            }
        }
    }

    func showLastMove() {
        guard lastMove != nil else { return }
        showLast = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) { [weak self] in self?.showLast = false }
    }

    // MARK: PGN
    func pgn() -> String {
        var t: [(String, String)] = [("Event", "Casual Game"), ("Site", "MinionChess"),
            ("Date", { let f = DateFormatter(); f.dateFormat = "yyyy.MM.dd"; return f.string(from: Date()) }()),
            ("Round", "-"),
            ("White", mode.whiteHuman ? "Person" : "Computer"), ("Black", mode.blackHuman ? "Person" : "Computer"),
            ("Result", outcome?.pgnResult ?? "*")]
        switch variant { case .crazyhouse: t.append(("Variant", "Crazyhouse")); case .losers: t.append(("Variant", "Losers"))
        case .suicide: t.append(("Variant", "Suicide")); default: break }
        var s = t.map { "[\($0.0) \"\($0.1)\"]" }.joined(separator: "\n") + "\n\n"
        for (i, m) in sans.enumerated() { if i % 2 == 0 { s += "\(i / 2 + 1). " }; s += m + " " }
        return s + (outcome?.pgnResult ?? "*") + "\n"
    }

    func savePGN() {
        let panel = NSSavePanel(); panel.nameFieldStringValue = "Chess Game.pgn"
        panel.allowedContentTypes = [.init(filenameExtension: "pgn") ?? .plainText]
        if panel.runModal() == .OK, let u = panel.url { try? pgn().write(to: u, atomically: true, encoding: .utf8) }
    }

    func openPGN() {
        let panel = NSOpenPanel(); panel.allowedContentTypes = [.init(filenameExtension: "pgn") ?? .plainText, .plainText]
        guard panel.runModal() == .OK, let u = panel.url, let text = try? String(contentsOf: u, encoding: .utf8) else { return }
        if !loadPGN(text) { notice = "Could not read that PGN file." }
    }

    @discardableResult
    func loadPGN(_ text: String) -> Bool {
        var variant = Variant.normal
        for line in text.split(separator: "\n") where line.hasPrefix("[Variant") {
            let l = line.lowercased()
            if l.contains("crazyhouse") { variant = .crazyhouse } else if l.contains("suicide") { variant = .suicide }
            else if l.contains("losers") || l.contains("losing") { variant = .losers }
        }
        var body = text.split(separator: "\n").filter { !$0.hasPrefix("[") }.joined(separator: " ")
        body = body.replacingOccurrences(of: "\\{[^}]*\\}", with: " ", options: .regularExpression)
        body = body.replacingOccurrences(of: "\\([^)]*\\)", with: " ", options: .regularExpression)
        let tokens = body.split(whereSeparator: { $0.isWhitespace }).map(String.init).compactMap { tok -> String? in
            var t = tok
            if let r = t.range(of: "^\\d+\\.+", options: .regularExpression) { t.removeSubrange(r) }
            t = t.trimmingCharacters(in: CharacterSet(charactersIn: "!?"))
            if t.isEmpty || ["1-0", "0-1", "1/2-1/2", "*"].contains(t) || t.hasPrefix("$") { return nil }
            return t
        }
        var p = Position.start(variant)
        var hist = [p], mv: [Move] = [], sn: [String] = []
        for tok in tokens {
            let key = tok.trimmingCharacters(in: CharacterSet(charactersIn: "+#")).replacingOccurrences(of: "0", with: "O")
            let lg = p.legalMoves()
            guard let m = lg.first(where: { p.san($0, legal: lg).trimmingCharacters(in: CharacterSet(charactersIn: "+#")) == key }) else { return false }
            sn.append(p.san(m, legal: lg)); p = p.applying(m); mv.append(m); hist.append(p)
        }
        generation += 1
        mode = .humanVsHuman; pos = p; history = hist; moves = mv; sans = sn
        selected = nil; hint = nil; thinking = false; refresh()
        return true
    }
}
