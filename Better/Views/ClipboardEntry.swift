//
//  ClipboardEntry.swift
//  Better
//
//  Created by Diego Rivera on 3/11/25.
//

import SwiftUI
internal import AppKit

struct ClipboardEntry: View {
    var entry: CopiedContent
    let isFrontMost: Bool
    let canPin: Bool
    let onChange: (UUID, String, Locale.Language?) -> Void
    let onPaste: () -> Void
    let onCopy: (String) -> Void
    
    @ObservedObject var languageContext: LanguageContext
    @Environment(\.translator) private var translator: Translator?
    @StateObject private var writingToolsController = WritingToolsController()
    
    @State private var editedText: String
    @State private var textLanguage: Locale.Language?
    @State private var translatedTo: Locale.Language?
    @State private var translatingTo: Locale.Language?
    @State private var isTranslationAvailable = false
    @State private var showingWritingToolsHelp = false
    @State private var showingTranslationHelp = false
    @State private var showCopyConfirmation = false
    @State private var localIsPinned: Bool
    @State private var preparedImage: NSImage?
    
    private var isCode: Bool { entry.codeLanguage != nil }
    private var isImage: Bool { entry.contentType == .image }
    private var isLink: Bool { entry.contentType == .link }
    private var isEmoji: Bool { entry.contentType == .emoji }
    private var isTranslationSupported: Bool {
        if #available(macOS 26.0, *) {
            return true
        }
        return false
    }
    
    private let cornerRadius: CGFloat = 12
    private let thumbnailHeightScale: CGFloat = 1.08
    private let thumbnailWidthScale: CGFloat = 1.01
    
    init(
        entry: CopiedContent,
        isFrontMost: Bool,
        canPin: Bool = true,
        onChange: @escaping (UUID, String, Locale.Language?) -> Void,
        onPaste: @escaping () -> Void,
        onCopy: @escaping (String) -> Void,
        languageContext: LanguageContext
    ) {
        self.entry = entry
        self.isFrontMost = isFrontMost
        self.canPin = canPin
        self.onChange = onChange
        self.onPaste = onPaste
        self.onCopy = onCopy
        self.languageContext = languageContext
        _editedText = State(initialValue: entry.rewritten ?? entry.original)
        _textLanguage = State(initialValue: entry.translatedTo)
        _translatedTo = State(initialValue: entry.translatedTo)
        _localIsPinned = State(initialValue: entry.isPinned)
        _preparedImage = State(initialValue: nil)
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
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                pinButton()
                    .padding(.trailing, 6)
                Text(localIsPinned ? "Pinned" : "Copied \(formattedDate)")
                Spacer()
                if isFrontMost {
                    languageBar()
                        .padding(.top, -6)
                        .padding(.horizontal, -6)
                }
            }
            ZStack {
                ZStack(alignment: .topLeading) {
                    VisualEffectBlur(material: .contentBackground).opacity(0.6)
                    if isImage {
                        if let nsImage = preparedImage {
                            AdaptiveImageContainer(image: nsImage, cornerRadius: cornerRadius)
                        } else {
                            ProgressView()
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                .background(Color.secondary.opacity(0.08))
                                .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                        }
                    } else if isLink, let url = URL(string: entry.original) {
                        LinkCard(url: url, metatags: entry.linkMetatags)
                            .frame(maxHeight: .infinity)
                    } else {
                        WritingToolsEditor(
                            text: $editedText,
                            controller: writingToolsController,
                            isEmoji: isEmoji,
                            codeLanguage: entry.codeLanguage
                        )
                        .onChange(of: editedText) {
                            onChange(entry.id, editedText, translatedTo)
                        }
                    }
                }
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .strokeBorder(localIsPinned
                                      ? Color.accentColor.opacity(0.3)
                                      : Color(NSColor.quaternaryLabelColor))
                )
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                .padding(.horizontal, -2)
                .zIndex(0)
                if isImage {
                    GeometryReader { proxy in
                        let size = proxy.size
                        if let nsImage = preparedImage {
                            let imageSize = nsImage.size
                            let imageAspectRatio = imageSize.width / imageSize.height
                            let containerAspectRatio = size.width / size.height
                            let isCropped = abs(imageAspectRatio - containerAspectRatio) > 0.01
                            let scaleFactor = min(size.width / imageSize.width, size.height / imageSize.height)
                            let isUpscaled = scaleFactor > 1.2
                            if isCropped || isUpscaled {
                                let thumbnailSize = calculateThumbnailSize(
                                    imageSize: imageSize,
                                    containerSize: size,
                                    imageAspectRatio: imageAspectRatio
                                )
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
                    }
                    .padding(.horizontal, -2)
                }
            }
            if !isCode && editedText != entry.original {
                Text("Original text")
                Text(entry.original)
                    .foregroundStyle(.secondary)
                Spacer()
            }
            if isFrontMost {
                buttonBar()
                    .padding(.top, 8)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onAppear {
            writingToolsController.onUnavailable = {
                showingWritingToolsHelp = true
            }
            if isFrontMost && !isImage {
                writingToolsController.focusTextView()
            }
            if isImage, let imageData = entry.imageData {
                Task {
                    let decoded = await decodeImage(data: imageData)
                    await MainActor.run { self.preparedImage = decoded }
                }
            }
            Task {
                guard isTranslationSupported, let translator else { return }
                let language = await translator.detectLanguage(for: editedText)
                let isAvailable = await translator.isAvailable(for: editedText)
                await MainActor.run {
                    self.textLanguage = language
                    self.isTranslationAvailable = isAvailable
                }
            }
        }
        .onDisappear {
            writingToolsController.onUnavailable = nil
        }
        .onChange(of: entry.isPinned) { _, newValue in
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                localIsPinned = newValue
            }
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
            guard isFrontMost, isTranslationSupported else { return }
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
    func pinButton() -> some View {
        Button(action: {
            if !canPin && !localIsPinned {
                NotificationCenter.default.post(name: .showUpgradeAlertRequested, object: nil)
                return
            }
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                localIsPinned.toggle()
            }
            NotificationCenter.default.post(name: .toggleEntryPinnedRequested,
                                            object: entry.id)
        }) {
            HStack {
                shortcut(mods: ["command"], key: "P")
                Image(systemName: localIsPinned ? "pin.slash.fill" : "pin")
                    .font(.subheadline)
                    .foregroundStyle(localIsPinned ? .white : (canPin ? .primary : .secondary))
                    .padding(.trailing, 8)
            }
            .buttonPillStyle(localIsPinned: localIsPinned, canPin: canPin)
        }
        .buttonStyle(.plain)
        .keyboardShortcut("p", modifiers: .command)
        .help(localIsPinned ? "Unpin" : (canPin ? "Pin" : "Upgrade to pin more"))
    }
    
    @ViewBuilder
    func languageBar() -> some View {
        HStack(spacing: 2) {
            if isImage {
                HStack {
                    Image(systemName: "photo")
                        .foregroundStyle(.white)
                        .padding(.leading, 4)
                    Text("Image")
                        .foregroundStyle(.blue)
                }
                .padding(.vertical, 4)
                .padding(.trailing, 5)
            } else if isEmoji || isLink {
                EmptyView()
            } else if isCode {
                HStack {
                    Image(systemName: "ellipsis.curlybraces")
                        .bold()
                        .monospaced()
                        .foregroundStyle(.secondary)
                        .padding(.leading, 4)
                    Text(entry.codeLanguage?.name ?? "Code")
                        .foregroundStyle(entry.codeLanguage?.color?.adaptiveForAppearance() ?? .primary)
                }
                .padding(.vertical, 4)
                .padding(.trailing, 5)
            } else if isTranslationSupported == false {
                EmptyView()
            } else if languageContext.languages.isEmpty || !isTranslationAvailable {
                Button(action: {
                    showingTranslationHelp = true
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "info.circle")
                            .foregroundStyle(.secondary)
                        Image(systemName: "translate")
                    }
                    .padding(.vertical, 2.5)
                    .padding(.horizontal, 6)
                    .buttonPillStyle()
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
                    languageButton(
                        language: item.element,
                        index: languageContext.languages.firstIndex(of: item.element) ?? 0
                    )
                }
            }
        }
        .padding(.top, 7)
        .padding(.trailing, 7)
    }
    
    @ViewBuilder
    func languageButton(
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
                            .padding(.leading, 6)
                            .padding(.trailing, 2)
                    } else if $translatingTo.wrappedValue == language {
                        ProgressView()
                            .frame(width: 16, height: 16)
                            .scaleEffect(0.6)
                            .padding(.horizontal, 4)
                            .padding(.leading, 4)
                    } else {
                        Image(systemName: "command")
                            .padding(.leading, 2)
                        Text("\(index + 1)")
                            .padding(.leading, -5)
                    }
                }
                .padding(.vertical, 3)
                .padding(.horizontal, 8)
                LanguageFlag(locale: locale, diameter: 31.5)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .padding(0)
                    .padding(.leading, -6)
            }
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Color.secondary.opacity(0.2))
                    )
            )
            .scaleEffect(0.9)
        }
        .buttonStyle(.plain)
        .keyboardShortcut(KeyEquivalent(Character("\((index % 9) + 1)")), modifiers: .command)
        .help("Translate into \(locale.description)")
        .disabled(isCurrent)
    }
    
    @ViewBuilder
    func buttonBar() -> some View {
        HStack(spacing: 12) {
            Button(action: {
                NotificationCenter.default.post(name: .deleteFrontEntryRequested,
                                                object: entry.id)
            }) {
                HStack {
                    shortcut(mods: ["command", "delete.left"])
                    Image(systemName: "trash")
                        .font(.subheadline)
                        .foregroundStyle(.primary)
                        .padding(.trailing, 8)
                        .transition(.scale.combined(with: .opacity))
                }
                .buttonPillStyle()
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
                        shortcut(mods: ["command"], key: "U")
                        Text("Back to original")
                            .font(.body)
                            .padding(.trailing, 8)
                    }
                    .buttonPillStyle()
                }
                .keyboardShortcut("u", modifiers: .command)
                .help("Back to the original copy")
            }
            if !isImage && !isLink && !isCode && !isEmoji && entry.original == editedText {
                Button(action: {
                    writingToolsController.showWritingToolsPanel()
                }) {
                    HStack {
                        shortcut(mods: ["command"], key: "R")
                        Text("Rewrite")
                            .font(.body)
                        Image(systemName: "sparkles")
                            .font(.subheadline)
                            .foregroundStyle(.primary)
                            .padding(.trailing, 8)
                    }
                    .buttonPillStyle()
                }
                .keyboardShortcut("r", modifiers: .command)
                .help("Rewrite this copy")
            }
            if isLink {
                Button(action: {
                    if let url = linkDestination() {
                        NSWorkspace.shared.open(url)
                    }
                }) {
                    HStack {
                        shortcut(mods: ["command"], key: "W")
                        Text("Follow link")
                            .font(.body)
                            .padding(.trailing, 8)
                    }
                    .buttonPillStyle()
                }
                .keyboardShortcut("w", modifiers: .command)
                .help("Follow this link")
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
                        shortcut(mods: ["command"], key: "C")
                        if showCopyConfirmation {
                            Image(systemName: "checkmark")
                                .font(.subheadline)
                                .padding(.trailing, 8)
                                .transition(.scale.combined(with: .opacity))
                        } else {
                            Image(systemName: "document.on.document")
                                .font(.subheadline)
                                .foregroundStyle(.primary)
                                .padding(.trailing, 8)
                                .transition(.scale.combined(with: .opacity))
                        }
                    }
                    .buttonPillStyle()
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
                        shortcut(mods: ["command"], key: "C")
                        if showCopyConfirmation {
                            Image(systemName: "checkmark")
                                .font(.subheadline)
                                .padding(.trailing, 8)
                                .transition(.scale.combined(with: .opacity))
                        } else {
                            Image(systemName: "photo.on.rectangle")
                                .font(.subheadline)
                                .foregroundStyle(.primary)
                                .padding(.trailing, 8)
                                .transition(.scale.combined(with: .opacity))
                        }
                    }
                    .buttonPillStyle()
                }
                .keyboardShortcut("c", modifiers: .command)
                .help("Copy image to the clipboard")
            }
            Button(action: onPaste) {
                HStack {
                    shortcut(mods: ["return"])
                    Text("Paste")
                        .font(.body)
                        .padding(.trailing, 8)
                }
                .buttonPillStyle()
            }
            .keyboardShortcut(.return)
            .help("Paste this copy")
        }
        .buttonStyle(.borderless)
        .font(.caption)
    }
    
    @ViewBuilder
    func shortcut(mods: [String], key: String? = nil) -> some View {
        HStack(spacing: 3) {
            ForEach(mods, id: \.self) { mod in
                Image(systemName: mod)
                    .resizable()
                    .frame(width: 10, height: 10)
            }
            if let key {
                Text(key)
                    .font(.system(size: 12))
            }
        }
        .padding(.vertical, 3)
        .padding(.horizontal, 8)
        .frame(height: 22)
        .foregroundStyle(.secondary)
        .background(
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .fill(.ultraThickMaterial)
        )
    }
}

