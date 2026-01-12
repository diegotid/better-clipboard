//
//  WritingToolsController.swift
//  Better
//
//  Created by Diego Rivera on 9/11/25.
//

import Foundation
import Combine
internal import AppKit

extension Notification.Name {
    static let rewriteFrontEntryRequested = Notification.Name("rewriteFrontEntryRequested")
    static let deleteFrontEntryRequested = Notification.Name("deleteFrontEntryRequested")
    static let wrapToFirstEntryRequested = Notification.Name("wrapToFirstEntryRequested")
    static let toggleEntryPinnedRequested = Notification.Name("toggleEntryPinnedRequested")
    static let entryPinnedStateChanged = Notification.Name("entryPinnedStateChanged")
    static let searchEntriesRequested = Notification.Name("searchEntriesRequested")
    static let translationRequested = Notification.Name("translationRequested")
    static let restorePurchasesRequested = Notification.Name("restorePurchasesRequested")
    static let openSettingsRequested = Notification.Name("openSettingsRequested")
    static let showUpgradeAlertRequested = Notification.Name("showUpgradeAlertRequested")
}

final class WritingToolsController: ObservableObject {
    weak var textView: NSTextView?
    var onUnavailable: (() -> Void)?
    private var pendingDismissal: DispatchWorkItem?
    
    @discardableResult
    func showWritingToolsPanel() -> Bool {
        guard let tv = textView, let window = tv.window else {
            onUnavailable?()
            return false
        }
        window.makeFirstResponder(tv)
        ensureSelectionIfNeeded(tv)
        if NSWritingToolsCoordinator.isWritingToolsAvailable == false {
            onUnavailable?()
            return false
        }
        if tv.tryToPerform(#selector(NSResponder.showWritingTools(_:)), with: nil) {
            return true
        }
        let handled = NSApplication.shared.sendAction(
            #selector(NSResponder.showWritingTools(_:)),
            to: nil,
            from: tv
        )
        if handled {
            return true
        }
        onUnavailable?()
        return false
    }

    func focusTextView() {
        guard let tv = textView else {
            return
        }
        pendingDismissal?.cancel()
        pendingDismissal = nil
        tv.window?.makeFirstResponder(tv)
    }

    func dismissWritingToolsIfNeeded() {
        guard let tv = textView else {
            return
        }
        if #available(macOS 15.2, *) {
            if let coordinator = tv.writingToolsCoordinator,
               coordinator.state != .inactive {
                coordinator.stopWritingTools()
            }
        }
    }

    func scheduleDismiss(delay: TimeInterval = 0.25) {
        guard let tv = textView, tv.window != nil else { return }
        if #available(macOS 15.2, *) {
            if let coordinator = tv.writingToolsCoordinator,
               coordinator.state == .inactive {
                return
            }
        }
        pendingDismissal?.cancel()
        let work = DispatchWorkItem { [weak self] in
            self?.dismissWritingToolsIfNeeded()
        }
        pendingDismissal = work
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
    }
}

private extension WritingToolsController {
    func ensureSelectionIfNeeded(_ tv: NSTextView) {
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
}
