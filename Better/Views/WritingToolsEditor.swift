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

    func makeNSView(context: Context) -> NSScrollView {
        let scroll = NSScrollView()
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
            textView.isHorizontallyResizable = true
            textView.isVerticallyResizable = true
            textView.textContainer?.widthTracksTextView = false
            textView.textContainer?.heightTracksTextView = false
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

    func updateNSView(_ nsView: NSScrollView, context: Context) {
        if let textView = nsView.documentView as? ShortcutAwareTextView, textView.string != text {
            textView.performProgrammaticEdit {
                textView.string = text
            }
        }
        if let textView = nsView.documentView as? ShortcutAwareTextView {
            if isCode {
                textView.backgroundColor = NSColor.white
                textView.font = .monospacedSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
                textView.drawsBackground = true
                textView.insertionPointColor = .clear
                textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
                textView.isHorizontallyResizable = true
                textView.isVerticallyResizable = true
                textView.textContainer?.widthTracksTextView = false
                textView.textContainer?.heightTracksTextView = false
                textView.textContainer?.containerSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
                textView.autoresizingMask = []
                nsView.hasHorizontalScroller = true
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

    static func dismantleNSView(_ nsView: NSScrollView, coordinator: Coordinator) {
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

    static func blurredBackground(cornerRadius: CGFloat = 12) -> some View {
        VisualEffectBlur(material: .contentBackground).opacity(0.6)
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
