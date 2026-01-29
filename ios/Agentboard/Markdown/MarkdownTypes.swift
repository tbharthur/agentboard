// Agentboard/Markdown/MarkdownTypes.swift
import Foundation

/// Inline-level markdown elements
enum MarkdownSpan: Equatable {
    case text(String)
    case bold(String)
    case italic(String)
    case boldItalic(String)
    case code(String)
    case link(text: String, url: String)
}

/// Block-level markdown elements
enum MarkdownBlock: Equatable {
    case paragraph([MarkdownSpan])
    case header(level: Int, [MarkdownSpan])
    case codeBlock(language: String?, code: String)
    case table(headers: [String], rows: [[String]])
    case bulletList([[MarkdownSpan]])
    case numberedList([[MarkdownSpan]])
    case horizontalRule
}
