// Agentboard/Views/MainTerminalView.swift
import SwiftUI

struct MainTerminalView: View {
    @Environment(AppState.self) var appState
    @Environment(TerminalManager.self) var terminalManager

    var useControlMode: Bool = false
    var contentModel: SessionContentModel?

    @State private var inputFocused = false

    var body: some View {
        ZStack {
            // Background
            Color.bgPrimary
                .ignoresSafeArea()

            if let sessionId = appState.activeSessionId {
                if useControlMode, let contentModel {
                    // Control mode: native markdown rendering
                    ContentSessionView(sessionId: sessionId, model: contentModel)
                        .id("cm-\(sessionId)")
                } else {
                    // Legacy mode: terminal emulator
                    SwiftTermViewRepresentable(
                        sessionId: sessionId,
                        onSizeChange: { cols, rows in
                            terminalManager.updateSize(cols: cols, rows: rows)
                            WebSocketClient.shared.send(
                                .terminalResize(sessionId: sessionId, cols: cols, rows: rows)
                            )
                        }
                    )
                    .id(sessionId)  // Forces destroy/recreate on session switch
                    .environment(terminalManager)
                    .ignoresSafeArea(.keyboard)
                }

                // Invisible text field for keyboard input capture
                TerminalInputFieldRepresentable(
                    isFocused: $inputFocused,
                    onTextInput: { text in
                        sendInput(text, to: sessionId)
                    },
                    onSpecialKey: { key in
                        handleSpecialKey(key, session: sessionId)
                    }
                )
                .frame(width: 1, height: 1)
                .opacity(0)
            } else {
                // No session
                VStack(spacing: 16) {
                    Text("NO ACTIVE SESSION")
                        .font(Fonts.spaceMonoBold(16))
                        .foregroundColor(.textMuted)

                    Text("Swipe from left edge to open sessions")
                        .font(Fonts.dmMono(12))
                        .foregroundColor(.textMuted.opacity(0.6))
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            if appState.activeSessionId != nil {
                AccessoryBarView(onInput: { text in
                    if let sessionId = appState.activeSessionId {
                        sendInput(text, to: sessionId)
                    }
                })
                .environment(appState)
            }
        }
        .onChange(of: appState.keyboardVisible) { _, visible in
            // Only update if different to avoid cycles
            if inputFocused != visible {
                inputFocused = visible
            }
        }
        .onChange(of: inputFocused) { _, focused in
            // Only update if different to avoid cycles
            if appState.keyboardVisible != focused {
                appState.keyboardVisible = focused
            }
        }
        .onChange(of: appState.activeSessionId) { _, sessionId in
            // Auto-focus keyboard when a session becomes active
            if sessionId != nil && !inputFocused {
                inputFocused = true
                appState.keyboardVisible = true
            }
        }
    }

    private func sendInput(_ text: String, to sessionId: String) {
        WebSocketClient.shared.send(.terminalInput(sessionId: sessionId, data: text))
    }

    private func handleSpecialKey(_ key: SpecialKey, session sessionId: String) {
        let code: String
        switch key {
        case .backspace: code = "\u{7F}"
        case .enter: code = "\r"
        case .tab: code = "\t"
        case .escape: code = "\u{1B}"
        case .arrowUp: code = "\u{1B}[A"
        case .arrowDown: code = "\u{1B}[B"
        case .arrowLeft: code = "\u{1B}[D"
        case .arrowRight: code = "\u{1B}[C"
        }
        sendInput(code, to: sessionId)
    }
}

// Notification for terminal output
extension Notification.Name {
    static let terminalOutput = Notification.Name("terminalOutput")
}
