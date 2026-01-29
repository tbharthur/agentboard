// Agentboard/App/AppState.swift
import SwiftUI

@Observable
class AppState {
    // MARK: - Connection
    var connectionStatus: ConnectionStatus = .disconnected
    var serverURL: URL?

    // MARK: - Sessions
    // Sessions updates shouldn't trigger re-renders (they update frequently)
    @ObservationIgnored var sessions: [Session] = []
    var activeSessionId: String?
    @ObservationIgnored var agentSessions: (active: [AgentSession], inactive: [AgentSession]) = ([], [])

    var activeSession: Session? {
        sessions.first { $0.id == activeSessionId }
    }

    var sortedSessions: [Session] {
        sessions.sorted { lhs, rhs in
            // Pinned first
            if (lhs.isPinned ?? false) != (rhs.isPinned ?? false) {
                return lhs.isPinned ?? false
            }
            // Then by last activity
            return lhs.lastActivity > rhs.lastActivity
        }
    }

    // MARK: - UI State
    var showingDrawer = false
    var showingSettings = false
    var keyboardVisible = false

    // MARK: - Singleton for Intents
    static let shared = AppState()

    // MARK: - Session Management

    func updateSessions(_ newSessions: [Session]) {
        sessions = newSessions
        // Auto-select first session if none selected
        if activeSessionId == nil, let first = sortedSessions.first {
            activeSessionId = first.id
        }
    }

    func updateSession(_ session: Session) {
        if let index = sessions.firstIndex(where: { $0.id == session.id }) {
            sessions[index] = session
        }
    }

    func addSession(_ session: Session) {
        sessions.append(session)
        activeSessionId = session.id
    }

    func removeSession(id: String) {
        sessions.removeAll { $0.id == id }
        if activeSessionId == id {
            activeSessionId = sortedSessions.first?.id
        }
    }

    func selectSession(_ session: Session) {
        activeSessionId = session.id
        showingDrawer = false
    }
}

enum ConnectionStatus: Equatable {
    case disconnected
    case connecting
    case connected
    case reconnecting(attempt: Int)
    case error(String)

    var displayText: String {
        switch self {
        case .disconnected: return "DISCONNECTED"
        case .connecting: return "CONNECTING..."
        case .connected: return "CONNECTED"
        case .reconnecting(let attempt): return "RECONNECTING (\(attempt))"
        case .error(let msg): return "ERROR: \(msg)"
        }
    }

    var color: Color {
        switch self {
        case .disconnected: return .textMuted
        case .connecting, .reconnecting: return .accentWarning
        case .connected: return .accentSuccess
        case .error: return .accentDanger
        }
    }
}
