//
//  WritingToolsEditor.swift
//  Better
//
//  Created by Diego Rivera on 9/11/25.
//

import SwiftUI

struct WritingToolsEditor: NSViewRepresentable {
    @Binding var text: String
    @ObservedObject var controller: WritingToolsController
    
    let codeLanguage: ProgrammingLanguage?
    private var isCode: Bool { codeLanguage != nil }
    
    private let cornerRadius: CGFloat = 12

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeNSView(context: Context) -> ScaledScrollView {
        let scroll = ScaledScrollView(isCode: isCode)
        configureScrollView(scroll)
        let textView = createTextView(context: context)
        scroll.documentView = textView
        configureScrollers(scroll)
        controller.textView = textView
        return scroll
    }

    func updateNSView(_ nsView: ScaledScrollView, context: Context) {
        guard let textView = nsView.documentView as? ShortcutAwareTextView else {
            return
        }
        if textView.string != text {
            textView.performProgrammaticEdit {
                textView.string = text
            }
        }
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let isAllEmojis = !trimmedText.isEmpty && trimmedText.allSatisfy { $0.isEmoji }
        if isAllEmojis {
            configureEmojiDisplay(textView: textView, scrollView: nsView, emojiCount: trimmedText.count)
        } else {
            nsView.setIsEmoji(false)
            textView.textContainerInset = NSSize(width: 6, height: 8)
            
            if isCode {
                configureCodeDisplay(textView: textView, scrollView: nsView, context: context)
            } else {
                configureTextDisplay(textView: textView, scrollView: nsView)
            }
        }
        updateScrollViewAppearance(nsView)
        controller.textView = textView
    }
    
    private func configureScrollView(_ scroll: ScaledScrollView) {
        scroll.hasVerticalScroller = true
        scroll.hasHorizontalScroller = true
        scroll.drawsBackground = false
        scroll.scrollerStyle = .overlay
        scroll.wantsLayer = true
        scroll.layer?.cornerRadius = cornerRadius
        scroll.layer?.masksToBounds = true
        scroll.autohidesScrollers = !isCode
    }
    
    private func createTextView(context: Context) -> ShortcutAwareTextView {
        let textView = ShortcutAwareTextView(frame: .zero)
        textView.commandRAction = { [weak controller] in
            controller?.showWritingToolsPanel()
        }
        textView.isRichText = false
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDataDetectionEnabled = false
        textView.isSelectable = true
        textView.insertionPointColor = .clear
        textView.performProgrammaticEdit {
            textView.string = text
        }
        textView.delegate = context.coordinator
        textView.textContainerInset = NSSize(width: 6, height: 8)
        textView.usesAdaptiveColorMappingForDarkAppearance = true
        if isCode {
            textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
            textView.isHorizontallyResizable = false
            textView.isVerticallyResizable = true
            textView.textContainer?.widthTracksTextView = false
            textView.textContainer?.heightTracksTextView = false
            textView.textContainer?.lineBreakMode = .byClipping
            textView.textContainer?.containerSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
            textView.autoresizingMask = []
        } else {
            textView.drawsBackground = false
        }
        return textView
    }
    
    private func configureScrollers(_ scroll: ScaledScrollView) {
        if let verticalScroller = scroll.verticalScroller {
            verticalScroller.wantsLayer = true
            verticalScroller.layer?.backgroundColor = NSColor.clear.cgColor
            verticalScroller.alphaValue = 1.0
            verticalScroller.scrollerStyle = .overlay
            verticalScroller.knobStyle = .default
            verticalScroller.layer?.cornerRadius = cornerRadius
        }
        if let horizontalScroller = scroll.horizontalScroller {
            horizontalScroller.wantsLayer = true
            horizontalScroller.layer?.backgroundColor = NSColor.clear.cgColor
            horizontalScroller.alphaValue = 0.0
            horizontalScroller.scrollerStyle = .overlay
        }
    }
    
    private func configureEmojiDisplay(textView: ShortcutAwareTextView, scrollView: ScaledScrollView, emojiCount: Int) {
        scrollView.setIsEmoji(true)
        let baseFontSize = NSFont.preferredFont(forTextStyle: .body).pointSize
        let multiplier = max(1.0, 11.0 - CGFloat(emojiCount))
        let finalFontSize = baseFontSize * multiplier
        textView.font = .systemFont(ofSize: finalFontSize)
        textView.alignment = .center
        textView.drawsBackground = false
        textView.backgroundColor = .clear
        scrollView.drawsBackground = false
        scrollView.hasHorizontalScroller = false
        scrollView.hasVerticalScroller = false
        scrollView.autohidesScrollers = true
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = true
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.heightTracksTextView = false
        textView.textContainer?.containerSize = NSSize(width: scrollView.contentSize.width, height: CGFloat.greatestFiniteMagnitude)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.minSize = NSSize(width: scrollView.contentSize.width, height: 0)
        DispatchQueue.main.async {
            scrollView.recenterEmojiIfNeeded()
        }
    }
    
