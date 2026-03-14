//
//  ShortcutAwareText.swift
//  Better
//
//  Created by Diego Rivera on 21/12/25.
//

internal import AppKit

final class ShortcutAwareText: NSTextView {
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
}

private extension ShortcutAwareText {
    func handleCommandR(event: NSEvent) -> Bool {
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
