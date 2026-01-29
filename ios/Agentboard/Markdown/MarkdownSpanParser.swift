// Agentboard/Markdown/MarkdownSpanParser.swift
import Foundation

/// Parses inline markdown formatting into MarkdownSpan tokens.
/// Ported from Happy's parseMarkdownSpans.ts
struct MarkdownSpanParser {

    /// Parse a string into an array of inline markdown spans.
    static func parse(_ text: String) -> [MarkdownSpan] {
        var spans: [MarkdownSpan] = []
        var remaining = text[text.startIndex...]

        while !remaining.isEmpty {
            if let result = tryInlineCode(&remaining) {
                spans.append(result)
            } else if let result = tryLink(&remaining) {
                spans.append(result)
            } else if let result = tryBoldItalic(&remaining) {
                spans.append(result)
            } else if let result = tryBold(&remaining) {
                spans.append(result)
            } else if let result = tryItalic(&remaining) {
                spans.append(result)
            } else {
                let ch = remaining.removeFirst()
                if case .text(let prev) = spans.last {
                    spans[spans.count - 1] = .text(prev + String(ch))
                } else {
                    spans.append(.text(String(ch)))
                }
            }
        }

        return spans
    }

    // MARK: - Inline Patterns

    private static func tryInlineCode(_ remaining: inout Substring) -> MarkdownSpan? {
        guard remaining.hasPrefix("`") else { return nil }

        let afterTick = remaining.index(after: remaining.startIndex)
        guard let endIdx = remaining[afterTick...].firstIndex(of: "`") else { return nil }

        let code = String(remaining[afterTick..<endIdx])
        remaining = remaining[remaining.index(after: endIdx)...]
        return .code(code)
    }

    private static func tryLink(_ remaining: inout Substring) -> MarkdownSpan? {
        guard remaining.hasPrefix("[") else { return nil }

        let afterBracket = remaining.index(after: remaining.startIndex)
        guard let closeBracket = remaining[afterBracket...].firstIndex(of: "]") else { return nil }

        let afterCloseBracket = remaining.index(after: closeBracket)
        guard afterCloseBracket < remaining.endIndex,
              remaining[afterCloseBracket] == "(" else { return nil }

        let afterParen = remaining.index(after: afterCloseBracket)
        guard let closeParen = remaining[afterParen...].firstIndex(of: ")") else { return nil }

        let text = String(remaining[afterBracket..<closeBracket])
        let url = String(remaining[afterParen..<closeParen])
        remaining = remaining[remaining.index(after: closeParen)...]
        return .link(text: text, url: url)
    }

    private static func tryBoldItalic(_ remaining: inout Substring) -> MarkdownSpan? {
        return tryDelimited(&remaining, delimiter: "***", maker: { .boldItalic($0) })
            ?? tryDelimited(&remaining, delimiter: "___", maker: { .boldItalic($0) })
    }

    private static func tryBold(_ remaining: inout Substring) -> MarkdownSpan? {
        return tryDelimited(&remaining, delimiter: "**", maker: { .bold($0) })
            ?? tryDelimited(&remaining, delimiter: "__", maker: { .bold($0) })
    }

    private static func tryItalic(_ remaining: inout Substring) -> MarkdownSpan? {
        return tryDelimited(&remaining, delimiter: "*", maker: { .italic($0) })
            ?? tryDelimited(&remaining, delimiter: "_", maker: { .italic($0) })
    }

    private static func tryDelimited(
        _ remaining: inout Substring,
        delimiter: String,
        maker: (String) -> MarkdownSpan
    ) -> MarkdownSpan? {
        guard remaining.hasPrefix(delimiter) else { return nil }

        let afterOpen = remaining.index(remaining.startIndex, offsetBy: delimiter.count)
        guard afterOpen < remaining.endIndex else { return nil }

        let searchRange = remaining[afterOpen...]
        guard let closeRange = searchRange.range(of: delimiter) else { return nil }

        let content = String(remaining[afterOpen..<closeRange.lowerBound])
        guard !content.isEmpty else { return nil }

        remaining = remaining[closeRange.upperBound...]
        return maker(content)
    }
}