    private func configureCodeDisplay(textView: ShortcutAwareTextView, scrollView: ScaledScrollView, context: Context) {
        textView.backgroundColor = NSColor.white
        let fontSize = NSFont.preferredFont(forTextStyle: .body).pointSize
        textView.font = .monospacedSystemFont(ofSize: fontSize, weight: .regular)
        textView.drawsBackground = false
        textView.insertionPointColor = .clear
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.isHorizontallyResizable = false
        textView.isVerticallyResizable = true
        textView.textContainer?.widthTracksTextView = false
        textView.textContainer?.heightTracksTextView = false
        textView.textContainer?.lineBreakMode = .byClipping
        textView.textContainer?.containerSize = NSSize(width: CGFloat.greatestFiniteMagnitude,
                                                       height: CGFloat.greatestFiniteMagnitude)
        textView.autoresizingMask = []
        scrollView.hasHorizontalScroller = false
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = false
        let originalText = textView.string
        CodeDetector.configureCodeStyling(for: textView, language: codeLanguage)
        if textView.string != originalText {
            DispatchQueue.main.async {
                context.coordinator.parent.text = textView.string
            }
        }
    }
    
    private func configureTextDisplay(textView: ShortcutAwareTextView, scrollView: ScaledScrollView) {
        textView.backgroundColor = .clear
        textView.textColor = .textColor
        textView.font = .preferredFont(forTextStyle: .body)
        textView.drawsBackground = false
        textView.isHorizontallyResizable = false
        textView.isVerticallyResizable = true
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.heightTracksTextView = false
        textView.textContainer?.containerSize = NSSize(width: scrollView.contentSize.width,
                                                       height: CGFloat.greatestFiniteMagnitude)
        textView.autoresizingMask = [.width]
        scrollView.hasHorizontalScroller = false
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
    }
    
    private func updateScrollViewAppearance(_ nsView: ScaledScrollView) {
        nsView.setIsCode(isCode)
        nsView.wantsLayer = true
        nsView.layer?.cornerRadius = cornerRadius
        nsView.layer?.masksToBounds = true
        nsView.scrollerStyle = .overlay
        if let verticalScroller = nsView.verticalScroller {
            verticalScroller.scrollerStyle = .overlay
            verticalScroller.wantsLayer = true
            verticalScroller.layer?.backgroundColor = NSColor.clear.cgColor
            verticalScroller.knobStyle = .default
        }
        if let horizontalScroller = nsView.horizontalScroller {
            horizontalScroller.scrollerStyle = .overlay
            horizontalScroller.wantsLayer = true
            horizontalScroller.layer?.backgroundColor = NSColor.clear.cgColor
            horizontalScroller.alphaValue = 0.0
        }
    }

    static func dismantleNSView(_ nsView: ScaledScrollView, coordinator: Coordinator) {
        if let textView = nsView.documentView as? NSTextView {
            textView.delegate = nil
        }
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        let parent: WritingToolsEditor
        init(_ parent: WritingToolsEditor) { self.parent = parent }
        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else {
                return
            }
            parent.text = textView.string
        }
    }
}

private final class ShortcutAwareTextView: NSTextView {
    var commandRAction: (() -> Void)?
    private var programmaticEditDepth = 0

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if handleCommandR(event: event) {
            return true
        }
        return super.performKeyEquivalent(with: event)
    }

    override func keyDown(with event: NSEvent) {
        if handleCommandR(event: event) {
            return
        }
        super.keyDown(with: event)
    }

    func performProgrammaticEdit(_ block: () -> Void) {
        programmaticEditDepth += 1
        block()
        programmaticEditDepth -= 1
    }

    override func shouldChangeText(in affectedCharRange: NSRange, replacementString: String?) -> Bool {
        if programmaticEditDepth > 0 ||
            self.isWritingToolsActive {
            return super.shouldChangeText(in: affectedCharRange,
                                          replacementString: replacementString)
        }
        return false
    }

    private func handleCommandR(event: NSEvent) -> Bool {
        guard event.type == .keyDown else {
            return false
        }
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        guard flags.contains(.command),
              event.charactersIgnoringModifiers?.lowercased() == "r" else {
            return false
        }
        commandRAction?()
        return true
    }
}

final class ScaledScrollView: NSScrollView {
    private var isCode: Bool
    private var isEmoji: Bool = false
    
    init(isCode: Bool) {
        self.isCode = isCode
        super.init(frame: .zero)
    }
    
