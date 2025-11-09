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
private let RETURN_KEY_CODE: UInt16 = 36
private let WINDOW_WIDTH: CGFloat = 500
private let WINDOW_HEIGHT: CGFloat = 350
private let OFFSET_STEP: Int = 110
private let OFFSET_DECAY: CGFloat = 0.6
private let OPACITY_STEP: CGFloat = 0.2
private let SCALE_STEP: CGFloat = 0.1

@MainActor
final class WindowController {
    private let statusItem: NSStatusItem
    private let clipboard: ClipboardController
    private var windows: [(window: NSWindow, host: NSHostingController<ClipboardEntry>)] = []
    private var entries: [TransformedText] = []
    private var baseHistory: [TransformedText] = []
    private var entryIndexLookup: [UUID: Int] = [:]
    private var keyMonitor: Any?
    private var scrollMonitor: Any?
    private var resignActiveObserver: Any?
    private var lastScrollEventTime: TimeInterval = 0
    private var aboutWindow: NSWindow?
    private var lastActiveApp: NSRunningApplication?

    private var showingWindows: Bool {
        windows.contains(where: { $0.window.isVisible })
    }

    private lazy var toggleMenuItem: NSMenuItem = {
        let item = NSMenuItem(
            title: "",
            action: #selector(toggleWindow(_:)),
            keyEquivalent: "v"
        )
        item.keyEquivalentModifierMask = [.command, .shift]
        item.target = self
        item.image = NSImage(systemSymbolName: "sparkles.rectangle.stack", accessibilityDescription: nil)
        return item
    }()

    private lazy var clearItem: NSMenuItem = {
        let item = NSMenuItem(
            title: "Clear Clipboard History",
            action: #selector(clearClipboardHistoryAction(_:)),
            keyEquivalent: "\u{8}"
        )
        item.keyEquivalentModifierMask = [.command]
        item.target = self
        item.image = NSImage(systemSymbolName: "trash", accessibilityDescription: nil)
        return item
    }()

    private lazy var aboutMenuItem: NSMenuItem = {
        let item = NSMenuItem(
            title: "About Better",
            action: #selector(showAboutWindow(_:)),
            keyEquivalent: ""
        )
        item.target = self
        item.image = NSImage(systemSymbolName: "info.circle", accessibilityDescription: nil)
        return item
    }()

    private lazy var quitItem: NSMenuItem = {
        let item = NSMenuItem(
            title: "Quit Better",
            action: #selector(quitAction(_:)),
            keyEquivalent: "q"
        )
        item.target = self
        item.image = NSImage(systemSymbolName: "power", accessibilityDescription: nil)
        return item
    }()

