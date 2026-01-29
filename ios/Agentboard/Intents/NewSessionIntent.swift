// Agentboard/Intents/NewSessionIntent.swift
import AppIntents

struct NewSessionIntent: AppIntent {
    static var title: LocalizedStringResource = "Start Claude Session"
    static var description = IntentDescription("Start a new Claude Code session in a project")

    @Parameter(title: "Project")
    var projectName: String

    static var parameterSummary: some ParameterSummary {
        Summary("Start Claude in \(\.$projectName)")
    }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let path = ProjectResolver.resolve(projectName)

        WebSocketClient.shared.send(
            .sessionCreate(projectPath: path, name: nil, command: nil)
        )

        return .result(dialog: "Starting session in \(projectName)")
    }
}

struct ProjectResolver {
    static let knownProjects: [String: String] = [
        "assistant": "~/Dev/assistant",
        "partnership": "~/Dev/partnership_webapp",
        "partnership webapp": "~/Dev/partnership_webapp",
        "pwa": "~/Dev/partnership_webapp",
        "qbo": "~/Dev/qbo-mcp",
        "quickbooks": "~/Dev/qbo-mcp",
        "agentboard": "~/Dev/agentboard",
        "telegram": "~/Dev/telegram-claude-bridge",
    ]

    static func resolve(_ name: String) -> String {
        let normalized = name.lowercased().trimmingCharacters(in: .whitespaces)
        return knownProjects[normalized] ?? "~/Dev/\(name)"
    }
}
