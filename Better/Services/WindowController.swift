//
//  WindowController.swift
//  Better
//
//  Created by Diego Rivera on 2/11/25.
//

import SwiftUI
import AppKit
import Carbon.HIToolbox
import Combine

private let escapeKeyCode: Int = 53
private let returnKeyCode: UInt16 = 36
private let cornerRadius: CGFloat = 24
private let offsetStep: Int = 110
private let offsetDecay: CGFloat = 0.6
private let opacityStep: CGFloat = 0.2
private let scaleStep: CGFloat = 0.1
private let windowSize = NSSize(width: 500, height: 350)
private let statusOverlayBarSize = NSSize(width: 360, height: 48)

@MainActor
final class WindowController: NSObject, NSMenuItemValidation {
    private let statusItem: NSStatusItem
    private let clipboard: ClipboardController
    private var windows: [(window: NSWindow, host: NSHostingController<ClipboardEntry>)] = []
    private var entries: [CopiedText] = []
    private var baseHistory: [CopiedText] = []
    private var entryIndexLookup: [UUID: Int] = [:]
    private var keyMonitor: Any?
    private var scrollMonitor: Any?
    private var resignActiveObserver: Any?
    private var deleteRequestObserver: Any?
    private var lastScrollEventTime: TimeInterval = 0
    private var aboutWindow: NSWindow?
    private var lastActiveApp: NSRunningApplication?
    private var statusOverlayBar: NSWindow?
    private var statusOverlayHostingController: NSHostingController<StatusOverlayBar>?
    private let statusOverlayContext = StatusOverlayContext()
    private var statusOverlaySearchObserver: AnyCancellable?
    private var hasPresentedInitialWindows = false

    private var showingWindows: Bool {
        windows.contains(where: { $0.window.isVisible })
    }

    private var searchText: String = ""
    private var filteredEntries: [CopiedText] {
        let lowercasedSearch = searchText.lowercased()
        if lowercasedSearch.isEmpty {
            return baseHistory
        }
        return baseHistory.filter { entry in
            entry.original.lowercased().contains(lowercasedSearch)
        }
    }

    private lazy var toggleMenuItem: NSMenuItem = {
        let item = NSMenuItem(
            title: "",
            action: #selector(toggleWindow(_:)),
            keyEquivalent: "v"
        )
        item.keyEquivalentModifierMask = [.command, .shift]
        item.target = self
        item.image = NSImage(systemSymbolName: "sparkles.rectangle.stack.fill", accessibilityDescription: nil)
        return item
    }()

