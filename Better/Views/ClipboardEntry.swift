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
    let onPaste: () -> Void
    
    @Environment(\.translator) private var translator: Translator?
    @ObservedObject var languageContext: LanguageContext
    @StateObject private var writingToolsController = WritingToolsController()

    @State private var editedText: String
    @State private var textLanguage: Locale.Language?
    @State private var translatedTo: Locale.Language?
    @State private var translatingTo: Locale.Language?
    @State private var isTranslationAvailable = false
    @State private var showingWritingToolsHelp = false
    @State private var showingTranslationHelp = false
    @State private var codeLanguage: ProgrammingLanguage? = nil

    private var isCode: Bool { codeLanguage != nil }
    private let cornerRadius: CGFloat = 12

    init(
        entry: CopiedText,
        isFrontMost: Bool,
        onChange: @escaping (UUID, String, Locale.Language?) -> Void,
        onPaste: @escaping () -> Void,
        languageContext: LanguageContext
    ) {
        self.entry = entry
        self.isFrontMost = isFrontMost
        self.onChange = onChange
        self.onPaste = onPaste
        self.languageContext = languageContext
        _editedText = State(initialValue: entry.rewritten ?? entry.original)
        _textLanguage = State(initialValue: entry.translatedTo)
        _translatedTo = State(initialValue: entry.translatedTo)
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
            if isCode {
                Button(action: {}) {
                    HStack {
                        Image(systemName: "curlybraces")
                            .bold()
                            .monospaced()
                            .foregroundStyle(.white)
                            .padding(.leading, 4)
                        Text(codeLanguage?.name ?? "Code")
                            .foregroundStyle(codeLanguage?.color?.adaptiveForAppearance() ?? .white)
                            .padding(.trailing, 8)
                    }
                    .padding(.vertical, 4)
                    .padding(.horizontal, 3)
                    .background(
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .fill(Color.secondary.opacity(0.3))
                    )
                }
                .buttonStyle(.plain)
            } else if languageContext.languages.isEmpty || !isTranslationAvailable {
                Button(action: {
                    showingTranslationHelp = true
                }) {
                    HStack {
                        Image(systemName: "translate")
                            .font(.system(size: 15))
                            .padding(.leading, 9)
                            .padding(.bottom, 4)
                            .padding(.top, 6)
                        Image(systemName: "info.circle")
                            .font(.system(size: 15))
                            .padding(.trailing, 9)
                    }
                    .background(
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .fill(.secondary.opacity(0.3))
                    )
                    .scaleEffect(0.9)
                }
                .buttonStyle(.plain)
                .help("Add translation languages")
                .popover(isPresented: $showingTranslationHelp, arrowEdge: .top) {
                    TranslationHelpPopover(onRefresh: {
                        languageContext.refreshLanguages()
                        showingTranslationHelp = false
                    })
                    .background(WindowLevelModifier())
                }
            } else {
                ForEach(Array(languageContext.languages.enumerated()), id: \.element) { item in
                    LanguageButton(
                        language: item.element,
                        index: languageContext.languages.firstIndex(of: item.element) ?? 0
                    )
                }
            }
        }
    }
    
    @ViewBuilder
    private func LanguageButton(
        language: Locale.Language,
        index: Int
    ) -> some View {
        let locale = Locale(identifier: language.maximalIdentifier)
        let lang = translatedTo ?? textLanguage
        let isCurrent = language.languageCode == lang?.languageCode
        Button(action: {
            $translatingTo.wrappedValue = language
            NotificationCenter.default.post(name: .translationRequested,
                                            object: language)
        }) {
            HStack {
                HStack {
                    if isCurrent {
                        Image(systemName: "checkmark")
                            .bold()
                            .font(.system(size: 15))
                            .padding(.leading, 4)
                            .padding(.trailing, 1)
                    } else if $translatingTo.wrappedValue == language {
                        ProgressView()
                            .frame(width: 16, height: 16)
                            .scaleEffect(0.6)
                            .padding(.horizontal, 4)
                    } else {
                        Image(systemName: "command")
                        Text("\(index + 1)")
                            .padding(.leading, -5)
                    }
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
        .disabled(isCurrent)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Copied \(formattedDate)")
                    .font(.subheadline)
                Spacer()
                if isFrontMost {
                    LanguageBar()
                        .padding(.top, -6)
                        .padding(.horizontal, -6)
                }
            }
            ZStack(alignment: .topLeading) {
                WritingToolsEditor.blurredBackground(cornerRadius: cornerRadius)
                WritingToolsEditor(
                    text: $editedText,
                    controller: writingToolsController,
                    codeLanguage: codeLanguage
                )
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
                            translatingTo = nil
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
                    if !isCode {
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
                    }
                    Button(action: onPaste) {
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
                let isAvailable = await translator.isAvailable(for: editedText)
                let codeLanguage = CodeDetector.detectCode(in: entry.original)
                await MainActor.run {
                    self.textLanguage = language
                    self.isTranslationAvailable = isAvailable
                    self.codeLanguage = codeLanguage
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

private struct WindowLevelModifier: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            if let window = view.window {
                window.level = .modalPanel
            }
        }
        return view
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            if let window = nsView.window {
                window.level = .modalPanel
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

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
    
    var components: (red: Double, green: Double, blue: Double, opacity: Double)? {
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var opacity: CGFloat = 0
        guard let rgbColor = NSColor(self).usingColorSpace(.sRGB) else {
            return nil
        }
        rgbColor.getRed(&red, green: &green, blue: &blue, alpha: &opacity)
        return (Double(red), Double(green), Double(blue), Double(opacity))
    }
    
    func adaptiveForAppearance() -> Color {
        guard let comps = components else {
            return self
        }
        return Color(
            light: Color(
                red: comps.red * 0.7,
                green: comps.green * 0.7,
                blue: comps.blue * 0.7
            ),
            dark: self
        )
    }
    
    init(light: Color, dark: Color) {
        self.init(nsColor: NSColor(name: nil) { appearance in
            if appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua {
                return NSColor(dark)
            } else {
                return NSColor(light)
            }
        })
    }
}
