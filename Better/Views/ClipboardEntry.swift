//
//  ClipboardEntry.swift
//  Better
//
//  Created by Diego Rivera on 3/11/25.
//

import SwiftUI

struct ClipboardEntry: View {
    let entry: TransformedText
    let isFrontMost: Bool

    @State private var editedText: String
    @StateObject private var writingToolsController = WritingToolsController()

    init(entry: TransformedText, isFrontMost: Bool) {
        self.entry = entry
        self.isFrontMost = isFrontMost
        _editedText = State(initialValue: entry.variants.first?.value ?? entry.original)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            WritingToolsEditor(text: $editedText, controller: writingToolsController)
                .frame(minHeight: 88)
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(.quaternary)
                )
            Text(entry.original)
                .font(.caption)
                .foregroundStyle(.secondary)
            if isFrontMost {
                Spacer()
                HStack(spacing: 12) {
                    Spacer()
                    Button(action: {
                        writingToolsController.showWritingToolsPanel()
                    }) {
                        HStack {
                            HStack {
                                Image(systemName: "command")
                                Text("R")
                                    .font(.callout)
                                    .padding(.leading, -5)
                                    .padding(.trailing, 1)
                                    .padding(.vertical, -3)
                            }
                            .padding(4)
                            .background(
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .fill(.ultraThickMaterial)
                            )
                            Text("Rewrite")
                                .font(.body)
                            Image(systemName: "sparkles")
                                .font(.subheadline)
                                .foregroundStyle(.primary)
                                .padding(.trailing, 3)
                        }
                        .padding(3)
                        .background(
                            RoundedRectangle(cornerRadius: 7, style: .continuous)
                                .fill(.secondary.opacity(0.6))
                        )
                    }
                    .keyboardShortcut("r", modifiers: .command)
                    Button(action: {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(entry.original, forType: .string)
                    }) {
                        HStack {
                            Image(systemName: "return")
                                .padding(4)
                                .background(
                                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                                        .fill(.ultraThickMaterial)
                                )
                            Text("Paste")
                                .font(.body)
                                .padding(.trailing, 8)
                        }
                        .padding(3)
                        .background(
                            RoundedRectangle(cornerRadius: 7, style: .continuous)
                                .fill(.secondary.opacity(0.6))
                        )
                    }
                    .keyboardShortcut(.return)
                }
                .buttonStyle(.borderless)
                .font(.caption)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onAppear {
            if isFrontMost {
                writingToolsController.focusTextView()
            }
        }
        .onChange(of: isFrontMost) { _, newValue in
            if newValue {
                writingToolsController.focusTextView()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .rewriteFrontEntryRequested)) { notification in
            guard isFrontMost,
                  let targetID = notification.object as? UUID,
                  targetID == entry.id else {
                return
            }
            writingToolsController.showWritingToolsPanel()
        }
    }
}