private extension ClipboardEntry {
    func calculateThumbnailSize(
        imageSize: CGSize,
        containerSize: CGSize,
        imageAspectRatio: CGFloat
    ) -> CGSize {
        let isPortrait = imageAspectRatio < 1.0
        var calculatedSize: CGSize
        if isPortrait {
            let height = containerSize.height * thumbnailHeightScale
            let width = height * imageAspectRatio
            if width > containerSize.width * thumbnailWidthScale {
                let constrainedWidth = containerSize.width * thumbnailWidthScale
                let constrainedHeight = constrainedWidth / imageAspectRatio
                calculatedSize = CGSize(width: constrainedWidth, height: constrainedHeight)
            } else {
                calculatedSize = CGSize(width: width, height: height)
            }
        } else {
            let width = containerSize.width * thumbnailWidthScale
            let height = width / imageAspectRatio
            if height > containerSize.height * thumbnailHeightScale {
                let constrainedHeight = containerSize.height * thumbnailHeightScale
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
    }
    
    func linkDestination() -> URL? {
        if let url = URL(string: entry.original), url.scheme != nil {
            return url
        }
        if !entry.original.isEmpty,
           entry.original.contains("."),
           let url = URL(string: "https://\(entry.original)") {
            return url
        }
        return nil
    }
    
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
    
    func decodeImage(data: Data) async -> NSImage? {
        await withCheckedContinuation { cont in
            DispatchQueue.global(qos: .userInitiated).async {
                let image = NSImage(data: data)
                cont.resume(returning: image)
            }
        }
    }
}

private struct ButtonPillStyle: ViewModifier {
    let localIsPinned: Bool
    let canPin: Bool

    func body(content: Content) -> some View {
        let overlayStyle: AnyShapeStyle = {
            if localIsPinned {
                return AnyShapeStyle(Color.accentColor.opacity(0.2))
            }
            return AnyShapeStyle(Color.secondary.opacity(canPin ? 0.2 : 0.1))
        }()
        content
            .padding(3)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(overlayStyle)
                    )
            )
    }
}

private extension View {
    func buttonPillStyle(localIsPinned: Bool = false, canPin: Bool = true) -> some View {
        modifier(ButtonPillStyle(localIsPinned: localIsPinned, canPin: canPin))
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
