// Agentboard/Models/Session.swift
import Foundation

struct Session: Identifiable, Codable, Equatable {
    let id: String
    var name: String
    var tmuxWindow: String
    var projectPath: String
    var status: SessionStatus
    var lastActivity: Date
    var createdAt: Date
    var agentType: AgentType?
    var source: SessionSource
    var command: String?
    var agentSessionId: String?
    var agentSessionName: String?
    var lastUserMessage: String?
    var isPinned: Bool?

    var displayName: String {
        agentSessionName ?? name
    }
}

enum SessionStatus: String, Codable {
    case working
    case waiting
    case permission
    case unknown
}

enum AgentType: String, Codable {
    case claude
    case codex
}

enum SessionSource: String, Codable {
    case managed
    case external
}

struct AgentSession: Identifiable, Codable {
    let sessionId: String
    var logFilePath: String
    var projectPath: String
    var agentType: AgentType
    var displayName: String
    var createdAt: Date
    var lastActivityAt: Date
    var isActive: Bool
    var lastUserMessage: String?
    var isPinned: Bool?
    var lastResumeError: String?

    var id: String { sessionId }
}
