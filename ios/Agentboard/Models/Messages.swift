// Agentboard/Models/Messages.swift
import Foundation

// MARK: - Client Messages (iOS → Server)

enum ClientMessage: Encodable {
    case terminalAttach(sessionId: String, cols: Int, rows: Int)
    case terminalDetach(sessionId: String)
    case terminalInput(sessionId: String, data: String)
    case terminalResize(sessionId: String, cols: Int, rows: Int)
    case sessionCreate(projectPath: String, name: String?, command: String?)
    case sessionKill(sessionId: String)
    case sessionRename(sessionId: String, newName: String)
    case sessionPin(sessionId: String, isPinned: Bool)
    case sessionRefresh
    case terminalFlow(sessionId: String, paneId: String, action: String)

    private enum CodingKeys: String, CodingKey {
        case type
        case sessionId, cols, rows, data
        case projectPath, name, command
        case newName, isPinned
        case paneId, action
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        switch self {
        case .terminalAttach(let sessionId, let cols, let rows):
            try container.encode("terminal-attach", forKey: .type)
            try container.encode(sessionId, forKey: .sessionId)
            try container.encode(cols, forKey: .cols)
            try container.encode(rows, forKey: .rows)

        case .terminalDetach(let sessionId):
            try container.encode("terminal-detach", forKey: .type)
            try container.encode(sessionId, forKey: .sessionId)

        case .terminalInput(let sessionId, let data):
            try container.encode("terminal-input", forKey: .type)
            try container.encode(sessionId, forKey: .sessionId)
            try container.encode(data, forKey: .data)

        case .terminalResize(let sessionId, let cols, let rows):
            try container.encode("terminal-resize", forKey: .type)
            try container.encode(sessionId, forKey: .sessionId)
            try container.encode(cols, forKey: .cols)
            try container.encode(rows, forKey: .rows)

        case .sessionCreate(let projectPath, let name, let command):
            try container.encode("session-create", forKey: .type)
            try container.encode(projectPath, forKey: .projectPath)
            try container.encodeIfPresent(name, forKey: .name)
            try container.encodeIfPresent(command, forKey: .command)

        case .sessionKill(let sessionId):
            try container.encode("session-kill", forKey: .type)
            try container.encode(sessionId, forKey: .sessionId)

        case .sessionRename(let sessionId, let newName):
            try container.encode("session-rename", forKey: .type)
            try container.encode(sessionId, forKey: .sessionId)
            try container.encode(newName, forKey: .newName)

        case .sessionPin(let sessionId, let isPinned):
            try container.encode("session-pin", forKey: .type)
            try container.encode(sessionId, forKey: .sessionId)
            try container.encode(isPinned, forKey: .isPinned)

        case .sessionRefresh:
            try container.encode("session-refresh", forKey: .type)

        case .terminalFlow(let sessionId, let paneId, let action):
            try container.encode("terminal-flow", forKey: .type)
            try container.encode(sessionId, forKey: .sessionId)
            try container.encode(paneId, forKey: .paneId)
            try container.encode(action, forKey: .action)
        }
    }
}

// MARK: - Server Messages (Server → iOS)

enum ServerMessage: Decodable {
    case sessions([Session])
    case sessionUpdate(Session)
    case sessionCreated(Session)
    case sessionRemoved(sessionId: String)
    case agentSessions(active: [AgentSession], inactive: [AgentSession])
    case terminalOutput(sessionId: String, data: String)
    case terminalReady(sessionId: String)
    case terminalError(sessionId: String, code: Int, message: String, retryable: Bool)
    case error(message: String)
    // Control mode messages
    case cmOutput(sessionId: String, paneId: String, data: String, latencyMs: Double?)
    case cmCommandStart(sessionId: String, cmdNum: Int, timestamp: Double)
    case cmCommandEnd(sessionId: String, cmdNum: Int, success: Bool)
    case cmWindow(sessionId: String, event: String, windowId: String, name: String?)
    case cmSession(sessionId: String, event: String, name: String)
    case cmFlow(sessionId: String, event: String, paneId: String)
    case cmExit(sessionId: String, reason: String?)
    case unknown(type: String)

