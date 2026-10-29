import SwiftUI

@main
struct MinionChessApp: App {
    @StateObject private var game = Game()
    init() { if let i = CommandLine.arguments.firstIndex(of: "--screens"), i + 1 < CommandLine.arguments.count { MainActor.assumeIsolated { renderScreens(to: CommandLine.arguments[i + 1]) }; exit(0) }; if let i = CommandLine.arguments.firstIndex(of: "--icon"), i + 1 < CommandLine.arguments.count { MainActor.assumeIsolated { renderIcon(to: CommandLine.arguments[i + 1]) }; exit(0) }; if CommandLine.arguments.contains("--selftest") { runSelfTest(); exit(0) }; NSApplication.shared.setActivationPolicy(.regular); NSApplication.shared.activate(ignoringOtherApps: true) }

    var body: some Scene {
        WindowGroup("Minion Chess") {
            ContentView(game: game).onAppear { NSApplication.shared.activate(ignoringOtherApps: true) }
        }
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New…") { NotificationCenter.default.post(name: .newGame, object: nil) }.keyboardShortcut("n")
                Button("Open…") { game.openPGN() }.keyboardShortcut("o")
                Button("Save As…") { game.savePGN() }.keyboardShortcut("s")
            }
            CommandMenu("Moves") {
                Button("Take Back Move") { game.undo() }.keyboardShortcut("z")
                Button("Show Hint") { game.requestHint() }.keyboardShortcut("h")
                Button("Show Last Move") { game.showLastMove() }.keyboardShortcut("l")
                Divider()
                Button("Offer Draw") { game.offerDraw() }
                Button("Resign") { game.resign() }
            }
        }
        Settings { SettingsView(game: game) }
    }
}