    func setIsCode(_ newValue: Bool) {
        self.isCode = newValue
        updateScale()
    }
    
    func setIsEmoji(_ newValue: Bool) {
        guard newValue != isEmoji else { return }
        isEmoji = newValue
        updateContentViewForEmoji()
        updateElasticity()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func resize(withOldSuperviewSize oldSize: NSSize) {
        super.resize(withOldSuperviewSize: oldSize)
        updateScale()
        recenterEmojiIfNeeded()
    }
    
    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        updateScale()
        recenterEmojiIfNeeded()
    }
    
    private func updateScale() {
        guard !isEmoji, let window = window else {
            return
        }
        let baseWindowHeight: CGFloat = 400.0
        let currentWindowHeight = window.frame.height
        let scale = currentWindowHeight / baseWindowHeight
        guard let textView = documentView as? NSTextView else {
            return
        }
        let baseFontSize = NSFont.preferredFont(forTextStyle: .body).pointSize
        let scaledFontSize = baseFontSize * scale * (isCode ? 1.05 : 1.15)
        if let currentFont = textView.font {
            let isMonospaced = currentFont.fontDescriptor.symbolicTraits.contains(.monoSpace)
            textView.font = isMonospaced
                ? .monospacedSystemFont(ofSize: scaledFontSize, weight: .regular)
                : .systemFont(ofSize: scaledFontSize)
        }
    }

    func recenterEmojiIfNeeded() {
        guard isEmoji,
              let textView = documentView as? NSTextView,
              let layoutManager = textView.layoutManager,
              let textContainer = textView.textContainer else {
            return
        }
        layoutManager.ensureLayout(for: textContainer)
        let textHeight = layoutManager.usedRect(for: textContainer).height
        let availableHeight = contentView.bounds.height
        let currentInsets = textView.textContainerInset
        let verticalInset = max(0, (availableHeight - textHeight) / 2)
        textView.textContainerInset = NSSize(width: currentInsets.width, height: verticalInset)
    }

    private func updateContentViewForEmoji() {
        let needsCenteringClip = isEmoji
        let currentClipView = contentView
        if needsCenteringClip, !(currentClipView is CenteringClipView) {
            replaceContentView(with: CenteringClipView(frame: currentClipView.frame))
        } else if !needsCenteringClip, currentClipView is CenteringClipView {
            replaceContentView(with: NSClipView(frame: currentClipView.frame))
        }
    }

    private func replaceContentView(with newClipView: NSClipView) {
        let oldClipView = contentView
        let document = documentView
        newClipView.drawsBackground = oldClipView.drawsBackground
        newClipView.backgroundColor = oldClipView.backgroundColor
        newClipView.autoresizingMask = oldClipView.autoresizingMask
        newClipView.documentView = document
        contentView = newClipView
        documentView = document
    }

    private func updateElasticity() {
        let elasticity: NSScrollView.Elasticity = isEmoji ? .none : .automatic
        verticalScrollElasticity = elasticity
        horizontalScrollElasticity = elasticity
    }
}

extension Character {
    var isEmoji: Bool {
        guard let scalar = unicodeScalars.first else { return false }
        return scalar.properties.isEmoji && (scalar.value > 0x238C || unicodeScalars.count > 1)
    }
}

class CenteringClipView: NSClipView {
    override var documentView: NSView? {
        didSet {
            if let view = documentView {
                NotificationCenter.default.removeObserver(self, name: NSView.frameDidChangeNotification, object: oldValue)
                view.postsFrameChangedNotifications = true
                NotificationCenter.default.addObserver(self, selector: #selector(documentViewFrameChanged), name: NSView.frameDidChangeNotification, object: view)
            }
        }
    }
    
    @objc private func documentViewFrameChanged(_ notification: Notification) {
        let currentBounds = bounds
        setBoundsOrigin(constrainBoundsRect(currentBounds).origin)
    }
    
    override func constrainBoundsRect(_ proposedBounds: NSRect) -> NSRect {
        var rect = super.constrainBoundsRect(proposedBounds)
        guard let documentView = documentView else {
            return rect
        }
        let documentHeight = documentView.frame.height
        let documentWidth = documentView.frame.width
        let clipViewHeight = bounds.height
        let clipViewWidth = bounds.width
        if documentHeight < clipViewHeight {
            rect.origin.y = -(clipViewHeight - documentHeight) / 2
        }
        if documentWidth < clipViewWidth {
            rect.origin.x = -(clipViewWidth - documentWidth) / 2
        }
        return rect
    }
    
    override func viewBoundsChanged(_ notification: Notification) {
        super.viewBoundsChanged(notification)
        let currentBounds = bounds
        setBoundsOrigin(constrainBoundsRect(currentBounds).origin)
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}

