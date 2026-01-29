// Agentboard/Core/HapticEngine.swift
import UIKit

final class HapticEngine {
    static let shared = HapticEngine()

    private let impactLight = UIImpactFeedbackGenerator(style: .light)
    private let impactMedium = UIImpactFeedbackGenerator(style: .medium)
    private let impactHeavy = UIImpactFeedbackGenerator(style: .heavy)
    private let selection = UISelectionFeedbackGenerator()
    private let notification = UINotificationFeedbackGenerator()

    private var hapticsEnabled = true

    private init() {
        // Prepare generators
        impactLight.prepare()
        impactMedium.prepare()
        selection.prepare()
    }

    func setEnabled(_ enabled: Bool) {
        hapticsEnabled = enabled
    }

    func buttonTap() {
        guard hapticsEnabled else { return }
        impactMedium.impactOccurred(intensity: 0.6)
    }

    func lightTap() {
        guard hapticsEnabled else { return }
        impactLight.impactOccurred()
    }

    func selectionChanged() {
        guard hapticsEnabled else { return }
        selection.selectionChanged()
    }

    func dPadTick(intensity: CGFloat) {
        guard hapticsEnabled else { return }
        impactMedium.impactOccurred(intensity: min(intensity, 1.0))
    }

    func success() {
        guard hapticsEnabled else { return }
        notification.notificationOccurred(.success)
    }

    func warning() {
        guard hapticsEnabled else { return }
        notification.notificationOccurred(.warning)
    }

    func error() {
        guard hapticsEnabled else { return }
        notification.notificationOccurred(.error)
    }
}
