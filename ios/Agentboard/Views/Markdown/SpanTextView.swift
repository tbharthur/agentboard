// Agentboard/Views/Markdown/SpanTextView.swift
import SwiftUI

/// Renders [MarkdownSpan] as concatenated SwiftUI Text views.
struct SpanTextView: View {
    let spans: [MarkdownSpan]

    var body: some View {
        spans.reduce(Text("")) { result, span in
            result + textForSpan(span)
        }
    }

    private func textForSpan(_ span: MarkdownSpan) -> Text {
        switch span {
        case .text(let content):
            return Text(content)
        case .bold(let content):
            return Text(content).bold()
        case .italic(let content):
            return Text(content).italic()
        case .boldItalic(let content):
            return Text(content).bold().italic()
        case .code(let content):
            return Text(content)
                .font(Fonts.jetBrainsMono(13))
                .foregroundColor(.accent)
        case .link(let text, _):
            return Text(text)
                .foregroundColor(.accent)
                .underline()
        }
    }
}
