// Agentboard/Markdown/MarkdownBlockParser.swift
import Foundation

/// Parses markdown text into block-level elements.
/// Ported from Happy's parseMarkdownBlock.ts
struct MarkdownBlockParser {

    /// Parse an array of lines into a single MarkdownBlock.
    static func parseBlock(_ lines: [String]) -> MarkdownBlock? {
        guard let firstLine = lines.first else { return nil }

        if isHorizontalRule(firstLine) {
            return .horizontalRule
        }

        if let header = parseHeader(firstLine) {
            return header
        }

        if firstLine.hasPrefix("```") {
            return parseCodeBlock(lines)
        }

        if firstLine.contains("|") && lines.count >= 2 {
            if let table = parseTable(lines) {
                return table
            }
        }

        if isBulletListItem(firstLine) {
            return parseBulletList(lines)
        }

        if isNumberedListItem(firstLine) {
            return parseNumberedList(lines)
        }

        let combinedText = lines.joined(separator: " ")
        let spans = MarkdownSpanParser.parse(combinedText)
        return .paragraph(spans)
    }

    // MARK: - Block Parsers

    private static func isHorizontalRule(_ line: String) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard trimmed.count >= 3 else { return false }
        let stripped = trimmed.replacingOccurrences(of: " ", with: "")
        let chars = Set(stripped)
        return chars.count == 1 && (chars.contains("-") || chars.contains("*") || chars.contains("_"))
    }

    private static func parseHeader(_ line: String) -> MarkdownBlock? {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        var level = 0
        for ch in trimmed {
            if ch == "#" {
                level += 1
            } else {
                break
            }
        }
        guard level >= 1, level <= 6 else { return nil }

        let afterHashes = trimmed.dropFirst(level)
        guard afterHashes.isEmpty || afterHashes.hasPrefix(" ") else { return nil }

        let content = afterHashes.trimmingCharacters(in: .whitespaces)
        let cleaned = content.replacingOccurrences(
            of: "\\s*#+\\s*$",
            with: "",
            options: .regularExpression
        )
        let spans = MarkdownSpanParser.parse(cleaned)
        return .header(level: level, spans)
    }

    private static func parseCodeBlock(_ lines: [String]) -> MarkdownBlock {
        let firstLine = lines[0]
        let language: String? = {
            let lang = firstLine.dropFirst(3).trimmingCharacters(in: .whitespaces)
            return lang.isEmpty ? nil : lang
        }()

        var codeLines: [String] = []
        for line in lines.dropFirst() {
            if line.trimmingCharacters(in: .whitespaces).hasPrefix("```") {
                break
            }
            codeLines.append(line)
        }

        let code = codeLines.joined(separator: "\n")
        return .codeBlock(language: language, code: code)
    }

    private static func parseTable(_ lines: [String]) -> MarkdownBlock? {
        guard lines.count >= 2 else { return nil }

        let headerCells = parseTableRow(lines[0])
        guard !headerCells.isEmpty else { return nil }

        let separatorLine = lines[1].trimmingCharacters(in: .whitespaces)
        let separatorCells = separatorLine.split(separator: "|").map {
            $0.trimmingCharacters(in: .whitespaces)
        }
        let isSeparator = separatorCells.allSatisfy { cell in
            cell.allSatisfy { $0 == "-" || $0 == ":" } && !cell.isEmpty
        }
        guard isSeparator else { return nil }

        var rows: [[String]] = []
        for line in lines.dropFirst(2) {
            let cells = parseTableRow(line)
            if !cells.isEmpty {
                rows.append(cells)
            }
        }

        return .table(headers: headerCells, rows: rows)
    }

    private static func parseTableRow(_ line: String) -> [String] {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        var content = trimmed[trimmed.startIndex...]

        if content.hasPrefix("|") {
            content = content.dropFirst()
        }
        if content.hasSuffix("|") {
            content = content.dropLast()
        }

        return content.split(separator: "|", omittingEmptySubsequences: false).map {
            $0.trimmingCharacters(in: .whitespaces)
        }
    }

    static func isBulletListItem(_ line: String) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        return trimmed.hasPrefix("- ") || trimmed.hasPrefix("* ")
    }

    private static func parseBulletList(_ lines: [String]) -> MarkdownBlock {
        let items: [[MarkdownSpan]] = lines.compactMap { line in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("- ") {
                return MarkdownSpanParser.parse(String(trimmed.dropFirst(2)))
            } else if trimmed.hasPrefix("* ") {
                return MarkdownSpanParser.parse(String(trimmed.dropFirst(2)))
            }
            return nil
        }
        return .bulletList(items)
    }

    static func isNumberedListItem(_ line: String) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard let dotIdx = trimmed.firstIndex(of: ".") ?? trimmed.firstIndex(of: ")") else {
            return false
        }
        let prefix = trimmed[trimmed.startIndex..<dotIdx]
        return prefix.allSatisfy(\.isNumber) && !prefix.isEmpty
    }

    private static func parseNumberedList(_ lines: [String]) -> MarkdownBlock {
        let items: [[MarkdownSpan]] = lines.compactMap { line in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard let sepIdx = trimmed.firstIndex(where: { $0 == "." || $0 == ")" }),
                  trimmed[trimmed.startIndex..<sepIdx].allSatisfy(\.isNumber) else {
                return nil
            }
            let afterSep = trimmed.index(after: sepIdx)
            let content = trimmed[afterSep...].trimmingCharacters(in: .whitespaces)
            return MarkdownSpanParser.parse(content)
        }
        return .numberedList(items)
    }
}
