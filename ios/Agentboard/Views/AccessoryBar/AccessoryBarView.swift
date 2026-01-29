// Agentboard/Views/AccessoryBar/AccessoryBarView.swift
import SwiftUI
import UIKit

struct AccessoryBarView: View {
    @Environment(AppState.self) var appState

    @State private var ctrlActive = false
    @State private var showNumPad = false
    @State private var showDPad = false
    @State private var overlayAnchor: CGPoint = .zero

    var onInput: (String) -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Session switcher (only when 2+ sessions)
            if appState.sessions.count > 1 {
                SessionSwitcherRow()
            }

            // Main control row
            ControlRow(
                ctrlActive: $ctrlActive,
                keyboardVisible: Binding(
                    get: { appState.keyboardVisible },
                    set: { appState.keyboardVisible = $0 }
                ),
                onEscape: { sendEscape() },
                onDeleteWord: { sendDeleteWord() },
                onReturn: { sendReturn() },
                onPaste: { pasteClipboard() },
                onNumPadStart: { point in
                    overlayAnchor = point
                    showNumPad = true
                },
                onDPadStart: { point in
                    overlayAnchor = point
                    showDPad = true
                }
            )
        }
        .overlay {
            if showNumPad {
                NumPadOverlay(
                    anchor: overlayAnchor,
                    onSelect: { digit in
                        sendInput(digit)
                        showNumPad = false
                    },
                    onCancel: { showNumPad = false }
                )
            }

            if showDPad {
                DPadOverlay(
                    anchor: overlayAnchor,
                    onDirection: { direction in
                        sendArrow(direction)
                    },
                    onEnd: { showDPad = false }
                )
            }
        }
    }

    // MARK: - Input Handling

    private func sendInput(_ text: String) {
        if ctrlActive {
            // Convert to control character
            if let char = text.first, char.isLetter {
                let code = Int(char.asciiValue ?? 0)
                let ctrl = code & 0x1F // Convert to control code
                onInput(String(UnicodeScalar(ctrl)!))
            }
            ctrlActive = false
        } else {
            onInput(text)
        }
    }

    private func sendEscape() {
        onInput("\u{1B}")
    }

    private func sendDeleteWord() {
        // Ctrl+W
        onInput("\u{17}")
    }

    private func sendReturn() {
        onInput("\r")
    }

    private func sendArrow(_ direction: DPadDirection) {
        let code: String
        switch direction {
        case .up: code = "\u{1B}[A"
        case .down: code = "\u{1B}[B"
        case .right: code = "\u{1B}[C"
        case .left: code = "\u{1B}[D"
        }
        onInput(code)
    }

    private func pasteClipboard() {
        if let string = UIPasteboard.general.string {
            onInput(string)
        }
    }
}

// Placeholder for session switcher
struct SessionSwitcherRow: View {
    @Environment(AppState.self) var appState

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 4) {
                ForEach(Array(appState.sortedSessions.enumerated()), id: \.element.id) { index, session in
                    SessionPill(
                        index: index + 1,
                        session: session,
                        isActive: session.id == appState.activeSessionId
                    )
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
        }
        .background(Color.bgPrimary)
    }
}

struct SessionPill: View {
    let index: Int
    let session: Session
    let isActive: Bool

    @Environment(AppState.self) var appState

    var body: some View {
        Button(action: {
            appState.selectSession(session)
            HapticEngine.shared.selectionChanged()
        }) {
            HStack(spacing: 6) {
                Text("\(index)")
                    .font(.system(size: 13, weight: .semibold, design: .monospaced))

                Circle()
                    .fill(statusColor)
                    .frame(width: 6, height: 6)
            }
            .foregroundColor(isActive ? .accent : .textMuted)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isActive ? Color.accent.opacity(0.15) : Color.bgControl)
            )
        }
    }

    var statusColor: Color {
        switch session.status {
        case .working: return .accentSuccess
        case .waiting: return .accentWarning
        case .permission: return .accentDanger
        case .unknown: return .textMuted
        }
    }
}
