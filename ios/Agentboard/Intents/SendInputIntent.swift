// Agentboard/Intents/SendInputIntent.swift
import AppIntents

struct SendInputIntent: AppIntent {
    static var title: LocalizedStringResource = "Send to Claude"
    static var description = IntentDescription("Send text input to the active Claude session")

    @Parameter(title: "Message")
    var message: String

    static var parameterSummary: some ParameterSummary {
        Summary("Send \(\.$message) to Claude")
    }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let appState = AppState.shared

        guard let session = appState.activeSession else {
            throw SendInputError.noActiveSession
        }

        WebSocketClient.shared.send(
            .terminalInput(sessionId: session.id, data: message + "\n")
        )

        return .result(dialog: "Sent to \(session.displayName)")
    }
}

enum SendInputError: Error, CustomLocalizedStringResourceConvertible {
    case noActiveSession
    case notConnected

    var localizedStringResource: LocalizedStringResource {
        switch self {
        case .noActiveSession:
            return "No active Claude session"
        case .notConnected:
            return "Not connected to server"
        }
    }
}
