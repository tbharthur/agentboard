// Agentboard/Styles/IndustrialButtonStyle.swift
import SwiftUI

struct IndustrialButtonStyle: ButtonStyle {
    var isActive: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 14, weight: .medium))
            .foregroundColor(isActive ? .accent : .textPrimary)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isActive ? Color.accent.opacity(0.15) : Color.bgControl)
            )
            .opacity(configuration.isPressed ? 0.6 : 1.0)
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == IndustrialButtonStyle {
    static var industrial: IndustrialButtonStyle { IndustrialButtonStyle() }
    static func industrial(isActive: Bool) -> IndustrialButtonStyle {
        IndustrialButtonStyle(isActive: isActive)
    }
}
