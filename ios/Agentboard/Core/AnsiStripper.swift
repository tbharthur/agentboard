// Agentboard/Core/AnsiStripper.swift
import Foundation

/// Strips ANSI escape sequences from terminal output.
/// Used to clean tmux control mode %output data before markdown parsing.
enum AnsiStripper {
    // CSI sequences: \x1b[ followed by parameter bytes and a final letter
    // Covers SGR (colors), cursor movement, erase, mode set/reset, etc.
    // OSC sequences: \x1b] followed by payload ending with BEL or ST
    // Character set selection: \x1b( followed by a character
    // Simple escapes: \x1b followed by single character (=, >, M, etc.)
    private static let pattern = try! NSRegularExpression(
        pattern: """
            \\x1b\\[[0-9;?]*[A-Za-z]|\
            \\x1b\\].*?(?:\\x07|\\x1b\\\\)|\
            \\x1b\\([A-Za-z0-9]|\
            \\x1b[A-Za-z=>]
            """,
        options: [.dotMatchesLineSeparators]
    )

    static func strip(_ text: String) -> String {
        let range = NSRange(text.startIndex..., in: text)
        return pattern.stringByReplacingMatches(in: text, range: range, withTemplate: "")
    }
}
