//
//  WritingToolsEditor.swift
//  Better
//
//  Created by Diego Rivera on 9/11/25.
//

import SwiftUI
import AppKit

struct WritingToolsEditor: NSViewRepresentable {
    @Binding var text: String
    @ObservedObject var controller: WritingToolsController
    
    let cornerRadius: CGFloat = 12

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scroll = NSScrollView()
        scroll.hasVerticalScroller = true
        scroll.autohidesScrollers = true
        scroll.drawsBackground = false
        scroll.scrollerStyle = .overlay
        scroll.wantsLayer = true
        scroll.layer?.cornerRadius = cornerRadius
        scroll.layer?.masksToBounds = true
        if let verticalScroller = scroll.verticalScroller {
            verticalScroller.wantsLayer = true
            verticalScroller.layer?.backgroundColor = NSColor.clear.cgColor
            verticalScroller.alphaValue = 1.0
            verticalScroller.scrollerStyle = .overlay
            verticalScroller.knobStyle = .default
            verticalScroller.layer?.cornerRadius = cornerRadius
        }
        let tv = ShortcutAwareTextView(frame: .zero)
        tv.commandRAction = { [weak controller] in
            controller?.showWritingToolsPanel()
        }
        tv.isRichText = false
        tv.isAutomaticQuoteSubstitutionEnabled = false
        tv.isAutomaticDataDetectionEnabled = false
        tv.font = .preferredFont(forTextStyle: .body)
        tv.performProgrammaticEdit {
            tv.string = text
        }
        tv.delegate = context.coordinator
        tv.textContainerInset = NSSize(width: 6, height: 8)
        tv.usesAdaptiveColorMappingForDarkAppearance = true
        tv.drawsBackground = false
        scroll.documentView = tv
        controller.textView = tv
        return scroll
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {
        if let tv = nsView.documentView as? ShortcutAwareTextView, tv.string != text {
            tv.performProgrammaticEdit {
                tv.string = text
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
        controller.textView = nsView.documentView as? NSTextView
    }

    static func dismantleNSView(_ nsView: NSScrollView, coordinator: Coordinator) {
        if let tv = nsView.documentView as? NSTextView {
            tv.delegate = nil
        }
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        private let parent: WritingToolsEditor
        init(_ parent: WritingToolsEditor) { self.parent = parent }
        func textDidChange(_ notification: Notification) {
            guard let tv = notification.object as? NSTextView else {
                return
            }
            parent.text = tv.string
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
        if programmaticEditDepth > 0 {
            return super.shouldChangeText(in: affectedCharRange, replacementString: replacementString)
        }
        if #available(macOS 15.0, *), self.isWritingToolsActive {
            return super.shouldChangeText(in: affectedCharRange, replacementString: replacementString)
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