    init(clipboard: ClipboardController) {
        self.clipboard = clipboard
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        configureStatusItem()
        registerHotKey()
        resignActiveObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didResignActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self else {
                return
            }
            Task { @MainActor in
                self.closeWindows()
            }
        }
    }

    deinit {
        if let observer = resignActiveObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        if let monitor = keyMonitor {
            NSEvent.removeMonitor(monitor)
        }
        if let monitor = scrollMonitor {
            NSEvent.removeMonitor(monitor)
        }
        if let aboutWin = aboutWindow {
            Task { @MainActor in
                aboutWin.close()
            }
        }
    }

    private enum RotationDirection {
        case older
        case newer
    }

    @objc
    private func toggleWindow(_ sender: Any?) {
        if showingWindows {
            closeWindows()
        } else {
            showWindows()
        }
    }

    private func showWindows() {
        lastActiveApp = NSWorkspace.shared.frontmostApplication
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
        installEventMonitors()
        NSApp.activate(ignoringOtherApps: true)
        updateToggleMenuTitle()
    }

    private func closeWindows() {
        for (window, _) in windows {
            window.orderOut(nil)
            window.close()
        }
        windows.removeAll()
        entries.removeAll()
        if let monitor = keyMonitor {
            NSEvent.removeMonitor(monitor)
            keyMonitor = nil
        }
        if let monitor = scrollMonitor {
            NSEvent.removeMonitor(monitor)
            scrollMonitor = nil
        }
        updateToggleMenuTitle()
    }

    private func configureStatusItem() {
        guard let button = statusItem.button else {
            return
        }
        button.image = NSImage(systemSymbolName: "sparkles",
                               accessibilityDescription: "Better")
        button.image?.isTemplate = true
        let menu = NSMenu()
        menu.addItem(toggleMenuItem)
        menu.addItem(clearItem)
        menu.addItem(NSMenuItem.separator())
        menu.addItem(aboutMenuItem)
        menu.addItem(NSMenuItem.separator())
        menu.addItem(quitItem)
        statusItem.menu = menu
        updateToggleMenuTitle()
    }

    private func updateToggleMenuTitle() {
        toggleMenuItem.title = showingWindows ? "Hide Clipboard" : "Show Clipboard"
    }

    @objc
    private func clearClipboardHistoryAction(_ sender: Any?) {
        let alert = NSAlert()
        alert.messageText = "Clear Clipboard History?"
        alert.informativeText = "This will permanently remove all clipboard items stored by Better. This action cannot be undone."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Clear History")
        alert.addButton(withTitle: "Cancel")
        if let window = NSApp.keyWindow {
            alert.beginSheetModal(for: window) { [weak self] response in
                if response == .alertFirstButtonReturn {
                    self?.clipboard.history = []
                }
            }
        } else {
            let response = alert.runModal()
            if response == .alertFirstButtonReturn {
                clipboard.history = []
            }
        }
    }

    @objc
    private func quitAction(_ sender: Any?) {
        NSApp.terminate(nil)
    }

    @objc
    private func showAboutWindow(_ sender: Any?) {
        if let aboutWin = aboutWindow {
            aboutWin.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        let hostingController = NSHostingController(rootView: About())
        let window = NSWindow(
            contentRect: NSRect(
                x: 0, y: 0,
                width: Frame.aboutWindowWidth,
                height: Frame.aboutWindowHeight
            ),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.center()
        window.title = "About Better"
        window.isReleasedWhenClosed = false
        window.contentViewController = hostingController
        window.level = .floating
        window.styleMask.insert(.utilityWindow)
        window.standardWindowButton(.zoomButton)?.isEnabled = false
        window.standardWindowButton(.miniaturizeButton)?.isEnabled = false
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(aboutWindowWillClose(_:)),
            name: NSWindow.willCloseNotification,
            object: window
        )
        aboutWindow = window
    }

    @objc
    private func aboutWindowWillClose(_ notification: Notification) {
        aboutWindow = nil
    }

    private func registerHotKey() {
        let keyCode = UInt32(kVK_ANSI_V)
        let modifiers = UInt32(cmdKey | shiftKey)
        HotKeyCenter.shared.register(keyCode: keyCode, modifiers: modifiers) { [weak self] in
            guard let self else { return }
            if self.windows.contains(where: { $0.window.isVisible }) {
                self.closeWindows()
            } else {
                self.showWindows()
            }
        }
    }

    private func createWindow(for entry: TransformedText) -> (NSWindow, NSHostingController<ClipboardEntry>) {
        let hostingController = NSHostingController(
            rootView: ClipboardEntry(entry: entry, isFrontMost: false)
        )
        let window = NSWindow(
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
        let hostingView = makeHostingView(container: container, hostingController: hostingController)
        container.addSubview(blurView)
        container.addSubview(hostingView)
        window.contentView = container
        return (window, hostingController)
    }

    private func makeBlurView(container: NSView) -> NSVisualEffectView {
        let view = NSVisualEffectView(frame: container.bounds)
        view.autoresizingMask = [.width, .height]
        view.blendingMode = .behindWindow
        view.material = .hudWindow
        view.state = .active
        view.isEmphasized = true
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
        var belowStack: [(window: NSWindow, host: NSHostingController<ClipboardEntry>, entry: TransformedText, baseIndex: Int)] = []
        var aboveStack: [(window: NSWindow, host: NSHostingController<ClipboardEntry>, entry: TransformedText, baseIndex: Int)] = []
        if windows.count > 1 {
            for idx in 1..<windows.count {
                let (window, host) = windows[idx]
                let entry = entries[idx]
                guard let baseIndex = entryIndexLookup[entry.id] else {
                    continue
                }
                if baseIndex > frontIndex {
                    belowStack.append((window, host, entry, baseIndex))
                } else if baseIndex < frontIndex {
                    aboveStack.append((window, host, entry, baseIndex))
                }
            }
        }
        belowStack.sort { $0.baseIndex < $1.baseIndex }
        aboveStack.sort { $0.baseIndex > $1.baseIndex }
        var updates: [(window: NSWindow, host: NSHostingController<ClipboardEntry>, frame: NSRect, alpha: CGFloat, entry: TransformedText, isFront: Bool)] = []
        func recordUpdate(window: NSWindow, host: NSHostingController<ClipboardEntry>, entry: TransformedText, depth: Int, offsetY: CGFloat, isFront: Bool) {
            let scale = max(1.0 - CGFloat(depth) * SCALE_STEP, 0.3)
            let opacity = depth > 3 ? 0.0 : 1.0 - CGFloat(depth) * OPACITY_STEP
            let windowSize = NSSize(width: baseSize.width * scale, height: baseSize.height * scale)
            let origin = NSPoint(
                x: centerPoint.x - windowSize.width / 2,
                y: centerPoint.y - windowSize.height / 2 + offsetY
            )
            let frame = NSRect(origin: origin, size: windowSize)
            window.contentMinSize = windowSize
            window.contentMaxSize = windowSize
            host.rootView = ClipboardEntry(entry: entry, isFrontMost: isFront)
            if let tintView = window.contentView?.subviews.first(where: { $0.identifier == NSUserInterfaceItemIdentifier("tint") }) {
                tintView.layer?.backgroundColor = NSColor(calibratedWhite: 1.0, alpha: isFront ? 0.08 : 0.22).cgColor
            }
            updates.append((window, host, frame, opacity, entry, isFront))
        }
        if let (frontWindow, frontHost) = windows.first {
            recordUpdate(window: frontWindow, host: frontHost, entry: frontEntry, depth: 0, offsetY: 0, isFront: true)
        }
        var belowOffset: CGFloat = 0
        for (position, element) in belowStack.enumerated() {
            let multiplier = position == 0 ? 1.0 : pow(OFFSET_DECAY, CGFloat(position))
            belowOffset -= CGFloat(OFFSET_STEP) * multiplier
            recordUpdate(window: element.window, host: element.host, entry: element.entry, depth: position + 1, offsetY: belowOffset, isFront: false)
        }
        var aboveOffset: CGFloat = 0
        for (position, element) in aboveStack.enumerated() {
            let multiplier = position == 0 ? 1.0 : pow(OFFSET_DECAY, CGFloat(position))
            aboveOffset += CGFloat(OFFSET_STEP) * multiplier
            recordUpdate(window: element.window, host: element.host, entry: element.entry, depth: position + 1, offsetY: aboveOffset, isFront: false)
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
        var stackingOrder: [NSWindow] = []
        if let (frontWindow, _) = windows.first {
            stackingOrder.append(frontWindow)
        }
        for item in belowStack {
            stackingOrder.append(item.window)
        }
        for item in aboveStack {
            stackingOrder.append(item.window)
        }
        for (index, win) in stackingOrder.enumerated() {
            if index == 0 {
                win.makeKeyAndOrderFront(nil)
            } else {
                win.order(.below, relativeTo: stackingOrder[index - 1].windowNumber)
            }
        }
    }

    private func installEventMonitors() {
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
            case UInt16(ESCAPE_KEY_CODE):
                self.closeWindows()
                return nil
            case RETURN_KEY_CODE:
                self.handlePasteFrontEntry()
                return nil
            case UInt16(kVK_ANSI_R):
                if event.modifierFlags.contains(.command) {
                    self.triggerRewriteShortcut()
                    return nil
                }
                return event
            default:
                return event
            }
        }
        scrollMonitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { [weak self] event in
            guard let self else { return event }
            guard !self.windows.isEmpty else {
                return event
            }
            let now = ProcessInfo.processInfo.systemUptime
            let cooldown: TimeInterval = 0.5
            if now - self.lastScrollEventTime < cooldown {
                return nil
            }
            if abs(event.scrollingDeltaY) > 2.5 {
                if event.scrollingDeltaY > 0 {
                    self.rotateWheel(direction: .newer)
                    self.lastScrollEventTime = now
                    return nil
                } else if event.scrollingDeltaY < 0 {
                    self.rotateWheel(direction: .older)
                    self.lastScrollEventTime = now
                    return nil
                }
            }
            return event
        }
    }

    private func triggerRewriteShortcut() {
        guard let frontEntry = entries.first else { return }
        NotificationCenter.default.post(name: .rewriteFrontEntryRequested, object: frontEntry.id)
    }

    private func paste(_ string: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(string, forType: .string)
        if let lastApp = lastActiveApp {
            _ = lastApp.activate(options: [.activateAllWindows])
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                let src = CGEventSource(stateID: .combinedSessionState)
                let keyVDown = CGEvent(keyboardEventSource: src, virtualKey: CGKeyCode(kVK_ANSI_V), keyDown: true)
                let keyVUp = CGEvent(keyboardEventSource: src, virtualKey: CGKeyCode(kVK_ANSI_V), keyDown: false)
                keyVDown?.flags = .maskCommand
                keyVUp?.flags = .maskCommand
                let loc = CGEventTapLocation.cghidEventTap
                keyVDown?.post(tap: loc)
                keyVUp?.post(tap: loc)
            }
        }
        lastActiveApp = nil
    }

    private func handlePasteFrontEntry() {
        guard let (frontWindow, _) = windows.first,
              let frontEntry = entries.first else {
            closeWindows()
            return
        }
        paste(frontEntry.original)
        if windows.count > 1 {
            for (window, _) in windows.dropFirst() {
                window.orderOut(nil)
                window.close()
            }
            if let first = windows.first {
                windows = [first]
                entries = [frontEntry]
            } else {
                windows = []
                entries = []
            }
        }
        layoutWindows(animated: false)
        presentCopyOverlay(on: frontWindow)
    }

    private func presentCopyOverlay(on window: NSWindow) {
        guard let container = window.contentView else {
            closeWindows()
            return
        }
        let overlaySize = NSSize(width: 220, height: 90)
        let overlay = NSVisualEffectView(frame: NSRect(origin: .zero, size: overlaySize))
        overlay.translatesAutoresizingMaskIntoConstraints = false
        overlay.blendingMode = .withinWindow
        overlay.material = .popover
        overlay.state = .active
        overlay.isEmphasized = true
        overlay.wantsLayer = true
        overlay.layer?.cornerRadius = 22
        overlay.layer?.masksToBounds = true
        overlay.alphaValue = 0
        let label = NSTextField(labelWithString: "Pasted!")
        label.font = NSFont.systemFont(ofSize: 22, weight: .semibold)
        label.alignment = .center
        label.textColor = .labelColor
        label.translatesAutoresizingMaskIntoConstraints = false
        overlay.addSubview(label)
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: overlay.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: overlay.centerYAnchor)
        ])
        container.addSubview(overlay)
        NSLayoutConstraint.activate([
            overlay.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            overlay.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            overlay.widthAnchor.constraint(equalToConstant: overlaySize.width),
            overlay.heightAnchor.constraint(equalToConstant: overlaySize.height)
        ])
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.15
            overlay.animator().alphaValue = 1
        })
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) { [weak self] in
            NSAnimationContext.runAnimationGroup({ context in
                context.duration = 0.2
                overlay.animator().alphaValue = 0
            }, completionHandler: {
                overlay.removeFromSuperview()
                Task { @MainActor in
                    self?.closeWindows()
                }
            })
        }
    }

    private func rotateWheel(direction: RotationDirection) {
        guard windows.count > 1,
              windows.count == entries.count else {
            return
        }
        guard let frontEntry = entries.first,
              let frontIndex = entryIndexLookup[frontEntry.id] else {
            return
        }
        switch direction {
        case .older:
            if frontIndex >= baseHistory.count - 1 {
                return
            }
            let winTuple = windows.removeFirst()
            let entry = entries.removeFirst()
            windows.append(winTuple)
            entries.append(entry)
        case .newer:
            if frontIndex <= 0 {
                return
            }
            let winTuple = windows.removeLast()
            let entry = entries.removeLast()
            windows.insert(winTuple, at: 0)
            entries.insert(entry, at: 0)
        }
        layoutWindows(animated: true)
    }
}
