//
//  WindowController.swift
//  Better
//
//  Created by Diego Rivera on 2/11/25.
//

import AppKit
import Carbon.HIToolbox
import SwiftUI

private let ESCAPE_KEY_CODE: Int = 53
private let WINDOW_WIDTH: CGFloat = 600
private let WINDOW_HEIGHT: CGFloat = 500
private let OFFSET_STEP: Int = 125
private let OFFSET_DECAY: CGFloat = 0.75
private let SCALE_STEP: CGFloat = 0.1
private let OPACITY_STEP: CGFloat = 0.2

final class EscapeClosableWindow: NSWindow {
    override func keyDown(with event: NSEvent) {
        if event.keyCode == ESCAPE_KEY_CODE {
            self.orderOut(nil)
        } else {
            super.keyDown(with: event)
        }
    }
}

@MainActor
final class WindowController {
    private let statusItem: NSStatusItem
    private var windows: [NSWindow] = []
    private let clipboard: ClipboardController

    init(clipboard: ClipboardController) {
        self.clipboard = clipboard
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        configureStatusItem()
        registerHotKey()
    }

    @objc
    private func toggleWindow(_ sender: Any?) {
        if windows.contains(where: { $0.isVisible }) {
            closeWindows()
        } else {
            showWindows()
        }
    }

    private func showWindows() {
        closeWindows()
        guard !clipboard.history.isEmpty else {
            return
        }
        guard let screen = NSScreen.main ?? NSScreen.screens.first else {
            return
        }
        let baseSize = NSSize(width: WINDOW_WIDTH, height: WINDOW_HEIGHT)
        let screenFrame = screen.visibleFrame
        let centerPoint = NSPoint(
            x: screenFrame.midX,
            y: screenFrame.midY
        )
        var allWindows: [NSWindow] = []
        var cumulativeOffset: CGFloat = 0
        let entries = clipboard.history
        for (depth, entry) in entries.enumerated() {
            let scale = max(1.0 - CGFloat(depth) * SCALE_STEP, 0.3)
            let opacity = 1.0 - CGFloat(depth) * OPACITY_STEP
            let windowSize = NSSize(width: baseSize.width * scale, height: baseSize.height * scale)
            let multiplier = depth == 0 ? 1 : pow(OFFSET_DECAY, CGFloat(depth))
            cumulativeOffset += CGFloat(OFFSET_STEP) * multiplier
            let origin = NSPoint(
                x: centerPoint.x - windowSize.width / 2,
                y: centerPoint.y - windowSize.height / 2 - cumulativeOffset
            )
            let hostingController = NSHostingController(
                rootView: ClipboardHistoryWindowView(entry: entry, isFrontMost: depth == 0)
                    .frame(width: windowSize.width, height: windowSize.height, alignment: .topLeading)
                    .clipped()
            )
            let window = EscapeClosableWindow(
                contentRect: NSRect(origin: origin, size: windowSize),
                styleMask: [.borderless],
                backing: .buffered,
                defer: false
            )
            window.hasShadow = true
            window.isOpaque = false
            window.alphaValue = opacity
            window.backgroundColor = NSColor.clear
            window.isReleasedWhenClosed = false
            window.isMovableByWindowBackground = false
            window.contentViewController = hostingController
            window.level = NSWindow.Level.floating
            window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            window.setFrame(NSRect(origin: origin, size: windowSize), display: false)
            window.contentMinSize = windowSize
            window.contentMaxSize = windowSize
            window.makeKeyAndOrderFront(nil)
            allWindows.append(window)
        }
        guard let frontWindow = allWindows.first else {
            return
        }
        for (offset, window) in allWindows.enumerated() {
            if offset == 0 {
                window.orderFrontRegardless()
            } else {
                window.order(.below, relativeTo: allWindows[offset - 1].windowNumber)
            }
        }
        windows = allWindows
        frontWindow.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func closeWindows() {
        windows.forEach { window in
            window.orderOut(nil)
            window.close()
        }
        windows.removeAll()
    }

    private func configureStatusItem() {
        guard let button = statusItem.button else {
            return
        }
        button.image = NSImage(systemSymbolName: "sparkles",
                               accessibilityDescription: "Better")
        button.image?.isTemplate = true
        button.action = #selector(toggleWindow(_:))
        button.target = self
    }

    private func registerHotKey() {
        let keyCode = UInt32(kVK_ANSI_V)
        let modifiers = UInt32(cmdKey | shiftKey)
        HotKeyCenter.shared.register(keyCode: keyCode, modifiers: modifiers) { [weak self] in
            guard let self else { return }
            if self.windows.contains(where: { $0.isVisible }) {
                self.closeWindows()
            } else {
                self.showWindows()
            }
        }
    }
}

private struct ClipboardHistoryWindowView: View {
    let entry: TransformedText
    let isFrontMost: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(displayText)
                .font(.title3.weight(.semibold))
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
            Text(entry.original)
                .font(.caption)
                .foregroundStyle(.secondary)
            if isFrontMost {
                HStack(spacing: 12) {
                    Button("Copy translation") {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(displayText, forType: .string)
                    }
                    Button("Copy original") {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(entry.original, forType: .string)
                    }
                }
                .buttonStyle(.borderless)
                .font(.caption)
            }
            Spacer()
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color(NSColor.windowBackgroundColor).opacity(isFrontMost ? 0.96 : 0.85))
                .shadow(color: .black.opacity(isFrontMost ? 0.25 : 0.15),
                        radius: isFrontMost ? 18 : 12,
                        x: 0,
                        y: isFrontMost ? 12 : 8)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(.white.opacity(isFrontMost ? 0.25 : 0.15), lineWidth: 1)
        )
    }

    private var displayText: String {
        if let variant = entry.variants.first?.value {
            return variant
        }
        return entry.original
    }
}
