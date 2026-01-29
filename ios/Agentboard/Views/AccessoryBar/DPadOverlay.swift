// Agentboard/Views/AccessoryBar/DPadOverlay.swift
import SwiftUI

enum DPadDirection: CaseIterable {
    case up, down, left, right
}

struct DPadOverlay: View {
    let anchor: CGPoint
    var onDirection: (DPadDirection) -> Void
    var onEnd: () -> Void

    @State private var currentDirection: DPadDirection?
    @State private var dragOffset: CGSize = .zero
    @State private var repeatTimer: Timer?

    private let radius: CGFloat = 70
    private let deadZone: CGFloat = 15

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // Background circle
                Circle()
                    .fill(Color.bgElevated.opacity(0.95))
                    .frame(width: radius * 2, height: radius * 2)

                // Outer ring
                Circle()
                    .stroke(Color.border, lineWidth: 1)
                    .frame(width: radius * 2, height: radius * 2)

                // Direction indicators
                ForEach(DPadDirection.allCases, id: \.self) { direction in
                    DirectionIndicator(
                        direction: direction,
                        isActive: currentDirection == direction
                    )
                }

                // Center knob
                Circle()
                    .fill(currentDirection != nil ? Color.accent : Color.textMuted)
                    .frame(width: 24, height: 24)
                    .offset(knobOffset)

                // Center dot
                Circle()
                    .fill(Color.bgElevated)
                    .frame(width: 8, height: 8)
                    .offset(knobOffset)
            }
            .position(
                x: min(max(radius + 20, anchor.x), geo.size.width - radius - 20),
                y: anchor.y - radius - 40
            )
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        dragOffset = value.translation
                        updateDirection()
                    }
                    .onEnded { _ in
                        stopRepeat()
                        onEnd()
                    }
            )
        }
    }

    private var knobOffset: CGSize {
        let distance = sqrt(pow(dragOffset.width, 2) + pow(dragOffset.height, 2))
        let maxDistance = radius - 20

        if distance <= maxDistance {
            return dragOffset
        }

        let scale = maxDistance / distance
        return CGSize(
            width: dragOffset.width * scale,
            height: dragOffset.height * scale
        )
    }

    private func updateDirection() {
        let distance = sqrt(pow(dragOffset.width, 2) + pow(dragOffset.height, 2))

        if distance < deadZone {
            if currentDirection != nil {
                currentDirection = nil
                stopRepeat()
            }
            return
        }

        let angle = atan2(dragOffset.height, dragOffset.width)
        let newDirection: DPadDirection

        if angle >= -0.785 && angle < 0.785 {
            newDirection = .right
        } else if angle >= 0.785 && angle < 2.356 {
            newDirection = .down
        } else if angle >= -2.356 && angle < -0.785 {
            newDirection = .up
        } else {
            newDirection = .left
        }

        if newDirection != currentDirection {
            currentDirection = newDirection
            onDirection(newDirection)

            // Haptic based on distance
            let intensity = min((distance - deadZone) / (radius - deadZone), 1.0)
            HapticEngine.shared.dPadTick(intensity: intensity)

            startRepeat(distance: distance)
        }
    }

    private func startRepeat(distance: CGFloat) {
        stopRepeat()

        // Repeat rate based on distance (closer = slower, farther = faster)
        let normalizedDistance = min((distance - deadZone) / (radius - deadZone), 1.0)
        let interval = 0.3 - (normalizedDistance * 0.2) // 0.3s to 0.1s

        repeatTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { _ in
            if let dir = currentDirection {
                onDirection(dir)
                HapticEngine.shared.lightTap()
            }
        }
    }

    private func stopRepeat() {
        repeatTimer?.invalidate()
        repeatTimer = nil
    }
}

struct DirectionIndicator: View {
    let direction: DPadDirection
    let isActive: Bool

    var body: some View {
        Text(symbol)
            .font(.system(size: 20, weight: .bold))
            .foregroundColor(isActive ? .accent : .textMuted.opacity(0.5))
            .offset(offset)
    }

    private var symbol: String {
        switch direction {
        case .up: return "↑"
        case .down: return "↓"
        case .left: return "←"
        case .right: return "→"
        }
    }

    private var offset: CGSize {
        let distance: CGFloat = 45
        switch direction {
        case .up: return CGSize(width: 0, height: -distance)
        case .down: return CGSize(width: 0, height: distance)
        case .left: return CGSize(width: -distance, height: 0)
        case .right: return CGSize(width: distance, height: 0)
        }
    }
}
