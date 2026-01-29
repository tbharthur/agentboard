// Agentboard/Views/SessionDrawer.swift
import SwiftUI

struct SessionDrawer: View {
    @Environment(AppState.self) var appState
    @Environment(\.dismiss) var dismiss

    var onKillSession: (String) -> Void
    var onNewSession: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Text("AGENTBOARD")
                    .font(Fonts.spaceMonoBold(14))
                    .foregroundColor(.textPrimary)
                    .kerning(2)

                Spacer()

                // Connection status
                Circle()
                    .fill(appState.connectionStatus.color)
                    .frame(width: 8, height: 8)

                Button(action: { appState.showingSettings = true }) {
                    Image(systemName: "gearshape")
                        .font(.system(size: 16))
                        .foregroundColor(.textMuted)
                }
            }
            .padding()
            .background(Color.bgElevated)

            // Divider
            Rectangle()
                .fill(Color.border)
                .frame(height: 1)

            // Session list
            ScrollView {
                LazyVStack(spacing: 1) {
                    ForEach(appState.sortedSessions) { session in
                        SessionRow(
                            session: session,
                            isActive: session.id == appState.activeSessionId,
                            onSelect: {
                                appState.selectSession(session)
                                HapticEngine.shared.selectionChanged()
                            },
                            onKill: {
                                onKillSession(session.id)
                            }
                        )
                    }
                }
            }

            Spacer()

            // New session button
            Button(action: {
                onNewSession()
                HapticEngine.shared.buttonTap()
            }) {
                HStack {
                    Image(systemName: "plus")
                    Text("New Session")
                }
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.accent)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.accent.opacity(0.1))
                )
            }
            .padding()
        }
        .frame(width: UIScreen.main.bounds.width * 0.75)
        .background(Color.bgPrimary)
    }
}
