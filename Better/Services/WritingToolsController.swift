//
//  WritingToolsController.swift
//  Better
//
//  Created by Diego Rivera on 9/11/25.
//

import Foundation
import Combine
import AppKit

extension Notification.Name {
    static let rewriteFrontEntryRequested = Notification.Name("rewriteFrontEntryRequested")
}

final class WritingToolsController: ObservableObject {
    weak var textView: NSTextView?

    private func ensureSelectionIfNeeded(_ tv: NSTextView) {
        let range = tv.selectedRange()
        if range.length == 0 {
            if let storage = tv.textStorage, !storage.string.isEmpty {
                let string = storage.string as NSString
                let loc = min(range.location == NSNotFound ? tv.selectedRange().location : range.location, string.length)
                let paraRange = string.paragraphRange(for: NSRange(location: max(0, loc), length: 0))
                tv.setSelectedRange(paraRange)
            }
        }
    }

    func presentWritingToolsMenu() {
        guard let tv = textView, let window = tv.window else { return }
        window.makeFirstResponder(tv)
        ensureSelectionIfNeeded(tv)
        var range = tv.selectedRange()
        if range.location == NSNotFound { range = NSRange(location: 0, length: 0) }
        let caretRectScreen = tv.firstRect(forCharacterRange: range, actualRange: nil)
        let caretRectWindow = window.convertFromScreen(caretRectScreen)
        let localPoint = tv.convert(caretRectWindow.origin, from: nil)
        guard let event = NSEvent.mouseEvent(
            with: .rightMouseDown,
            location: localPoint,
            modifierFlags: [],
            timestamp: ProcessInfo.processInfo.systemUptime,
            windowNumber: window.windowNumber,
            context: nil,
            eventNumber: 0,
            clickCount: 1,
            pressure: 0
        ) else { return }

        let contextualMenu = tv.menu(for: event) ?? NSMenu(title: "Edit")
        NSMenu.popUpContextMenu(contextualMenu, with: event, for: tv)
    }

    func showWritingToolsPanel() {
        guard let tv = textView, let window = tv.window else { return }
        window.makeFirstResponder(tv)
        ensureSelectionIfNeeded(tv)
        if tv.tryToPerform(#selector(NSResponder.showWritingTools(_:)), with: nil) {
            return
        }
        let handled = NSApplication.shared.sendAction(#selector(NSResponder.showWritingTools(_:)), to: nil, from: tv)
        if handled == false {
            presentWritingToolsMenu()
        }
    }

    func focusTextView() {
        guard let tv = textView else { return }
        tv.window?.makeFirstResponder(tv)
    }
}
