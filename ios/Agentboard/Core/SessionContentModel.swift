// Agentboard/Core/SessionContentModel.swift
import Foundation

/// Observable model that bridges WebSocket output to SwiftUI content views.
/// Solves the problem of feeding data into ContentSessionView from outside.
@Observable
class SessionContentModel {
    private(set) var content: String = ""
    private(set) var blocks: [MarkdownBlock] = []

    /// Append new output and re-parse markdown.
    func appendContent(_ text: String) {
        content += AnsiStripper.strip(text)
        blocks = MarkdownParser.parse(content)
    }

    /// Replace all content (e.g. on session switch).
    func setContent(_ text: String) {
        content = AnsiStripper.strip(text)
        blocks = MarkdownParser.parse(content)
    }

    /// Clear all content.
    func clear() {
        content = ""
        blocks = []
    }
}
