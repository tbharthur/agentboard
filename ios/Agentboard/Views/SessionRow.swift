// Agentboard/Views/SessionRow.swift
import SwiftUI

struct SessionRow: View {
    let session: Session
    let isActive: Bool
    var onSelect: () -> Void
    var onKill: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 12) {
                // Status indicator
                Circle()
                    .fill(statusColor)
                    .frame(width: 8, height: 8)

                VStack(alignment: .leading, spacing: 4) {
                    Text(session.displayName)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(isActive ? .accent : .textPrimary)

                    Text(session.lastUserMessage ?? "Ready")
                        .font(.system(size: 12))
                        .foregroundColor(.textMuted)
                        .lineLimit(1)
                }

                Spacer()

                Text(formatTime(session.lastActivity))
                    .font(.system(size: 11))
                    .foregroundColor(.textMuted.opacity(0.6))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(isActive ? Color.bgElevated : Color.clear)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive, action: onKill) {
                Label("Kill", systemImage: "xmark.circle")
            }
        }
    }

    private var statusColor: Color {
        switch session.status {
        case .working: return .accentSuccess
        case .waiting: return .accentWarning
        case .permission: return .accentDanger
        case .unknown: return .textMuted
        }
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
}
