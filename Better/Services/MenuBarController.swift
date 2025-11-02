//
//  MenuBarController.swift
//  Better
//
//  Created by Diego Rivera on 2/11/25.
//

import AppKit
import Carbon.HIToolbox
import SwiftUI

@MainActor
final class MenuBarController {
    private let statusItem: NSStatusItem
    private let popover = NSPopover()
    private var globalMonitor: Any?
    private let clipboard: ClipboardController

    init(clipboard: ClipboardController) {
        self.clipboard = clipboard
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        configureStatusItem()
        configurePopover()
        registerHotKey()
        installEventMonitor()
    }

    @objc
    private func togglePopover(_ sender: Any?) {
        if popover.isShown {
            closePopover()
        } else {
            showPopover()
        }
    }

    private func showPopover() {
        guard let button = statusItem.button else {
            return
        }
        if !popover.isShown {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    private func closePopover() {
        popover.performClose(nil)
    }

    private func configureStatusItem() {
        guard let button = statusItem.button else {
            return
        }
        button.image = NSImage(systemSymbolName: "sparkles.rectangle.stack.fill", accessibilityDescription: "Better")
        button.image?.isTemplate = true
        button.action = #selector(togglePopover(_:))
        button.target = self
    }

    private func configurePopover() {
        popover.behavior = .transient
        popover.animates = true
        popover.contentViewController = NSHostingController(
            rootView: Clipboard()
                .environmentObject(clipboard)
        )
    }

    private func installEventMonitor() {
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            guard let self else { return }
            if self.popover.isShown {
                self.closePopover()
            }
        }
    }

    private func registerHotKey() {
        let keyCode = UInt32(kVK_ANSI_V)
        let modifiers = UInt32(cmdKey | shiftKey)

        HotKeyCenter.shared.register(keyCode: keyCode, modifiers: modifiers) { [weak self] in
            guard let self else { return }
            if self.popover.isShown {
                self.closePopover()
            } else {
                self.showPopover()
            }
        }
    }
}
