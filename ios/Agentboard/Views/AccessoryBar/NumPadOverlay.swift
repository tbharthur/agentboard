// Agentboard/Views/AccessoryBar/NumPadOverlay.swift
import SwiftUI

struct NumPadOverlay: View {
    let anchor: CGPoint
    var onSelect: (String) -> Void
    var onCancel: () -> Void

    @State private var selectedDigit: String?
    @State private var dragLocation: CGPoint?

    private let digits = [
        ["1", "2", "3"],
        ["4", "5", "6"],
        ["7", "8", "9"],
        ["", "0", ""]
    ]

    private let cellSize: CGFloat = 56
    private let spacing: CGFloat = 1

    var body: some View {
        GeometryReader { geo in
            VStack(spacing: spacing) {
                ForEach(0..<4, id: \.self) { row in
                    HStack(spacing: spacing) {
                        ForEach(0..<3, id: \.self) { col in
                            let digit = digits[row][col]
                            NumPadKey(
                                digit: digit,
                                isSelected: selectedDigit == digit && !digit.isEmpty
                            )
                        }
                    }
                }

                // Release indicator
                Text("Release to send")
                    .font(Fonts.dmMono(10))
                    .foregroundColor(.textMuted)
                    .padding(.top, 4)
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.bgElevated)
            )
            .shadow(color: .black.opacity(0.3), radius: 10, y: 4)
            .position(
                x: min(max(padWidth / 2 + 20, anchor.x), geo.size.width - padWidth / 2 - 20),
                y: anchor.y - padHeight - 20
            )
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        dragLocation = value.location
                        updateSelection(in: geo)
                    }
                    .onEnded { _ in
                        if let digit = selectedDigit, !digit.isEmpty {
                            onSelect(digit)
                        } else {
                            onCancel()
                        }
                    }
            )
        }
    }

    private var padWidth: CGFloat {
        cellSize * 3 + spacing * 2 + 16
    }

    private var padHeight: CGFloat {
        cellSize * 4 + spacing * 3 + 16 + 24 // +24 for release text
    }

    private func updateSelection(in geo: GeometryProxy) {
        guard let location = dragLocation else { return }

        // Convert to pad-local coordinates
        let padX = min(max(padWidth / 2 + 20, anchor.x), geo.size.width - padWidth / 2 - 20)
        let padY = anchor.y - padHeight - 20

        let localX = location.x - (padX - padWidth / 2) - 8
        let localY = location.y - (padY - padHeight / 2) - 8

        let col = Int(localX / (cellSize + spacing))
        let row = Int(localY / (cellSize + spacing))

        if row >= 0 && row < 4 && col >= 0 && col < 3 {
            let digit = digits[row][col]
            if digit != selectedDigit && !digit.isEmpty {
                selectedDigit = digit
                HapticEngine.shared.selectionChanged()
            } else if digit.isEmpty {
                selectedDigit = nil
            }
        } else {
            selectedDigit = nil
        }
    }
}

struct NumPadKey: View {
    let digit: String
    let isSelected: Bool

    var body: some View {
        Text(digit)
            .font(.system(size: 20, weight: .medium, design: .monospaced))
            .foregroundColor(isSelected ? .white : .textPrimary)
            .frame(width: 56, height: 56)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? Color.accent : Color.bgControl)
            )
            .opacity(digit.isEmpty ? 0 : 1)
    }
}
