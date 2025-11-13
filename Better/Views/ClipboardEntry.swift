//
//  ClipboardEntry.swift
//  Better
//
//  Created by Diego Rivera on 3/11/25.
//

import SwiftUI

struct ClipboardEntry: View {
    var entry: CopiedText
    let isFrontMost: Bool
    let onChange: (UUID, String) -> Void

    @State private var editedText: String
    @State private var showingWritingToolsHelp = false
    
    @StateObject private var writingToolsController = WritingToolsController()

    init(entry: CopiedText, isFrontMost: Bool, onChange: @escaping (UUID, String) -> Void) {
        self.entry = entry
        self.isFrontMost = isFrontMost
        self.onChange = onChange
        _editedText = State(initialValue: entry.rewritten ?? entry.original)
    }
    
    private let cornerRadius: CGFloat = 12
    
    var formattedDate: String {
        let calendar = Calendar.current
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        if calendar.isDateInToday(entry.date) {
            formatter.dateFormat = "HH:mm"
            return formatter.string(from: entry.date)
        } else if calendar.isDateInYesterday(entry.date) {
            formatter.dateFormat = "HH:mm"
            return "\(String(localized: "yesterday")), \(formatter.string(from: entry.date))"
        } else {
            formatter.setLocalizedDateFormatFromTemplate("MMM d")
            var dateString = formatter.string(from: entry.date)
            if formatter.locale.identifier.hasPrefix("en") {
                let day = calendar.component(.day, from: entry.date)
                let formatterOrdinal = NumberFormatter()
                formatterOrdinal.numberStyle = .ordinal
                if let dayOrdinal = formatterOrdinal.string(from: NSNumber(value: day)) {
                    dateString = dateString.replacingOccurrences(of: "\\d+", with: dayOrdinal, options: .regularExpression)
                }
            }
            return dateString
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Copied \(formattedDate)")
                .font(.caption2)
            ZStack(alignment: .topLeading) {
                WritingToolsEditor.blurredBackground(cornerRadius: cornerRadius)
                WritingToolsEditor(text: $editedText, controller: writingToolsController)
                    .onChange(of: editedText) {
                        onChange(entry.id, editedText)
                    }
            }
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(.quaternary)
            )
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            if editedText != entry.original {
                Text("Original text")
                    .font(.caption2)
                Text(entry.original)
                    .foregroundStyle(.secondary)
            }
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
                    if editedText != entry.original {
                        Button(action: {
                            editedText = entry.original
                        }) {
                            HStack {
                                HStack {
                                    Image(systemName: "command")
                                    Text("U")
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
                                Text("Back to original")
                                    .font(.body)
                                    .padding(.trailing, 8)
                            }
                            .padding(3)
                            .background(
                                RoundedRectangle(cornerRadius: 7, style: .continuous)
                                    .fill(.secondary.opacity(0.6))
                            )
                        }
                        .keyboardShortcut("u", modifiers: .command)
                    }
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
                            if entry.original == editedText {
                                Text("Rewrite")
                                    .font(.body)
                            }
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
                        NSPasteboard.general.setString(entry.rewritten ?? entry.original,
                                                       forType: .string)
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
