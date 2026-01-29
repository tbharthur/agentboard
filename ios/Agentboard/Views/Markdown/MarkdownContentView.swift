// Agentboard/Views/Markdown/MarkdownContentView.swift
import SwiftUI

/// Renders an array of MarkdownBlocks as a vertical stack of SwiftUI views.
struct MarkdownContentView: View {
    let blocks: [MarkdownBlock]

    var body: some View {
        LazyVStack(alignment: .leading, spacing: 12) {
            ForEach(Array(blocks.enumerated()), id: \.offset) { _, block in
                MarkdownBlockView(block: block)
            }
        }
    }
}
