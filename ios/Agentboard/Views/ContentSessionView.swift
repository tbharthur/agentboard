// Agentboard/Views/ContentSessionView.swift
import SwiftUI

/// Session view that renders Claude Code output as native markdown.
/// Replaces SwiftTermViewRepresentable for control mode rendering.
struct ContentSessionView: View {
    let sessionId: String
    @Bindable var model: SessionContentModel

    @State private var autoScroll = true

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                MarkdownContentView(blocks: model.blocks)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)

                Color.clear
                    .frame(height: 1)
                    .id("bottom")
            }
            .background(Color.bgPrimary)
            .onChange(of: model.blocks.count) {
                if autoScroll {
                    withAnimation(.easeOut(duration: 0.15)) {
                        proxy.scrollTo("bottom", anchor: .bottom)
                    }
                }
            }
        }
    }
}
