//
//  ClipboardEntry.swift
//  Better
//
//  Created by Diego Rivera on 3/11/25.
//

import SwiftUI

struct ClipboardEntry: View {
    var entry: CopiedContent
    let isFrontMost: Bool
    let onChange: (UUID, String, Locale.Language?) -> Void
    let onPaste: () -> Void
    let onCopy: (String) -> Void
    
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
    @State private var showCopyConfirmation = false

    private var isCode: Bool { codeLanguage != nil }
    private var isImage: Bool { entry.contentType == .image }
    private var isEmoji: Bool { entry.contentType == .emoji }
    
    private let cornerRadius: CGFloat = 12
    private let thumbnailHeightScale: CGFloat = 1.08
    private let thumbnailWidthScale: CGFloat = 1.01

    init(
        entry: CopiedContent,
        isFrontMost: Bool,
        onChange: @escaping (UUID, String, Locale.Language?) -> Void,
        onPaste: @escaping () -> Void,
        onCopy: @escaping (String) -> Void,
        languageContext: LanguageContext
    ) {
        self.entry = entry
        self.isFrontMost = isFrontMost
        self.onChange = onChange
        self.onPaste = onPaste
        self.onCopy = onCopy
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
            if isImage {
                Button(action: {}) {
                    HStack {
                        Image(systemName: "photo")
                            .foregroundStyle(.white)
                            .padding(.leading, 4)
                        Text("Image")
                            .foregroundStyle(.blue)
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
            } else if isEmoji {
                EmptyView()
            } else if isCode {
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
            ZStack {
                ZStack(alignment: .topLeading) {
                    VisualEffectBlur(material: .contentBackground).opacity(0.6)
                    if isImage,
                       let imageData = entry.imageData,
                       let nsImage = NSImage(data: imageData) {
                        AdaptiveImageContainer(image: nsImage, cornerRadius: cornerRadius)
                    } else {
                        WritingToolsEditor(
                            text: $editedText,
                            controller: writingToolsController,
                            isEmoji: isEmoji,
                            codeLanguage: codeLanguage
                        )
                        .onChange(of: editedText) {
                            onChange(entry.id, editedText, translatedTo)
                        }
                    }
                }
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .strokeBorder(.quaternary)
                )
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                .padding(.horizontal, -6)
                .zIndex(0)
                if isImage,
                   let imageData = entry.imageData,
                   let nsImage = NSImage(data: imageData) {
                    GeometryReader { proxy in
                        let size = proxy.size
                        let imageSize = nsImage.size
                        let imageAspectRatio = imageSize.width / imageSize.height
                        let containerAspectRatio = size.width / size.height
                        let isCropped = abs(imageAspectRatio - containerAspectRatio) > 0.01
                        let scaleFactor = min(size.width / imageSize.width, size.height / imageSize.height)
                        let isUpscaled = scaleFactor > 1.2
                        if isCropped || isUpscaled {
                            let isPortrait = imageAspectRatio < 1.0
                            let thumbnailSize: CGSize = {
                                var calculatedSize: CGSize
                                if isPortrait {
                                    let height = size.height * thumbnailHeightScale
                                    let width = height * imageAspectRatio
                                    if width > size.width * thumbnailWidthScale {
                                        let constrainedWidth = size.width * thumbnailWidthScale
                                        let constrainedHeight = constrainedWidth / imageAspectRatio
                                        calculatedSize = CGSize(width: constrainedWidth, height: constrainedHeight)
                                    } else {
                                        calculatedSize = CGSize(width: width, height: height)
                                    }
                                } else {
                                    let width = size.width * thumbnailWidthScale
                                    let height = width / imageAspectRatio
                                    if height > size.height * thumbnailHeightScale {
                                        let constrainedHeight = size.height * thumbnailHeightScale
                                        let constrainedWidth = constrainedHeight * imageAspectRatio
                                        calculatedSize = CGSize(width: constrainedWidth, height: constrainedHeight)
                                    } else {
                                        calculatedSize = CGSize(width: width, height: height)
                                    }
                                }
                                return CGSize(
                                    width: min(calculatedSize.width, imageSize.width),
                                    height: min(calculatedSize.height, imageSize.height)
                                )
                            }()
                            Image(nsImage: nsImage)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: thumbnailSize.width, height: thumbnailSize.height)
                                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .stroke(Color(white: 0.85), lineWidth: 1)
                                )
                                .shadow(color: Color.black.opacity(0.6), radius: 10, x: 0, y: 4)
                                .frame(width: size.width, height: size.height)
                                .opacity(isFrontMost ? 1 : 0)
                                .scaleEffect(isFrontMost ? 1 : 0.9)
                                .animation(.spring(response: 0.9, dampingFraction: 0.8), value: isFrontMost)
                        }
                    }
                    .padding(.horizontal, -6)
                }
            }
            if !isCode && editedText != entry.original {
                Text("Original text")
                    .font(.subheadline)
                Text(entry.original)
                    .foregroundStyle(.secondary)
            }
            if isFrontMost {
                Spacer()
                buttonBar()
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onAppear {
            writingToolsController.onUnavailable = {
                showingWritingToolsHelp = true
            }
            if isFrontMost && !isImage {
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
            if newValue && !isImage {
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
    
    @ViewBuilder
    private func buttonBar() -> some View {
        HStack(spacing: 12) {
            Button(action: {
                NotificationCenter.default.post(name: .deleteFrontEntryRequested,
                                                object: entry.id)
            }) {
                HStack {
                    keyImage("command")
                    keyImage("delete.left")
                        .padding(.leading, -6)
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
            if !isImage && !isCode && editedText != entry.original {
                Button(action: {
                    editedText = entry.original
                    translatingTo = nil
                    translatedTo = nil
                }) {
                    HStack {
                        keyImage("command")
                        keyCharacter("U")
                            .padding(.leading, -6)
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
            if !isImage && !isCode && !isEmoji && entry.original == editedText {
                Button(action: {
                    writingToolsController.showWritingToolsPanel()
                }) {
                    HStack {
                        keyImage("command")
                        keyCharacter("R")
                            .padding(.leading, -6)
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
                .help("Rewrite this copy")
            }
            if !isImage && (isCode || entry.original != editedText) {
                Button(action: {
                    onCopy(editedText)
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        showCopyConfirmation = true
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        withAnimation(.easeOut(duration: 0.2)) {
                            showCopyConfirmation = false
                        }
                    }
                }) {
                    HStack {
                        keyImage("command")
                        keyCharacter("C")
                            .padding(.leading, -6)
                        if showCopyConfirmation {
                            Image(systemName: "checkmark")
                                .font(.subheadline)
                                .padding(.trailing, 5)
                                .transition(.scale.combined(with: .opacity))
                        } else {
                            Image(systemName: "document.on.document")
                                .font(.subheadline)
                                .foregroundStyle(.primary)
                                .padding(.trailing, 3)
                                .transition(.scale.combined(with: .opacity))
                        }
                    }
                    .padding(3)
                    .background(
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .fill(.secondary.opacity(0.6))
                    )
                }
                .keyboardShortcut("c", modifiers: .command)
                .help("Copy rewritten text to the clipboard")
            }
            if isImage {
                Button(action: {
                    if let imageData = entry.imageData {
                        let pasteboard = NSPasteboard.general
                        pasteboard.clearContents()
                        pasteboard.setData(imageData, forType: .tiff)
                    }
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        showCopyConfirmation = true
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        withAnimation(.easeOut(duration: 0.2)) {
                            showCopyConfirmation = false
                        }
                    }
                }) {
                    HStack {
                        keyImage("command")
                        keyCharacter("C")
                            .padding(.leading, -6)
                        if showCopyConfirmation {
                            Image(systemName: "checkmark")
                                .font(.subheadline)
                                .padding(.trailing, 5)
                                .transition(.scale.combined(with: .opacity))
                        } else {
                            Image(systemName: "photo.on.rectangle")
                                .font(.subheadline)
                                .foregroundStyle(.primary)
                                .padding(.trailing, 3)
                                .transition(.scale.combined(with: .opacity))
                        }
                    }
                    .padding(3)
                    .background(
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .fill(.secondary.opacity(0.6))
                    )
                }
                .keyboardShortcut("c", modifiers: .command)
                .help("Copy image to the clipboard")
            }
            Button(action: onPaste) {
                HStack {
                    keyImage("return")
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
    
    @ViewBuilder
    private func keyImage(_ systemName: String) -> some View {
        HStack {
            Image(systemName: systemName)
        }
        .padding(4)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(.ultraThickMaterial)
        )
    }
    
    @ViewBuilder
    private func keyCharacter(_ character: String) -> some View {
        HStack {
            Text(character)
                .font(.callout)
                .padding(.horizontal, 1)
                .padding(.vertical, -3)
        }
        .padding(4)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(.ultraThickMaterial)
        )
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

struct VisualEffectBlur: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode

    init(material: NSVisualEffectView.Material = .windowBackground,
         blendingMode: NSVisualEffectView.BlendingMode = .behindWindow) {
        self.material = material
        self.blendingMode = blendingMode
    }

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
        nsView.state = .active
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
