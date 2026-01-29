// Agentboard/Views/SwiftTermView.swift
import SwiftUI
import SwiftTerm

struct SwiftTermViewRepresentable: UIViewRepresentable {
    let sessionId: String
    var onSizeChange: ((Int, Int) -> Void)?

    @Environment(TerminalManager.self) private var terminalManager

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> TerminalView {
        let terminal = TerminalView(frame: .zero)

        // Configure appearance
        terminal.backgroundColor = UIColor(Color.bgPrimary)
        terminal.nativeBackgroundColor = UIColor(Color.bgPrimary)
        terminal.nativeForegroundColor = UIColor(Color.textPrimary)

        // Configure font
        if let font = UIFont(name: "JetBrainsMono-Regular", size: 14) {
            terminal.font = font
        }

        // Configure cursor
        terminal.cursorStyleChanged(source: terminal.getTerminal(), newStyle: .blinkBlock)

        // User interaction settings
        terminal.isUserInteractionEnabled = true
        terminal.allowMouseReporting = false

        // Register with manager
        terminalManager.register(terminal, for: sessionId)

        return terminal
    }

    func updateUIView(_ uiView: TerminalView, context: Context) {
        let cols = uiView.getTerminal().cols
        let rows = uiView.getTerminal().rows

        guard cols > 0 && rows > 0 else { return }

        if cols != context.coordinator.lastCols || rows != context.coordinator.lastRows {
            context.coordinator.lastCols = cols
            context.coordinator.lastRows = rows
            // Debounce: SwiftUI calls updateUIView multiple times during layout
            // transitions, reporting intermediate sizes before settling. Wait for
            // the size to stabilize before notifying.
            context.coordinator.debounceTimer?.invalidate()
            let callback = onSizeChange
            context.coordinator.debounceTimer = Timer.scheduledTimer(withTimeInterval: 0.15, repeats: false) { [weak coordinator = context.coordinator] _ in
                guard let coordinator else { return }
                callback?(coordinator.lastCols, coordinator.lastRows)
            }
        }
    }

    static func dismantleUIView(_ uiView: TerminalView, coordinator: Coordinator) {
        coordinator.debounceTimer?.invalidate()
    }

    class Coordinator {
        var lastCols: Int = 0
        var lastRows: Int = 0
        var debounceTimer: Timer?
    }
}

@Observable
class TerminalManager {
    @ObservationIgnored private var terminals: [String: TerminalView] = [:]
    @ObservationIgnored private var activeSessionId: String?
    @ObservationIgnored private(set) var lastCols: Int = 0
    @ObservationIgnored private(set) var lastRows: Int = 0

    /// Best available terminal dimensions: last reported by SwiftTerm, or an estimate from screen metrics.
    var bestDimensions: (cols: Int, rows: Int) {
        if lastCols > 0 && lastRows > 0 {
            return (lastCols, lastRows)
        }
        return Self.estimateDimensions()
    }

    /// Estimate terminal dimensions from screen size and font metrics.
    /// JetBrainsMono-Regular at 14pt: ~8.4pt character width, ~17pt line height.
    static func estimateDimensions() -> (cols: Int, rows: Int) {
        let screen = UIScreen.main.bounds
        let width = min(screen.width, screen.height) // portrait width
        let charWidth: CGFloat = 8.4
        let lineHeight: CGFloat = 17.0
        let horizontalInset: CGFloat = 8.0  // SwiftTerm internal padding
        let verticalInset: CGFloat = 120.0  // safe area + accessory bar
        let cols = max(20, Int((width - horizontalInset * 2) / charWidth))
        let rows = max(10, Int((max(screen.width, screen.height) - verticalInset) / lineHeight))
        return (cols, rows)
    }

    func updateSize(cols: Int, rows: Int) {
        lastCols = cols
        lastRows = rows
    }

    func setActiveSession(_ sessionId: String?) {
        // Clear old terminal when switching
        if let oldId = activeSessionId, oldId != sessionId {
            terminals.removeValue(forKey: oldId)
        }
        activeSessionId = sessionId
    }

    func register(_ terminal: TerminalView, for sessionId: String) {
        terminals[sessionId] = terminal
    }

    func unregister(sessionId: String) {
        terminals.removeValue(forKey: sessionId)
    }

    func feed(sessionId: String, data: String) {
        guard sessionId == activeSessionId,
              let terminal = terminals[sessionId] else { return }
        let bytes = Array(data.utf8)
        terminal.feed(byteArray: ArraySlice(bytes))
    }

    func feed(sessionId: String, bytes: [UInt8]) {
        guard sessionId == activeSessionId,
              let terminal = terminals[sessionId] else { return }
        terminal.feed(byteArray: ArraySlice(bytes))
    }

    func getSize(sessionId: String) -> (cols: Int, rows: Int)? {
        guard let terminal = terminals[sessionId] else { return nil }
        return (terminal.getTerminal().cols, terminal.getTerminal().rows)
    }
}