    private lazy var clearItem: NSMenuItem = {
        let item = NSMenuItem(
            title: "Clear Clipboard History",
            action: #selector(clearClipboardHistoryAction(_:)),
            keyEquivalent: ""
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
        super.init()
        configureStatusItem()
        registerHotKey()
        statusOverlayContext.setSearchTextIfNeeded(searchText)
        statusOverlaySearchObserver = statusOverlayContext.$searchText
            .removeDuplicates()
            .debounce(for: .seconds(1), scheduler: RunLoop.main)
            .receive(on: RunLoop.main)
            .sink { [weak self] newValue in
                self?.handleSearchTextChange(newValue)
            }
        deleteRequestObserver = NotificationCenter.default.addObserver(
            forName: .deleteFrontEntryRequested,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self else { return }
            let entryID = notification.object as? UUID
            Task { @MainActor in
                self.deleteFrontEntry(requestedID: entryID)
            }
        }
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
        if let observer = deleteRequestObserver {
            NotificationCenter.default.removeObserver(observer)
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

    func presentInitialWindowsIfNeeded() {
        guard hasPresentedInitialWindows == false else {
            return
        }
        hasPresentedInitialWindows = true
        showWindows(presentEmptyAlert: false, captureLastApp: false)
    }

    private func showWindows(presentEmptyAlert: Bool = true, captureLastApp: Bool = true) {
        if captureLastApp {
            lastActiveApp = NSWorkspace.shared.frontmostApplication
        }
        closeWindows()
        let history = clipboard.history
        guard !history.isEmpty else {
            if presentEmptyAlert {
                presentEmptyClipboardAlert()
            }
            return
        }
        baseHistory = history
        entryIndexLookup = Dictionary(uniqueKeysWithValues: history.enumerated().map { ($0.element.id, $0.offset) })
        entries = filteredEntries
        windows = filteredEntries.map { createWindow(for: $0) }
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
        hideStatusOverlayBar()
        updateToggleMenuTitle()
    }

    private func presentEmptyClipboardAlert() {
        let alert = NSAlert()
        alert.messageText = "Clipboard is Empty"
        alert.informativeText = "Copy something first to see it here."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        if let window = NSApp.keyWindow {
            alert.beginSheetModal(for: window)
        } else {
            alert.runModal()
        }
    }

    private func deleteFrontEntry(requestedID: UUID? = nil) {
        guard let frontEntry = entries.first else {
            return
        }
        if let requestedID, requestedID != frontEntry.id {
            return
        }
        self.deleteFrontEntry(frontEntry)
    }

    private func deleteFrontEntry(_ entry: CopiedText) {
        guard !windows.isEmpty else {
            clipboard.removeEntry(with: entry.id)
            return
        }
        let frontPair = windows.removeFirst()
        let frontWindow = frontPair.window
        entries.removeFirst()
        clipboard.removeEntry(with: entry.id)
        animateRemoval(of: frontWindow) { [weak self] in
            guard let self else { return }
            self.windows = self.windows.filter { $0.window != frontWindow }
            if self.clipboard.history.isEmpty {
                self.closeWindows()
            } else {
                self.baseHistory = self.clipboard.history
                self.entries = self.filteredEntries
                self.windows = self.filteredEntries.map { self.createWindow(for: $0) }
                self.layoutWindows(animated: true)
            }
        }
    }

    private func configureStatusItem() {
        guard let button = statusItem.button else {
            return
        }
        button.image = NSImage(systemSymbolName: "sparkles.rectangle.stack.fill",
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
        let processConfirmation: () -> Void = { [weak self] in
            _ = self
            self?.clipboard.history = []
            self?.clipboard.saveHistory()
            self?.closeWindows()
        }
        if let window = NSApp.keyWindow {
            alert.beginSheetModal(for: window) { response in
                guard response == .alertFirstButtonReturn else {
                    return
                }
                processConfirmation()
            }
        } else {
            let response = alert.runModal()
            if response == .alertFirstButtonReturn {
                processConfirmation()
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
            guard let self else {
                return
            }
            if self.windows.contains(where: { $0.window.isVisible }) {
                self.closeWindows()
            } else {
                self.showWindows()
            }
        }
    }
    
    private func handleEntryUpdate(id: UUID, text: String) {
        clipboard.updateRewritten(for: id, value: text)
        if let idx = entries.firstIndex(where: { $0.id == id }) {
            entries[idx].updateRewritten(text)
        }
        if let idx = baseHistory.firstIndex(where: { $0.id == id }) {
            baseHistory[idx].updateRewritten(text)
        }
        clipboard.saveHistory()
    }

    private func createWindow(for entry: CopiedText) -> (NSWindow, NSHostingController<ClipboardEntry>) {
        let hostingController = NSHostingController(
            rootView: ClipboardEntry(entry: entry,
                                     isFrontMost: false,
                                     onChange: { [weak self] id, text in
                                         self?.handleEntryUpdate(id: id, text: text)
                                     })
        )
        let window = FloatingClipboardWindow(
            contentRect: NSRect(origin: .zero, size: windowSize),
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
        let container = NSView(frame: NSRect(origin: .zero, size: windowSize))
        container.wantsLayer = true
        container.layer?.cornerRadius = cornerRadius
        container.layer?.masksToBounds = true
        let blurView = makeBlurView(container: container)
        let hostingView = makeHostingView(container: container, hostingController: hostingController)
        container.addSubview(blurView)
        container.addSubview(hostingView)
        window.contentView = container
        return (window, hostingController)
    }

    private func closeWindowPairs(_ windowPairs: [(window: NSWindow, host: NSHostingController<ClipboardEntry>)]) {
        for (window, _) in windowPairs {
            window.orderOut(nil)
            window.close()
        }
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

    private func makeHostingView<Content: View>(container: NSView,
                                                hostingController: NSHostingController<Content>) -> NSView {
        let view = hostingController.view
        view.frame = container.bounds
        view.autoresizingMask = [.width, .height]
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.clear.cgColor
        view.layer?.cornerRadius = cornerRadius
        view.layer?.masksToBounds = true
        return view
    }

    private func animateRemoval(of window: NSWindow, completion: @escaping () -> Void) {
        guard window.contentView != nil else {
            completion()
            return
        }
        let newFrame = window.frame.offsetBy(dx: 0, dy: -40)
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.18
            window.animator().alphaValue = 0
            window.animator().setFrame(newFrame, display: true)
        }, completionHandler: {
            window.orderOut(nil)
            window.close()
            completion()
        })
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
        let screenFrame = screen.visibleFrame
        let centerPoint = NSPoint(x: screenFrame.midX, y: screenFrame.midY)
        var belowStack: [(window: NSWindow, host: NSHostingController<ClipboardEntry>, entry: CopiedText, baseIndex: Int)] = []
        var aboveStack: [(window: NSWindow, host: NSHostingController<ClipboardEntry>, entry: CopiedText, baseIndex: Int)] = []
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
        var updates: [(window: NSWindow, host: NSHostingController<ClipboardEntry>, frame: NSRect, alpha: CGFloat, entry: CopiedText, isFront: Bool)] = []
        var frontFrame: NSRect?
        var frontWindowReference: NSWindow?
        func recordUpdate(window: NSWindow, host: NSHostingController<ClipboardEntry>, entry: CopiedText, depth: Int, offsetY: CGFloat, isFront: Bool) {
            let scale = max(1.0 - CGFloat(depth) * scaleStep, 0.3)
            let opacity = depth > 3 ? 0.0 : 1.0 - CGFloat(depth) * opacityStep
            let windowSize = NSSize(width: windowSize.width * scale, height: windowSize.height * scale)
            let origin = NSPoint(
                x: centerPoint.x - windowSize.width / 2,
                y: centerPoint.y - windowSize.height / 2 + offsetY
            )
            let frame = NSRect(origin: origin, size: windowSize)
            window.contentMinSize = windowSize
            window.contentMaxSize = windowSize
            host.rootView = ClipboardEntry(entry: entry,
                                           isFrontMost: isFront,
                                           onChange: { [weak self] id, text in
                                                self?.handleEntryUpdate(id: id, text: text)
                                            })
            if let tintView = window.contentView?.subviews.first(where: { $0.identifier == NSUserInterfaceItemIdentifier("tint") }) {
                tintView.layer?.backgroundColor = NSColor(calibratedWhite: 1.0, alpha: isFront ? 0.08 : 0.22).cgColor
            }
            updates.append((window, host, frame, opacity, entry, isFront))
            if isFront {
                frontFrame = frame
            }
        }
        if let (frontWindow, frontHost) = windows.first {
            frontWindowReference = frontWindow
            recordUpdate(window: frontWindow, host: frontHost, entry: frontEntry, depth: 0, offsetY: 0, isFront: true)
        }
        var belowOffset: CGFloat = 0
        for (position, element) in belowStack.enumerated() {
            let multiplier = position == 0 ? 1.0 : pow(offsetDecay, CGFloat(position))
            belowOffset -= CGFloat(offsetStep) * multiplier
            recordUpdate(window: element.window, host: element.host, entry: element.entry, depth: position + 1, offsetY: belowOffset, isFront: false)
        }
        var aboveOffset: CGFloat = 0
        for (position, element) in aboveStack.enumerated() {
            let multiplier = position == 0 ? 1.0 : pow(offsetDecay, CGFloat(position))
            aboveOffset += CGFloat(offsetStep) * multiplier
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
        if let frame = frontFrame,
           let reference = frontWindowReference {
            updateStatusOverlayBar(frontFrame: frame,
                                   referenceWindow: reference,
                                   screenFrame: screenFrame,
                                   frontIndex: frontIndex,
                                   totalCount: entries.count,
                                   animated: animated)
        } else {
            hideStatusOverlayBar()
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
        let shouldPreserveOverlayFocus = statusOverlayBar?.isKeyWindow == true
        for (index, win) in stackingOrder.enumerated() {
            if index == 0 {
                if shouldPreserveOverlayFocus {
                    win.orderFront(nil)
                } else {
                    win.makeKeyAndOrderFront(nil)
                }
            } else {
                win.order(.below, relativeTo: stackingOrder[index - 1].windowNumber)
            }
        }
        if shouldPreserveOverlayFocus {
            statusOverlayBar?.makeKeyAndOrderFront(nil)
        }
    }

    private func statusOverlayComponents() -> (NSWindow, NSHostingController<StatusOverlayBar>) {
        if let window = statusOverlayBar,
           let host = statusOverlayHostingController {
            return (window, host)
        }
        let host = NSHostingController(
            rootView: StatusOverlayBar(
                context: statusOverlayContext,
                onWrapToFirst: { [weak self] in
                    self?.wrapToFirstEntry()
                }
            )
        )
        let panel = StatusOverlayWindow(
            contentRect: NSRect(origin: .zero, size: statusOverlayBarSize),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = false
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.ignoresMouseEvents = false
        panel.isReleasedWhenClosed = false
        panel.contentViewController = host
        let container = NSView(frame: NSRect(origin: .zero, size: statusOverlayBarSize))
        container.wantsLayer = true
        container.layer?.cornerRadius = cornerRadius
        container.layer?.masksToBounds = true
        let blurView = makeBlurView(container: container)
        let hostingView = makeHostingView(container: container, hostingController: host)
        container.addSubview(blurView)
        container.addSubview(hostingView)
        panel.contentView = container
        panel.setFrame(NSRect(origin: .zero, size: statusOverlayBarSize), display: true)
        statusOverlayContext.update(index: 1, total: max(entries.count, 1))
        statusOverlayContext.setSearchTextIfNeeded(searchText)
        statusOverlayBar = panel
        statusOverlayHostingController = host
        return (panel, host)
    }

    private func updateStatusOverlayBar(
        frontFrame: NSRect,
        referenceWindow: NSWindow,
        screenFrame: NSRect,
        frontIndex: Int,
        totalCount: Int,
        animated: Bool
    ) {
        guard totalCount > 0 else {
            hideStatusOverlayBar()
            return
        }
        let displayIndex = min(max(frontIndex + 1, 1), totalCount)
        let (window, host) = statusOverlayComponents()
        statusOverlayContext.update(index: displayIndex, total: totalCount)
        statusOverlayContext.setSearchTextIfNeeded(searchText)
        host.view.frame = NSRect(origin: .zero, size: statusOverlayBarSize)
        let horizontalPadding: CGFloat = 16
        var origin = NSPoint(x: frontFrame.midX - statusOverlayBarSize.width / 2,
                             y: frontFrame.maxY + 40)
        origin.x = min(max(origin.x, screenFrame.minX + horizontalPadding),
                       screenFrame.maxX - statusOverlayBarSize.width - horizontalPadding)
        origin.y = min(origin.y, screenFrame.maxY - statusOverlayBarSize.height - horizontalPadding)
        let frame = NSRect(origin: origin, size: statusOverlayBarSize)
        let targetLevel = NSWindow.Level(rawValue: referenceWindow.level.rawValue + 1)
        if window.level != targetLevel {
            window.level = targetLevel
        }
        window.animationBehavior = .utilityWindow
        func placeWindow() {
            if animated {
                NSAnimationContext.runAnimationGroup { context in
                    context.duration = 0.25
                    context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                    window.animator().setFrame(frame, display: true)
                }
            } else {
                window.setFrame(frame, display: true, animate: false)
            }
        }
        if window.isVisible == false {
            window.alphaValue = 0
            window.setFrame(frame, display: true)
            window.order(.above, relativeTo: referenceWindow.windowNumber)
            NSAnimationContext.runAnimationGroup({ context in
                context.duration = 0.18
                context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                window.animator().alphaValue = 1
            })
            return
        }
        placeWindow()
        window.order(.above, relativeTo: referenceWindow.windowNumber)
    }

    private func hideStatusOverlayBar() {
        guard let window = statusOverlayBar else {
            return
        }
        if window.isVisible {
            window.orderOut(nil)
        }
    }

    private func installEventMonitors() {
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else {
                return event
            }
            guard !self.windows.isEmpty else {
                return event
            }
            if event.keyCode == UInt16(kVK_UpArrow),
               event.modifierFlags.contains(.command) {
                NotificationCenter.default.post(name: .wrapToFirstEntryRequested, object: nil)
                return nil
            }
            switch event.keyCode {
            case UInt16(kVK_DownArrow):
                self.rotateWheel(direction: .older)
                return nil
            case UInt16(kVK_UpArrow):
                self.rotateWheel(direction: .newer)
                return nil
            case UInt16(kVK_Delete):
                if event.modifierFlags.contains(.command) {
                    self.deleteFrontEntry()
                    return nil
                }
                return event
            case UInt16(escapeKeyCode):
                if self.clearSearchTextIfNeeded() == false {
                    self.closeWindows()
                }
                return nil
            case returnKeyCode:
                self.handlePasteFrontEntry()
                return nil
            case UInt16(kVK_ANSI_R):
                if event.modifierFlags.contains(.command) {
                    self.triggerRewriteShortcut()
                    return nil
                }
                return event
            case UInt16(kVK_ANSI_F):
                if event.modifierFlags.contains(.command) {
                    self.triggerSearchShortcut()
                    return nil
                }
                return event
            default:
                return event
            }
        }
        scrollMonitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { [weak self] event in
            guard let self else {
                return event
            }
            guard !self.windows.isEmpty else {
                return event
            }
            if self.shouldAllowScrollForEditor(event: event) {
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

    private func shouldAllowScrollForEditor(event: NSEvent) -> Bool {
        guard let window = event.window else {
            return false
        }
        guard windows.contains(where: { $0.window == window }) else {
            return false
        }
        guard let hitView = window.contentView?.hitTest(event.locationInWindow) else {
            return false
        }
        return hitView.isDescendantOfScrollableEditor
    }

    private func triggerRewriteShortcut() {
        guard let frontEntry = entries.first else {
            return
        }
        NotificationCenter.default.post(name: .rewriteFrontEntryRequested, object: frontEntry.id)
    }

    private func triggerSearchShortcut() {
        guard showingWindows else {
            return
        }
        _ = statusOverlayComponents()
        statusOverlayBar?.makeKeyAndOrderFront(nil)
        NotificationCenter.default.post(name: .searchEntriesRequested, object: nil)
    }

    private func handleSearchTextChange(_ newValue: String) {
        guard searchText != newValue else {
            return
        }
        searchText = newValue
        let previousWindows = windows
        entries = filteredEntries
        windows = filteredEntries.map { createWindow(for: $0) }
        closeWindowPairs(previousWindows)
        layoutWindows(animated: false)
        updateToggleMenuTitle()
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
        overlay.layer?.cornerRadius = cornerRadius
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

    private func wrapToFirstEntry() {
        guard windows.count > 1,
              windows.count == entries.count else {
            return
        }
        guard let targetIndex = entries.firstIndex(where: { entryIndexLookup[$0.id] == 0 }),
              targetIndex != 0 else {
            return
        }
        let headEntries = Array(entries[targetIndex...])
        let tailEntries = Array(entries[..<targetIndex])
        entries = headEntries + tailEntries
        let headWindows = Array(windows[targetIndex...])
        let tailWindows = Array(windows[..<targetIndex])
        windows = headWindows + tailWindows
        layoutWindows(animated: true)
    }

    @discardableResult
    private func clearSearchTextIfNeeded() -> Bool {
        let trimmed = statusOverlayContext.searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false else {
            return false
        }
        statusOverlayContext.setSearchTextIfNeeded("")
        handleSearchTextChange("")
        return true
    }
}

private extension NSView {
    var isDescendantOfScrollableEditor: Bool {
        var current: NSView? = self
        while let view = current {
            if let scrollView = view as? NSScrollView,
               scrollView.hasVerticalScroller {
                return true
            }
            current = view.superview
        }
        return false
    }
}

private final class FloatingClipboardWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

private final class StatusOverlayWindow: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

extension WindowController {
    @objc func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        if menuItem == clearItem {
            return !clipboard.history.isEmpty
        }
        return true
    }
}
