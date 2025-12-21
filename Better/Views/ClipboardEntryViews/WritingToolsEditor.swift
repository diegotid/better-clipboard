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
    
    let isEmoji: Bool
    let codeLanguage: ProgrammingLanguage?
    private var isCode: Bool {
        codeLanguage != nil
    }
    private let cornerRadius: CGFloat = 12

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeNSView(context: Context) -> ScaledScroll {
        let scroll = ScaledScroll(isCode: isCode)
        configureScrollView(scroll)
        let textView = createTextView(context: context)
        scroll.documentView = textView
        configureScrollers(scroll)
        controller.textView = textView
        return scroll
    }

    func updateNSView(_ nsView: ScaledScroll, context: Context) {
        guard let textView = nsView.documentView as? ShortcutAwareText else {
            return
        }
        if textView.string != text {
            textView.performProgrammaticEdit {
                textView.string = text
            }
        }
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let isEmojiOnly = (!trimmedText.isEmpty && isEmoji)
            || (!isEmoji && !trimmedText.isEmpty && trimmedText.allSatisfy { $0.isEmoji })
        if isEmojiOnly {
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

    static func dismantleNSView(_ nsView: ScaledScroll, coordinator: Coordinator) {
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

private extension WritingToolsEditor {
    func configureScrollView(_ scroll: ScaledScroll) {
        scroll.hasVerticalScroller = true
        scroll.hasHorizontalScroller = true
        scroll.drawsBackground = false
        scroll.scrollerStyle = .overlay
        scroll.wantsLayer = true
        scroll.layer?.cornerRadius = cornerRadius
        scroll.layer?.masksToBounds = true
        scroll.autohidesScrollers = !isCode
    }
    
    func createTextView(context: Context) -> ShortcutAwareText {
        let textView = ShortcutAwareText(frame: .zero)
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
    
    func configureScrollers(_ scroll: ScaledScroll) {
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
    
    func configureEmojiDisplay(textView: ShortcutAwareText, scrollView: ScaledScroll, emojiCount: Int) {
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
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.heightTracksTextView = false
        textView.textContainer?.containerSize = NSSize(width: scrollView.contentSize.width, height: CGFloat.greatestFiniteMagnitude)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.minSize = NSSize(width: scrollView.contentSize.width, height: 0)
        DispatchQueue.main.async {
            scrollView.recenterEmojiIfNeeded()
        }
    }
    
    func configureCodeDisplay(textView: ShortcutAwareText, scrollView: ScaledScroll, context: Context) {
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
    
    func configureTextDisplay(textView: ShortcutAwareText, scrollView: ScaledScroll) {
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
    
    func updateScrollViewAppearance(_ nsView: ScaledScroll) {
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
}