    private enum CodingKeys: String, CodingKey {
        case type
        case sessions, session, sessionId
        case active, inactive
        case data, code, message, retryable
        case paneId, latencyMs, cmdNum, timestamp, success
        case event, windowId, name, reason
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)

        switch type {
        case "sessions":
            let sessions = try container.decode([Session].self, forKey: .sessions)
            self = .sessions(sessions)

        case "session-update":
            let session = try container.decode(Session.self, forKey: .session)
            self = .sessionUpdate(session)

        case "session-created":
            let session = try container.decode(Session.self, forKey: .session)
            self = .sessionCreated(session)

        case "session-removed":
            let sessionId = try container.decode(String.self, forKey: .sessionId)
            self = .sessionRemoved(sessionId: sessionId)

        case "agent-sessions":
            let active = try container.decode([AgentSession].self, forKey: .active)
            let inactive = try container.decode([AgentSession].self, forKey: .inactive)
            self = .agentSessions(active: active, inactive: inactive)

        case "terminal-output":
            let sessionId = try container.decode(String.self, forKey: .sessionId)
            let data = try container.decode(String.self, forKey: .data)
            self = .terminalOutput(sessionId: sessionId, data: data)

        case "terminal-ready":
            let sessionId = try container.decode(String.self, forKey: .sessionId)
            self = .terminalReady(sessionId: sessionId)

        case "terminal-error":
            let sessionId = try container.decode(String.self, forKey: .sessionId)
            let code = try container.decode(Int.self, forKey: .code)
            let message = try container.decode(String.self, forKey: .message)
            let retryable = try container.decodeIfPresent(Bool.self, forKey: .retryable) ?? false
            self = .terminalError(sessionId: sessionId, code: code, message: message, retryable: retryable)

        case "error":
            let message = try container.decode(String.self, forKey: .message)
            self = .error(message: message)

        // Control mode messages
        case "cm-output":
            let sessionId = try container.decode(String.self, forKey: .sessionId)
            let paneId = try container.decode(String.self, forKey: .paneId)
            let data = try container.decode(String.self, forKey: .data)
            let latencyMs = try container.decodeIfPresent(Double.self, forKey: .latencyMs)
            self = .cmOutput(sessionId: sessionId, paneId: paneId, data: data, latencyMs: latencyMs)

        case "cm-command-start":
            let sessionId = try container.decode(String.self, forKey: .sessionId)
            let cmdNum = try container.decode(Int.self, forKey: .cmdNum)
            let timestamp = try container.decode(Double.self, forKey: .timestamp)
            self = .cmCommandStart(sessionId: sessionId, cmdNum: cmdNum, timestamp: timestamp)

        case "cm-command-end":
            let sessionId = try container.decode(String.self, forKey: .sessionId)
            let cmdNum = try container.decode(Int.self, forKey: .cmdNum)
            let success = try container.decode(Bool.self, forKey: .success)
            self = .cmCommandEnd(sessionId: sessionId, cmdNum: cmdNum, success: success)

        case "cm-window":
            let sessionId = try container.decode(String.self, forKey: .sessionId)
            let event = try container.decode(String.self, forKey: .event)
            let windowId = try container.decode(String.self, forKey: .windowId)
            let name = try container.decodeIfPresent(String.self, forKey: .name)
            self = .cmWindow(sessionId: sessionId, event: event, windowId: windowId, name: name)

        case "cm-session":
            let sessionId = try container.decode(String.self, forKey: .sessionId)
            let event = try container.decode(String.self, forKey: .event)
            let name = try container.decode(String.self, forKey: .name)
            self = .cmSession(sessionId: sessionId, event: event, name: name)

        case "cm-flow":
            let sessionId = try container.decode(String.self, forKey: .sessionId)
            let event = try container.decode(String.self, forKey: .event)
            let paneId = try container.decode(String.self, forKey: .paneId)
            self = .cmFlow(sessionId: sessionId, event: event, paneId: paneId)

        case "cm-exit":
            let sessionId = try container.decode(String.self, forKey: .sessionId)
            let reason = try container.decodeIfPresent(String.self, forKey: .reason)
            self = .cmExit(sessionId: sessionId, reason: reason)

        default:
            self = .unknown(type: type)
        }
    }
}
