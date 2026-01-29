// Agentboard/Markdown/MarkdownParser.swift
import Foundation

/// Entry point for parsing markdown text into structured blocks.
/// Ported from Happy's parseMarkdown.ts
struct MarkdownParser {

    /// Parse a markdown string into an array of blocks.
    static func parse(_ text: String) -> [MarkdownBlock] {
        let lines = text.components(separatedBy: "\n")
        var blocks: [MarkdownBlock] = []
        var index = 0

        while index < lines.count {
            let line = lines[index]

            // Skip empty lines
            if line.trimmingCharacters(in: .whitespaces).isEmpty {
                index += 1
                continue
            }

            // Fenced code block
            if line.trimmingCharacters(in: .whitespaces).hasPrefix("```") {
                var blockLines = [line]
                index += 1
                while index < lines.count {
                    let current = lines[index]
                    blockLines.append(current)
                    index += 1
                    if current.trimmingCharacters(in: .whitespaces) == "```" {
                        break
                    }
                }
                if let block = MarkdownBlockParser.parseBlock(blockLines) {
                    blocks.append(block)
                }
                continue
            }

            // Table
            if line.contains("|") {
                var tableLines = [line]
                index += 1
                while index < lines.count {
                    let current = lines[index]
                    if current.contains("|") {
                        tableLines.append(current)
                        index += 1
                    } else {
                        break
                    }
                }
                if let block = MarkdownBlockParser.parseBlock(tableLines) {
                    blocks.append(block)
                } else {
                    for tl in tableLines {
                        let spans = MarkdownSpanParser.parse(tl)
                        blocks.append(.paragraph(spans))
                    }
                }
                continue
            }

            // Bullet list
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("- ") || trimmed.hasPrefix("* ") {
                var listLines = [line]
                index += 1
                while index < lines.count {
                    let current = lines[index].trimmingCharacters(in: .whitespaces)
                    if current.hasPrefix("- ") || current.hasPrefix("* ") {
                        listLines.append(lines[index])
                        index += 1
                    } else {
                        break
                    }
                }
                if let block = MarkdownBlockParser.parseBlock(listLines) {
                    blocks.append(block)
                }
                continue
            }

            // Numbered list
            if MarkdownBlockParser.isNumberedListItem(trimmed) {
                var listLines = [line]
                index += 1
                while index < lines.count {
                    let current = lines[index].trimmingCharacters(in: .whitespaces)
                    if MarkdownBlockParser.isNumberedListItem(current) {
                        listLines.append(lines[index])
                        index += 1
                    } else {
                        break
                    }
                }
                if let block = MarkdownBlockParser.parseBlock(listLines) {
                    blocks.append(block)
                }
                continue
            }

            // Single-line blocks: header, horizontal rule, paragraph
            if let block = MarkdownBlockParser.parseBlock([line]) {
                blocks.append(block)
            }
            index += 1
        }

        return blocks
    }
}
