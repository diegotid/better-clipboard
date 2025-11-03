//
//  WindowController.swift
//  Better
//
//  Created by Diego Rivera on 2/11/25.
//

import AppKit
import Carbon.HIToolbox
import SwiftUI
import QuartzCore

private let ESCAPE_KEY_CODE: Int = 53
private let WINDOW_WIDTH: CGFloat = 600
private let WINDOW_HEIGHT: CGFloat = 500
private let OFFSET_STEP: Int = 130
private let OFFSET_DECAY: CGFloat = 0.6
private let SCALE_STEP: CGFloat = 0.1
private let OPACITY_STEP: CGFloat = 0.3

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
    private var entries: [TransformedText] = []
    private var baseHistory: [TransformedText] = []
    private var entryIndexLookup: [UUID: Int] = [:]
    private var keyMonitor: Any?
    private let clipboard: ClipboardController

    init(clipboard: ClipboardController) {
        self.clipboard = clipboard
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        configureStatusItem()
        registerHotKey()
    }

    private enum RotationDirection {
        case older
        case newer
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
        let history = clipboard.history
        guard !history.isEmpty else {
            return
        }
        baseHistory = history
        entryIndexLookup = Dictionary(uniqueKeysWithValues: history.enumerated().map { ($0.element.id, $0.offset) })
        entries = history
        windows = history.map { createWindow(for: $0) }
        layoutWindows(animated: false)
        installKeyMonitor()
        NSApp.activate(ignoringOtherApps: true)
    }

    private func closeWindows() {
        windows.forEach { window in
            window.orderOut(nil)
            window.close()
        }
        windows.removeAll()
        entries.removeAll()
        if let monitor = keyMonitor {
            NSEvent.removeMonitor(monitor)
            keyMonitor = nil
        }
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

    private func createWindow(for entry: TransformedText) -> NSWindow {
        let hostingController = NSHostingController(
            rootView: ClipboardEntry(entry: entry, isFrontMost: false)
        )
        let window = EscapeClosableWindow(
            contentRect: NSRect(origin: .zero, size: NSSize(width: WINDOW_WIDTH, height: WINDOW_HEIGHT)),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.hasShadow = true
        window.isOpaque = false
        window.alphaValue = 1.0
        window.backgroundColor = NSColor.clear
        window.isReleasedWhenClosed = false
        window.isMovableByWindowBackground = false
        window.contentViewController = hostingController
        window.level = NSWindow.Level.floating
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        let container = NSView(frame: NSRect(origin: .zero, size: NSSize(width: WINDOW_WIDTH, height: WINDOW_HEIGHT)))
        container.wantsLayer = true
        container.layer?.cornerRadius = 24
        container.layer?.masksToBounds = true
        let blurView = makeBlurView(container: container)
        let tintView = makeTintView(container: container)
        let hostingView = makeHostingView(container: container, hostingController: hostingController)
        container.addSubview(blurView)
        container.addSubview(tintView)
        container.addSubview(hostingView)
        window.contentView = container
        return window
    }

    private func makeBlurView(container: NSView) -> NSVisualEffectView {
        let view = NSVisualEffectView(frame: container.bounds)
        view.autoresizingMask = [.width, .height]
        view.blendingMode = .behindWindow
        view.material = .fullScreenUI
        view.state = .active
        view.isEmphasized = true
        return view
    }

    private func makeTintView(container: NSView) -> NSView {
        let view = NSView(frame: container.bounds)
        view.autoresizingMask = [.width, .height]
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor(calibratedWhite: 1.0, alpha: 0.12).cgColor
        view.identifier = NSUserInterfaceItemIdentifier("tint")
        return view
    }

    private func makeHostingView(container: NSView, hostingController: NSHostingController<ClipboardEntry>) -> NSView {
        let view = hostingController.view
        view.frame = container.bounds
        view.autoresizingMask = [.width, .height]
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.clear.cgColor
        view.layer?.cornerRadius = 24
        view.layer?.masksToBounds = true
        return view
    }

    private func layoutWindows(animated: Bool) {
        guard !windows.isEmpty, windows.count == entries.count else {
            return
        }
        guard let screen = NSScreen.main ?? NSScreen.screens.first else {
            return
        }
        guard let frontEntry = entries.first,
              let frontIndex = entryIndexLookup[frontEntry.id] else {
            return
        }
        let baseSize = NSSize(width: WINDOW_WIDTH, height: WINDOW_HEIGHT)
        let screenFrame = screen.visibleFrame
        let centerPoint = NSPoint(x: screenFrame.midX, y: screenFrame.midY)
        var belowStack: [(window: NSWindow, entry: TransformedText, baseIndex: Int)] = []
        var aboveStack: [(window: NSWindow, entry: TransformedText, baseIndex: Int)] = []
        if windows.count > 1 {
            for idx in 1..<windows.count {
                let window = windows[idx]
                let entry = entries[idx]
                guard let baseIndex = entryIndexLookup[entry.id] else {
                    continue
                }
                if baseIndex > frontIndex {
                    belowStack.append((window, entry, baseIndex))
                } else if baseIndex < frontIndex {
                    aboveStack.append((window, entry, baseIndex))
                }
            }
        }
        belowStack.sort { $0.baseIndex < $1.baseIndex }
        aboveStack.sort { $0.baseIndex > $1.baseIndex }
        var updates: [(window: NSWindow, frame: NSRect, alpha: CGFloat)] = []
        func recordUpdate(window: NSWindow, entry: TransformedText, depth: Int, offsetY: CGFloat, isFront: Bool) {
            let scale = max(1.0 - CGFloat(depth) * SCALE_STEP, 0.3)
            let opacity = 1.0 - CGFloat(depth) * OPACITY_STEP
            let windowSize = NSSize(width: baseSize.width * scale, height: baseSize.height * scale)
            let origin = NSPoint(
                x: centerPoint.x - windowSize.width / 2,
                y: centerPoint.y - windowSize.height / 2 + offsetY
            )
            let frame = NSRect(origin: origin, size: windowSize)
            window.contentMinSize = windowSize
            window.contentMaxSize = windowSize
            if let hosting = window.contentViewController as? NSHostingController<ClipboardEntry> {
                hosting.rootView = ClipboardEntry(entry: entry, isFrontMost: isFront)
            }
            if let tintView = window.contentView?.subviews.first(where: { $0.identifier == NSUserInterfaceItemIdentifier("tint") }) {
                tintView.layer?.backgroundColor = NSColor(calibratedWhite: 1.0, alpha: isFront ? 0.08 : 0.22).cgColor
            }
            updates.append((window, frame, opacity))
        }
        if let frontWindow = windows.first {
            recordUpdate(window: frontWindow, entry: frontEntry, depth: 0, offsetY: 0, isFront: true)
        }
        var belowOffset: CGFloat = 0
        for (position, element) in belowStack.enumerated() {
            let multiplier = position == 0 ? 1.0 : pow(OFFSET_DECAY, CGFloat(position))
            belowOffset -= CGFloat(OFFSET_STEP) * multiplier
            recordUpdate(window: element.window, entry: element.entry, depth: position + 1, offsetY: belowOffset, isFront: false)
        }
        var aboveOffset: CGFloat = 0
        for (position, element) in aboveStack.enumerated() {
            let multiplier = position == 0 ? 1.0 : pow(OFFSET_DECAY, CGFloat(position))
            aboveOffset += CGFloat(OFFSET_STEP) * multiplier
            recordUpdate(window: element.window, entry: element.entry, depth: position + 1, offsetY: aboveOffset, isFront: false)
        }
        if animated {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.3
                context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                context.allowsImplicitAnimation = true
                for update in updates {
                    let animator = update.window.animator()
                    animator.setFrame(update.frame, display: true)
                    animator.alphaValue = update.alpha
                }
            }
        } else {
            for update in updates {
                update.window.setFrame(update.frame, display: true, animate: false)
                update.window.alphaValue = update.alpha
            }
        }
        for index in windows.indices {
            if index == 0 {
                windows[index].makeKeyAndOrderFront(nil)
            } else {
                windows[index].order(.below, relativeTo: windows[index - 1].windowNumber)
            }
        }
    }

    private func installKeyMonitor() {
        guard keyMonitor == nil else { return }
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else { return event }
            guard !self.windows.isEmpty else {
                return event
            }
            switch event.keyCode {
            case UInt16(kVK_DownArrow):
                self.rotateWheel(direction: .older)
                return nil
            case UInt16(kVK_UpArrow):
                self.rotateWheel(direction: .newer)
                return nil
            default:
                return event
            }
        }
    }

    private func rotateWheel(direction: RotationDirection) {
        guard windows.count > 1, windows.count == entries.count else { return }
        guard let frontEntry = entries.first,
              let frontIndex = entryIndexLookup[frontEntry.id] else {
            return
        }
        switch direction {
        case .older:
            if frontIndex >= baseHistory.count - 1 {
                return
            }
            let window = windows.removeFirst()
            let entry = entries.removeFirst()
            windows.append(window)
            entries.append(entry)
        case .newer:
            if frontIndex <= 0 {
                return
            }
            let window = windows.removeLast()
            let entry = entries.removeLast()
            windows.insert(window, at: 0)
            entries.insert(entry, at: 0)
        }
        layoutWindows(animated: true)
    }
}
