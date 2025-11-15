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
    let onChange: (UUID, String, Locale.Language?) -> Void
    
    @Environment(\.translator) private var translator: Translator?
    @ObservedObject var languageContext: LanguageContext

    @State private var editedText: String
    @State private var translatedTo: Locale.Language?
    @State private var textLanguage: Locale.Language?
    @State private var showingWritingToolsHelp = false
    
    @StateObject private var writingToolsController = WritingToolsController()

    private let cornerRadius: CGFloat = 12

    init(
        entry: CopiedText,
        isFrontMost: Bool,
        onChange: @escaping (UUID, String, Locale.Language?) -> Void,
        languageContext: LanguageContext
    ) {
        self.entry = entry
        self.isFrontMost = isFrontMost
        self.onChange = onChange
        self.languageContext = languageContext
        _editedText = State(initialValue: entry.rewritten ?? entry.original)
        _translatedTo = State(initialValue: entry.translatedTo)
        _textLanguage = State(initialValue: entry.translatedTo)
    }
        
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
    
    @ViewBuilder
    private func LanguageBar() -> some View {
        HStack(spacing: 2) {
            if let itemLanguage = translatedTo ?? textLanguage,
               languageContext.languages.contains(itemLanguage) {
                let locale = Locale(identifier: itemLanguage.maximalIdentifier)
                HStack {
                    LanguageFlag(locale: locale, diameter: 24)
                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                        .scaleEffect(0.9)
                    Divider()
                        .frame(height: 24)
                        .foregroundStyle(.primary)
                        .padding(.trailing, 5)
                }
            }
            let languages = languageContext.languages.filter({ $0 != translatedTo })
            ForEach(Array(languages.enumerated()), id: \.element) { item in
                let index = item.offset
                let language = item.element
                let locale = Locale(identifier: language.maximalIdentifier)
                Button(action: {
                    NotificationCenter.default.post(name: .translationRequested,
                                                    object: language)
                }) {
                    HStack {
                        HStack {
                            Image(systemName: "command")
                            Text("\(index + 1)")
                                .padding(.leading, -5)
                        }
                        .padding(.leading, 6)
                        .padding(.vertical, 5)
                        .padding(.trailing, 0)
                        LanguageFlag(locale: locale, diameter: 24)
                            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                            .padding(0)
                    }
                    .background(
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .fill(.secondary.opacity(0.3))
                    )
                    .scaleEffect(0.9)
                }
                .buttonStyle(.plain)
                .keyboardShortcut(KeyEquivalent(Character("\((index % 9) + 1)")), modifiers: .command)
                .help("Translate into \(locale.description)")
            }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Copied \(formattedDate)")
                    .font(.caption2)
                Spacer()
                if isFrontMost {
                    LanguageBar()
                        .padding(.top, -6)
                        .padding(.horizontal, -6)
                }
            }
            ZStack(alignment: .topLeading) {
                WritingToolsEditor.blurredBackground(cornerRadius: cornerRadius)
                WritingToolsEditor(text: $editedText, controller: writingToolsController)
                    .onChange(of: editedText) {
                        onChange(entry.id, editedText, translatedTo)
                    }
            }
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(.quaternary)
            )
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .padding(.horizontal, -6)
            if editedText != entry.original {
                Text("Original text")
                    .font(.subheadline)
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
                    .help("Delete this copy")
                    Spacer()
                    if editedText != entry.original {
                        Button(action: {
                            editedText = entry.original
                            translatedTo = nil
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
                        .help("Back to the original copy")
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
                    .help("Rewrite this copy")
                    Button(action: {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(editedText, forType: .string)
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
                    .help("Paste this copy")
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
            Task {
                guard let translator else { return }
                let language = await translator.detectLanguage(for: editedText)
                await MainActor.run {
                    self.textLanguage = language
                }
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
        .onReceive(NotificationCenter.default.publisher(for: .translationRequested)) { notification in
            guard isFrontMost else { return }
            if let language = notification.object as? Locale.Language {
                translate(to: language)
            }
        }
        .sheet(isPresented: $showingWritingToolsHelp) {
            AIHelpSheet {
                showingWritingToolsHelp = false
            }
        }
    }
}

private extension ClipboardEntry {
    func translate(to language: Locale.Language) {
        guard let translator else {
            return
        }
        let source = editedText
        Task {
            await translator.reconfigureIfNeeded(target: language)
            do {
                let translation = try await translator.translate(source)
                await MainActor.run {
                    translatedTo = language
                    editedText = translation
                }
            } catch {
                NSLog("Translation failed: \(error)")
            }
        }
    }
}
