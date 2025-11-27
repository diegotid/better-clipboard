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
        scroll.hasVerticalScroller = true
        scroll.hasHorizontalScroller = true
        scroll.drawsBackground = false
        scroll.scrollerStyle = .overlay
        scroll.wantsLayer = true
        scroll.layer?.cornerRadius = cornerRadius
        scroll.layer?.masksToBounds = true
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
            scroll.autohidesScrollers = false
        } else {
            textView.drawsBackground = false
            scroll.autohidesScrollers = true
        }
        scroll.documentView = textView
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
        controller.textView = textView
        return scroll
    }

    func updateNSView(_ nsView: ScaledScrollView, context: Context) {
        if let textView = nsView.documentView as? ShortcutAwareTextView, textView.string != text {
            textView.performProgrammaticEdit {
                textView.string = text
            }
        }
        if let textView = nsView.documentView as? ShortcutAwareTextView {
            if isCode {
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
                textView.textContainer?.containerSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
                textView.autoresizingMask = []
                nsView.hasHorizontalScroller = false
                nsView.hasVerticalScroller = true
                nsView.autohidesScrollers = false
                let originalText = textView.string
                CodeDetector.configureCodeStyling(for: textView, language: codeLanguage)
                if textView.string != originalText {
                    DispatchQueue.main.async {
                        context.coordinator.parent.text = textView.string
                    }
                }
            } else {
                textView.backgroundColor = .clear
                textView.textColor = .textColor
                textView.font = .preferredFont(forTextStyle: .body)
                textView.drawsBackground = false
                textView.isHorizontallyResizable = false
                textView.isVerticallyResizable = true
                textView.textContainer?.widthTracksTextView = true
                textView.textContainer?.heightTracksTextView = false
                textView.textContainer?.containerSize = NSSize(width: nsView.contentSize.width, height: CGFloat.greatestFiniteMagnitude)
                textView.autoresizingMask = [.width]
                nsView.hasHorizontalScroller = false
                nsView.hasVerticalScroller = true
                nsView.autohidesScrollers = true
            }
        }
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
        controller.textView = nsView.documentView as? NSTextView
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
    
    init(isCode: Bool) {
        self.isCode = isCode
        super.init(frame: .zero)
    }
    
    func setIsCode(_ newValue: Bool) {
        self.isCode = newValue
        updateScale()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func resize(withOldSuperviewSize oldSize: NSSize) {
        super.resize(withOldSuperviewSize: oldSize)
        updateScale()
    }
    
    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        updateScale()
    }
    
    private func updateScale() {
        guard let window = window else {
            return
        }
        let baseWindowHeight: CGFloat = 400.0
        let currentWindowHeight = window.frame.height
        let scale = currentWindowHeight / baseWindowHeight
        if let textView = documentView as? NSTextView {
            let baseFontSize = NSFont.preferredFont(forTextStyle: .body).pointSize
            let scaledFontSize = baseFontSize * scale * (isCode ? 1.05 : 1.15)
            if let currentFont = textView.font {
                let isMonospaced = currentFont.fontDescriptor.symbolicTraits.contains(.monoSpace)
                if isMonospaced {
                    textView.font = .monospacedSystemFont(ofSize: scaledFontSize, weight: .regular)
                } else {
                    textView.font = .systemFont(ofSize: scaledFontSize)
                }
            }
        }
    }
}
