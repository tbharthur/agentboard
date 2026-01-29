// Agentboard/Views/Markdown/MarkdownBlockView.swift
import SwiftUI

/// Renders a single MarkdownBlock as a SwiftUI view.
struct MarkdownBlockView: View {
    let block: MarkdownBlock

    var body: some View {
        switch block {
        case .header(let level, let spans):
            headerView(level: level, spans: spans)

        case .paragraph(let spans):
            SpanTextView(spans: spans)
                .foregroundColor(.textPrimary)

        case .codeBlock(let language, let code):
            codeBlockView(language: language, code: code)

        case .table(let headers, let rows):
            tableView(headers: headers, rows: rows)

        case .bulletList(let items):
            VStack(alignment: .leading, spacing: 4) {
                ForEach(Array(items.enumerated()), id: \.offset) { _, spans in
                    HStack(alignment: .top, spacing: 6) {
                        Text("\u{2022}")
                            .foregroundColor(.textMuted)
                        SpanTextView(spans: spans)
                            .foregroundColor(.textPrimary)
                    }
                }
            }

        case .numberedList(let items):
            VStack(alignment: .leading, spacing: 4) {
                ForEach(Array(items.enumerated()), id: \.offset) { index, spans in
                    HStack(alignment: .top, spacing: 6) {
                        Text("\(index + 1).")
                            .foregroundColor(.textMuted)
                            .frame(minWidth: 20, alignment: .trailing)
                        SpanTextView(spans: spans)
                            .foregroundColor(.textPrimary)
                    }
                }
            }

        case .horizontalRule:
            Divider()
                .background(Color.border)
                .padding(.vertical, 4)
        }
    }

    // MARK: - Header

    @ViewBuilder
    private func headerView(level: Int, spans: [MarkdownSpan]) -> some View {
        SpanTextView(spans: spans)
            .font(fontForHeaderLevel(level))
            .foregroundColor(.textPrimary)
    }

    private func fontForHeaderLevel(_ level: Int) -> Font {
        switch level {
        case 1: return .title.bold()
        case 2: return .title2.bold()
        case 3: return .title3.bold()
        case 4: return .headline
        case 5: return .subheadline.bold()
        default: return .caption.bold()
        }
    }

    // MARK: - Code Block

    @ViewBuilder
    private func codeBlockView(language: String?, code: String) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            if let language, !language.isEmpty {
                Text(language)
                    .font(Fonts.jetBrainsMono(11))
                    .foregroundColor(.textMuted)
                    .padding(.horizontal, 12)
                    .padding(.top, 8)
                    .padding(.bottom, 4)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                Text(code)
                    .font(Fonts.jetBrainsMono(13))
                    .foregroundColor(.textPrimary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, language != nil ? 4 : 12)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.bgElevated)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.border, lineWidth: 0.5)
        )
    }

    // MARK: - Table (column-first layout from Happy)

    @ViewBuilder
    private func tableView(headers: [String], rows: [[String]]) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .top, spacing: 0) {
                ForEach(Array(headers.enumerated()), id: \.offset) { colIndex, header in
                    VStack(alignment: .leading, spacing: 0) {
                        // Header cell
                        Text(header)
                            .font(Fonts.jetBrainsMonoBold(13))
                            .foregroundColor(.textPrimary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.bgElevated)

                        Divider().background(Color.border)

                        // Data cells
                        ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                            let cell = colIndex < row.count ? row[colIndex] : ""
                            Text(cell)
                                .font(Fonts.jetBrainsMono(13))
                                .foregroundColor(.textPrimary)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .frame(minWidth: 80)

                    if colIndex < headers.count - 1 {
                        Divider().background(Color.border)
                    }
                }
            }
        }
        .background(Color.bgControl)
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(Color.border, lineWidth: 0.5)
        )
    }
}
