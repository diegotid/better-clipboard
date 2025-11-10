//
//  ClipboardEntry.swift
//  Better
//
//  Created by Diego Rivera on 3/11/25.
//

import SwiftUI

struct ClipboardEntry: View {
    let entry: CopiedText
    let isFrontMost: Bool

    @State private var editedText: String
    @State private var showingWritingToolsHelp = false
    
    @StateObject private var writingToolsController = WritingToolsController()

    init(entry: CopiedText, isFrontMost: Bool) {
        self.entry = entry
        self.isFrontMost = isFrontMost
        _editedText = State(initialValue: entry.original)
    }
    
    let cornerRadius: CGFloat = 12

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ZStack(alignment: .topLeading) {
                WritingToolsEditor.blurredBackground(cornerRadius: cornerRadius)
                WritingToolsEditor(text: $editedText, controller: writingToolsController)
                    .frame(minHeight: 160)
            }
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(.quaternary)
            )
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            Text(entry.original)
                .font(.caption)
                .foregroundStyle(.secondary)
            if isFrontMost {
                Spacer()
                HStack(spacing: 12) {
                    Button(action: {
                        NotificationCenter.default.post(name: .deleteFrontEntryRequested,
                                                        object: entry.id)
                    }) {
                        HStack {
                            HStack {
                                Image(systemName: "command")
                                Image(systemName: "delete.left")
                                    .padding(.leading, -5)
                            }
                            .padding(4)
                            .background(
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .fill(.ultraThickMaterial)
                            )
                            Text("Delete")
                                .font(.body)
                                .foregroundStyle(.red)
                                .padding(.trailing, 8)
                        }
                        .padding(3)
                        .background(
                            RoundedRectangle(cornerRadius: 7, style: .continuous)
                                .fill(.secondary.opacity(0.6))
                        )
                    }
                    .keyboardShortcut(.delete, modifiers: .command)
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
            writingToolsController.onUnavailable = {
                showingWritingToolsHelp = true
            }
            if isFrontMost {
                writingToolsController.focusTextView()
            }
        }
        .onDisappear {
            writingToolsController.onUnavailable = nil
        }
        .onChange(of: isFrontMost) { _, newValue in
            if newValue {
                writingToolsController.focusTextView()
            } else {
                writingToolsController.scheduleDismiss()
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
        .sheet(isPresented: $showingWritingToolsHelp) {
            AppleIntelligenceHelpSheet {
                showingWritingToolsHelp = false
            }
        }
    }
}
