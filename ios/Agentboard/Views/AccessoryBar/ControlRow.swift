// Agentboard/Views/AccessoryBar/ControlRow.swift
import SwiftUI

struct ControlRow: View {
    @Binding var ctrlActive: Bool
    @Binding var keyboardVisible: Bool

    var onEscape: () -> Void
    var onDeleteWord: () -> Void
    var onReturn: () -> Void
    var onPaste: () -> Void
    var onNumPadStart: (CGPoint) -> Void
    var onDPadStart: (CGPoint) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                // Ctrl modifier
                ControlButton(label: "ctrl", isActive: ctrlActive) {
                    ctrlActive.toggle()
                }

                // Escape
                ControlButton(label: "esc") {
                    onEscape()
                }

                // 123 (NumPad)
                NumPadTrigger(onStart: onNumPadStart)

                // Arrow keys (DPad)
                DPadTrigger(onStart: onDPadStart)

                // Delete word
                ControlButton(icon: "delete.backward") {
                    onDeleteWord()
                }

                // Return/Enter
                ControlButton(icon: "return") {
                    onReturn()
                }

                // Paste
                ControlButton(icon: "doc.on.clipboard") {
                    onPaste()
                }

                // Keyboard toggle
                ControlButton(icon: keyboardVisible ? "keyboard.fill" : "keyboard", isActive: keyboardVisible) {
                    keyboardVisible.toggle()
                }
            }
            .padding(.horizontal, 8)
        }
        .padding(.vertical, 8)
        .background(Color.bgElevated)
    }
}

// Simple control button with fixed size
struct ControlButton: View {
    var label: String? = nil
    var icon: String? = nil
    var isActive: Bool = false
    var action: () -> Void

    var body: some View {
        Button(action: {
            action()
            HapticEngine.shared.buttonTap()
        }) {
            Group {
                if let label = label {
                    Text(label)
                        .font(.system(size: 13, weight: .medium))
                } else if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: 15))
                }
            }
            .foregroundColor(isActive ? .accent : .textPrimary)
            .frame(minWidth: 44, minHeight: 36)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isActive ? Color.accent.opacity(0.15) : Color.bgControl)
            )
        }
    }
}

// Long-press trigger for NumPad
struct NumPadTrigger: View {
    var onStart: (CGPoint) -> Void

    @State private var pressing = false

    var body: some View {
        Text("123")
            .font(.system(size: 13, weight: .medium))
            .foregroundColor(.textPrimary)
            .frame(minWidth: 44, minHeight: 36)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.bgControl)
            )
            .opacity(pressing ? 0.6 : 1.0)
            .gesture(
                LongPressGesture(minimumDuration: 0.15)
                    .onChanged { _ in pressing = true }
                    .onEnded { _ in
                        pressing = false
                        HapticEngine.shared.buttonTap()
                    }
                    .simultaneously(with:
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                if pressing {
                                    onStart(value.location)
                                }
                            }
                    )
            )
    }
}

// Long-press trigger for DPad
struct DPadTrigger: View {
    var onStart: (CGPoint) -> Void

    @State private var pressing = false

    var body: some View {
        Image(systemName: "arrow.up.and.down.and.arrow.left.and.right")
            .font(.system(size: 15))
            .foregroundColor(.textPrimary)
            .frame(minWidth: 44, minHeight: 36)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.bgControl)
            )
            .opacity(pressing ? 0.6 : 1.0)
            .gesture(
                LongPressGesture(minimumDuration: 0.15)
                    .onChanged { _ in pressing = true }
                    .onEnded { _ in
                        pressing = false
                        HapticEngine.shared.buttonTap()
                    }
                    .simultaneously(with:
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                if pressing {
                                    onStart(value.location)
                                }
                            }
                    )
            )
    }
}
