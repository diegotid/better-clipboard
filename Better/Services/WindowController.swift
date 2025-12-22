//
//  WindowController.swift
//  Better
//
//  Created by Diego Rivera on 2/11/25.
//

import SwiftUI
import Carbon.HIToolbox
import Combine
import QuartzCore
import StoreKit
internal import AppKit

private let escapeKeyCode: Int = 53
private let returnKeyCode: UInt16 = 36
private let cornerRadius: CGFloat = 24
private let offsetStep: Int = 110
private let offsetDecay: CGFloat = 0.6
private let opacityStep: CGFloat = 0.2
private let scaleStep: CGFloat = 0.1
private let windowSize = NSSize(width: 500, height: 350)
private let statusOverlayHeight: Int = 48
private let statusOverlayWidth: Int = 500
private let statusSideControlWidth: Int = 72

@MainActor
final class WindowController: NSObject, NSMenuItemValidation {
    private let statusBarItem: NSStatusItem
    private let clipboard: ClipboardController
    private let translator: Translator
    private var windows: [(window: NSWindow, host: NSHostingController<AnyView>)] = []
    private var entries: [CopiedContent] = []
    private var baseHistory: [CopiedContent] = []
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
    private var statusOverlaySearchObserver: AnyCancellable?
    private var statusOverlayFilterObserver: AnyCancellable?
    private var statusOverlaySearchImmediateObserver: AnyCancellable?
    private var settingsPopover: NSPopover?
    private var proPopover: NSPopover?
    private let purchaseManager = PurchaseManager()
    private let statusOverlayContext = StatusOverlayContext()
    private let languageContext = LanguageContext()
    private var hasPresentedInitialWindows = false
    private var searchText: String = ""
    private var entriesUpdateResetTask: DispatchWorkItem?
    private var showingWindows: Bool {
        windows.contains(where: { $0.window.isVisible })
    }
    private var filteredEntries: [CopiedContent] {
        let lowercasedSearch = searchText.lowercased()
        let base = statusOverlayContext.filterPinned ? baseHistory.filter { $0.isPinned } : baseHistory
        guard !lowercasedSearch.isEmpty else {
            return base
        }
        return base.filter { entry in
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
    
    private lazy var settingsItem: NSMenuItem = {
        let item = NSMenuItem(
            title: "Settings…",
            action: #selector(showSettings(_:)),
            keyEquivalent: ","
        )
        item.keyEquivalentModifierMask = [.command]
        item.target = self
        item.image = NSImage(systemSymbolName: "gearshape", accessibilityDescription: nil)
        return item
    }()
    
    private lazy var restorePurchasesItem: NSMenuItem = {
        let item = NSMenuItem(
            title: "Restore Purchases",
            action: #selector(restorePurchases(_:)),
            keyEquivalent: ""
        )
        item.target = self
        item.image = NSImage(systemSymbolName: "arrow.clockwise", accessibilityDescription: nil)
        return item
    }()
    
    private lazy var aboutMenuItem: NSMenuItem = {
        let item = NSMenuItem(
            title: "About Better Clipboard",
            action: #selector(showAboutWindow(_:)),
            keyEquivalent: ""
        )
        item.target = self
        item.image = NSImage(systemSymbolName: "info.circle", accessibilityDescription: nil)
        return item
    }()
    
    private lazy var quitItem: NSMenuItem = {
        let item = NSMenuItem(
            title: "Quit Better Clipboard",
            action: #selector(quitAction(_:)),
            keyEquivalent: "q"
        )
        item.target = self
        item.image = NSImage(systemSymbolName: "power", accessibilityDescription: nil)
        return item
    }()
    
    init(clipboard: ClipboardController) async {
        self.clipboard = clipboard
        self.translator = Translator()
        statusBarItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        super.init()
        configureStatusBarItem()
        registerHotKey()
        statusOverlayContext.setSearchTextIfNeeded(searchText)
        statusOverlaySearchImmediateObserver = statusOverlayContext.$searchText
            .dropFirst()
            .removeDuplicates()
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.beginEntriesUpdate()
            }
        statusOverlaySearchObserver = statusOverlayContext.$searchText
            .removeDuplicates()
            .debounce(for: .seconds(1), scheduler: RunLoop.main)
            .receive(on: RunLoop.main)
            .sink { [weak self] newValue in
                self?.handleSearchTextChange(newValue)
            }
        statusOverlayFilterObserver = statusOverlayContext.$filterPinned
            .removeDuplicates()
            .receive(on: RunLoop.main)
            .sink { [weak self] newValue in
                self?.handleFilterPinnedChange(newValue)
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
        _ = NotificationCenter.default.addObserver(
            forName: .toggleEntryPinnedRequested,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 10_000_000) // 0.01 seconds
                self.refreshEntriesAfterPinToggle()
            }
        }
        resignActiveObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didResignActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                self.hideSettingsPopover()
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
        MainActor.assumeIsolated {
            settingsPopover?.close()
            proPopover?.close()
            aboutWindow?.close()
        }
    }
    
    func presentInitialWindowsIfNeeded() {
        guard hasPresentedInitialWindows == false else {
            return
        }
        hasPresentedInitialWindows = true
        showWindows(presentEmptyAlert: false, captureLastApp: false)
    }
}

private extension WindowController {
    enum RotationDirection {
        case older
        case newer
    }

    @objc
    func toggleWindow(_ sender: Any?) {
        if showingWindows {
            closeWindows()
        } else {
            showWindows()
        }
    }
    
    func pasteFrontMost() {
        guard let _ = windows.first,
              let frontEntry = entries.first else {
            closeWindows()
            return
        }
        paste(entry: frontEntry)
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
    }
    
    func handleCopyEntry(_ final: String) {
        copy(final)
    }
    
    func updateBaseHistory(_ history: [CopiedContent]) {
        baseHistory = history
        entryIndexLookup = Dictionary(uniqueKeysWithValues: history.enumerated().map {
            ($0.element.id, $0.offset)
        })
    }

    func showWindows(presentEmptyAlert: Bool = true, captureLastApp: Bool = true) {
        if captureLastApp {
            lastActiveApp = NSWorkspace.shared.frontmostApplication
        }
        if let aboutWin = aboutWindow {
            aboutWin.orderOut(nil)
        }
        closeWindows()
        let history = clipboard.history
        guard !history.isEmpty else {
            if presentEmptyAlert {
                presentEmptyClipboardAlert()
            }
            return
        }
        updateBaseHistory(history)
        entries = filteredEntries
        if entries.isEmpty && !history.isEmpty {
            searchText = ""
            statusOverlayContext.searchText = ""
            entries = filteredEntries
        }
        windows = filteredEntries.map { createWindow(for: $0) }
        layoutWindows(animated: false)
        installEventMonitors()
        NSApp.activate(ignoringOtherApps: true)
        updateToggleMenuTitle()
    }

    func closeWindows() {
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
        entriesUpdateResetTask?.cancel()
        statusOverlayContext.setUpdatingEntries(false)
        hideStatusOverlayBar()
        updateToggleMenuTitle()
    }

    func presentEmptyClipboardAlert() {
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

    func deleteFrontEntry(requestedID: UUID? = nil) {
        guard let frontEntry = entries.first else {
            return
        }
        if let requestedID, requestedID != frontEntry.id {
            return
        }
        self.deleteFrontEntry(frontEntry)
    }

    func deleteFrontEntry(_ entry: CopiedContent) {
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
            self.updateBaseHistory(self.clipboard.history)
            self.windows = self.windows.filter { $0.window != frontWindow }
            let filtered = self.filteredEntries
            let visibleIDs = Set(filtered.map(\.id))
            var retainedWindows: [(window: NSWindow, host: NSHostingController<AnyView>)] = []
            var retainedEntries: [CopiedContent] = []
            for (pair, entry) in zip(self.windows, self.entries) {
                if visibleIDs.contains(entry.id) {
                    retainedWindows.append(pair)
                    retainedEntries.append(entry)
                } else {
                    pair.window.orderOut(nil)
                    pair.window.close()
                }
            }
            let existingIDs = Set(retainedEntries.map(\.id))
            let missingEntries = filtered.filter { !existingIDs.contains($0.id) }
            for entry in missingEntries {
                retainedWindows.append(self.createWindow(for: entry))
                retainedEntries.append(entry)
            }
            self.windows = retainedWindows
            self.entries = retainedEntries
            if self.entries.isEmpty {
                self.closeWindows()
            } else {
                self.layoutWindows(animated: true)
            }
        }
    }

    func configureStatusBarItem() {
        guard let button = statusBarItem.button else {
            return
        }
        button.image = NSImage(systemSymbolName: "sparkles.rectangle.stack.fill",
                               accessibilityDescription: "Better")
        button.image?.isTemplate = true
        let menu = NSMenu()
        menu.addItem(aboutMenuItem)
        menu.addItem(NSMenuItem.separator())
        menu.addItem(toggleMenuItem)
        menu.addItem(clearItem)
        menu.addItem(NSMenuItem.separator())
        menu.addItem(settingsItem)
        menu.addItem(restorePurchasesItem)
        menu.addItem(NSMenuItem.separator())
        menu.addItem(quitItem)
        statusBarItem.menu = menu
        updateToggleMenuTitle()
    }

    func updateToggleMenuTitle() {
        toggleMenuItem.title = showingWindows ? "Hide Clipboard" : "Show Clipboard"
    }

    @objc
    func clearClipboardHistoryAction(_ sender: Any?) {
        let alert = NSAlert()
        alert.messageText = "Clear Clipboard History?"
        alert.informativeText = "This will permanently remove all clipboard items stored by Better. This action cannot be undone."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Clear History")
        alert.addButton(withTitle: "Cancel")
        let processConfirmation: () -> Void = { [weak self] in
            _ = self
            self?.clipboard.history = []
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
    func quitAction(_ sender: Any?) {
        NSApp.terminate(nil)
    }

    @objc
    func showSettings(_ sender: Any?) {
        toggleSettingsPopover()
    }

    @objc
    func restorePurchases(_ sender: Any?) {
        Task {
            var foundEntitlement = false
            for await result in Transaction.currentEntitlements {
                if case .verified(let transaction) = result,
                   transaction.productID == PurchaseManager.unlockProductID {
                    foundEntitlement = true
                    break
                }
            }
            await MainActor.run {
                NotificationCenter.default.post(name: .restorePurchasesRequested, object: nil)
                let alert = NSAlert()
                if foundEntitlement {
                    alert.messageText = "Purchase Restored"
                    alert.informativeText = "Your lifetime unlock has been successfully restored."
                    alert.alertStyle = .informational
                } else {
                    alert.messageText = "No Purchases Found"
                    alert.informativeText = "No previous purchases were found for this Apple ID."
                    alert.alertStyle = .warning
                }
                alert.addButton(withTitle: "OK")
                alert.runModal()
            }
        }
    }

    @objc
    func showPro(_ sender: Any?) {
        toggleProPopover()
    }

    func toggleProPopover() {
        if let popover = proPopover, popover.isShown {
            hideProPopover()
        } else {
            showProPopover()
        }
    }

    func showProPopover() {
        guard let button = statusBarItem.button else {
            return
        }
        hideProPopover()
        let popover = NSPopover()
        popover.behavior = .transient
        popover.animates = true
        popover.contentViewController = NSHostingController(
            rootView: ProPopover(onPurchase: {
                // TODO: Hook up real purchase flow.
                self.hideProPopover()
            })
        )
        proPopover = popover
        popover.show(
            relativeTo: button.bounds,
            of: button,
            preferredEdge: .maxY
        )
        NSApp.activate(ignoringOtherApps: true)
    }

    func hideProPopover() {
        proPopover?.performClose(nil)
        proPopover = nil
    }

    func toggleSettingsPopover() {
        if let popover = settingsPopover, popover.isShown {
            hideSettingsPopover()
        } else {
            showSettingsPopover()
        }
    }

    func showSettingsPopover() {
        guard let button = statusBarItem.button else {
            return
        }
        hideSettingsPopover()
        let popover = NSPopover()
        popover.behavior = .transient
        popover.animates = true
        popover.contentViewController = NSHostingController(
            rootView: SettingsPopover()
                .environmentObject(clipboard)
        )
        settingsPopover = popover
        popover.show(
            relativeTo: button.bounds,
            of: button,
            preferredEdge: .maxY
        )
        NSApp.activate(ignoringOtherApps: true)
    }

    func hideSettingsPopover() {
        settingsPopover?.performClose(nil)
        settingsPopover = nil
    }

    @objc
    func showAboutWindow(_ sender: Any?) {
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
    func aboutWindowWillClose(_ notification: Notification) {
        aboutWindow = nil
    }

    func registerHotKey() {
        let keyCode = UInt32(kVK_ANSI_V)
        let modifiers = UInt32(cmdKey | shiftKey)
        KeyboardListener.shared.register(keyCode: keyCode, modifiers: modifiers) { [weak self] in
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
    
    func handleEntryUpdate(id: UUID, text: String, language: Locale.Language?) {
        clipboard.updateRewritten(for: id, value: text, language: language)
        if let index = entries.firstIndex(where: { $0.id == id }) {
            entries[index].updateRewritten(text)
            entries[index].updateLanguage(language)
        }
        if let index = baseHistory.firstIndex(where: { $0.id == id }) {
            baseHistory[index].updateRewritten(text)
            baseHistory[index].updateLanguage(language)
        }
        clipboard.saveHistory()
    }

    func refreshEntriesAfterPinToggle() {
        guard showingWindows else { return }
        beginEntriesUpdate()
        defer { finishEntriesUpdate() }
        let updatedHistory = clipboard.history
        updateBaseHistory(updatedHistory)
        let filtered = filteredEntries
        let currentIDs = Set(entries.map(\.id))
        let filteredIDs = Set(filtered.map(\.id))
        if currentIDs != filteredIDs {
            let previousWindows = windows
            entries = filtered
            windows = filtered.map { createWindow(for: $0) }
            closeWindowPairs(previousWindows)
            layoutWindows(animated: true)
        } else {
            for (index, entry) in entries.enumerated() {
                if let updatedEntry = filtered.first(where: { $0.id == entry.id }) {
                    entries[index] = updatedEntry
                }
            }
            for (index, pair) in windows.enumerated() {
                if index < entries.count {
                    let updatedEntry = entries[index]
                    let isFrontMost = index == 0
                    let newView = AnyView(
                        ClipboardEntry(
                            entry: updatedEntry,
                            isFrontMost: isFrontMost,
                            onChange: { [weak self] id, text, language in
                                self?.handleEntryUpdate(id: id, text: text, language: language)
                            },
                            onPaste: pasteFrontMost,
                            onCopy: handleCopyEntry,
                            languageContext: languageContext
                        ).environment(\.translator, translator)
                    )
                    pair.host.rootView = newView
                }
            }
            layoutWindows(animated: true)
        }
    }

    func createWindow(for entry: CopiedContent) -> (NSWindow, NSHostingController<AnyView>) {
        let entryView = AnyView(
            ClipboardEntry(
                entry: entry,
                isFrontMost: false,
                onChange: { [weak self] id, text, language in
                    self?.handleEntryUpdate(id: id, text: text, language: language)
                },
                onPaste: pasteFrontMost,
                onCopy: handleCopyEntry,
                languageContext: languageContext
            ).environment(\.translator, translator)
        )
        let hostingController = NSHostingController(rootView: entryView)
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
        let container = FocusableContainer(frame: NSRect(origin: .zero, size: windowSize))
        container.wantsLayer = true
        container.layer?.cornerRadius = cornerRadius
        container.layer?.masksToBounds = true
        let blurView = makeBlurView(container: container)
        let hostingView = makeHostingView(container: container, hostingController: hostingController)
        container.addSubview(blurView)
        container.addSubview(hostingView)
        window.contentView = container
        window.initialFirstResponder = container
        return (window, hostingController)
    }

    func closeWindowPairs(_ windowPairs: [(window: NSWindow, host: NSHostingController<AnyView>)]) {
        for (window, _) in windowPairs {
            window.orderOut(nil)
            window.close()
        }
    }

    func makeBlurView(container: NSView) -> NSVisualEffectView {
        let view = NSVisualEffectView(frame: container.bounds)
        view.autoresizingMask = [.width, .height]
        view.blendingMode = .behindWindow
        view.material = .hudWindow
        view.state = .active
        view.isEmphasized = true
        return view
    }

    func makeHostingView<Content: View>(container: NSView,
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

    func animateRemoval(of window: NSWindow, completion: @escaping () -> Void) {
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

    func layoutWindows(animated: Bool) {
        guard !windows.isEmpty, windows.count == entries.count else {
            if windows.isEmpty {
                statusOverlayContext.update(index: 0, total: 0)
                hideStatusOverlayBar()
            }
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
        var belowStack: [(window: NSWindow, host: NSHostingController<AnyView>, entry: CopiedContent, baseIndex: Int)] = []
        var aboveStack: [(window: NSWindow, host: NSHostingController<AnyView>, entry: CopiedContent, baseIndex: Int)] = []
        if windows.count > 1 {
            for index in 1..<windows.count {
                let (window, host) = windows[index]
                let entry = entries[index]
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
        var updates: [(window: NSWindow, host: NSHostingController<AnyView>, frame: NSRect, alpha: CGFloat, entry: CopiedContent, isFront: Bool)] = []
        var frontFrame: NSRect?
        var frontWindowReference: NSWindow?
        func recordUpdate(window: NSWindow, host: NSHostingController<AnyView>, entry: CopiedContent, depth: Int, offsetY: CGFloat, isFront: Bool) {
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
            host.rootView = AnyView(
                ClipboardEntry(entry: entry,
                               isFrontMost: isFront,
                               onChange: { [weak self] id, text, language in
                                   self?.handleEntryUpdate(id: id,
                                                           text: text,
                                                           language: language)
                               },
                               onPaste: pasteFrontMost,
                               onCopy: handleCopyEntry,
                               languageContext: languageContext)
                .environment(\.translator, translator)
            )
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

    func statusOverlayComponents() -> (NSWindow, NSHostingController<StatusOverlayBar>) {
        if let window = statusOverlayBar,
           let host = statusOverlayHostingController {
            return (window, host)
        }
        let host = NSHostingController(
            rootView: StatusOverlayBar(
                width: statusOverlayWidth,
                onWrapToFirst: { [weak self] in
                    self?.wrapToFirstEntry()
                },
                context: statusOverlayContext
            )
        )
        let size = NSSize(width: statusOverlayWidth, height: statusOverlayHeight)
        let panel = StatusOverlayWindow(
            contentRect: NSRect(origin: .zero, size: size),
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
        panel.becomesKeyOnlyIfNeeded = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.ignoresMouseEvents = false
        panel.isReleasedWhenClosed = false
        panel.contentViewController = host
        let container = NSView(frame: NSRect(origin: .zero, size: size))
        container.wantsLayer = true
        container.layer?.cornerRadius = cornerRadius
        container.layer?.masksToBounds = true
        let blurView = makeBlurView(container: container)
        let hostingView = makeHostingView(container: container, hostingController: host)
        container.addSubview(blurView)
        container.addSubview(hostingView)
        panel.contentView = container
        panel.setFrame(NSRect(origin: .zero, size: size), display: true)
        statusOverlayContext.update(index: 1, total: max(entries.count, 1))
        statusOverlayContext.setSearchTextIfNeeded(searchText)
        statusOverlayBar = panel
        statusOverlayHostingController = host
        return (panel, host)
    }

    func updateStatusOverlayBar(
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
        let actualIndex: Int
        if statusOverlayContext.filterPinned {
            actualIndex = entries.filter { entryIndexLookup[$0.id] ?? Int.max < frontIndex }.count
        } else {
            actualIndex = frontIndex
        }
        let displayIndex = min(max(actualIndex + 1, 1), totalCount)
        let (window, host) = statusOverlayComponents()
        statusOverlayContext.update(index: displayIndex, total: totalCount)
        statusOverlayContext.setSearchTextIfNeeded(searchText)
        let size = NSSize(width: statusOverlayWidth, height: statusOverlayHeight)
        host.view.frame = NSRect(origin: .zero, size: size)
        let horizontalPadding: CGFloat = 16
        var origin = NSPoint(x: frontFrame.midX - CGFloat(statusOverlayWidth) / 2,
                             y: frontFrame.maxY + 40)
        origin.x = min(max(origin.x, screenFrame.minX + horizontalPadding),
                       screenFrame.maxX - CGFloat(statusOverlayWidth) - horizontalPadding)
        origin.y = min(origin.y, screenFrame.maxY - CGFloat(statusOverlayHeight) - horizontalPadding)
        let frame = NSRect(origin: origin, size: size)
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

    func hideStatusOverlayBar() {
        guard let window = statusOverlayBar else {
            return
        }
        if window.isVisible {
            window.orderOut(nil)
        }
    }

    func installEventMonitors() {
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else {
                return event
            }
            let isSettingsShortcut = event.keyCode == UInt16(kVK_ANSI_Comma) && event.modifierFlags.contains(.command)
            guard !self.windows.isEmpty || isSettingsShortcut else {
                return event
            }
            switch event.keyCode {
            case returnKeyCode:
                self.pasteFrontMost()
                return nil
            case uint16(kVK_UpArrow):
                if event.modifierFlags.contains(.command) {
                    NotificationCenter.default.post(name: .wrapToFirstEntryRequested,
                                                    object: nil)
                } else {
                    self.rotateWheel(direction: .newer)
                }
                return nil
            case UInt16(kVK_DownArrow):
                self.rotateWheel(direction: .older)
                return nil
            case UInt16(kVK_Delete):
                if event.modifierFlags.contains(.command) {
                    self.deleteFrontEntry()
                    return nil
                }
            case UInt16(kVK_ANSI_Comma):
                if event.modifierFlags.contains(.command) {
                    self.toggleSettingsPopover()
                    return nil
                }
            case UInt16(escapeKeyCode):
                if self.clearSearchTextIfNeeded() == false {
                    self.closeWindows()
                    return nil
                }
            case UInt16(kVK_ANSI_R):
                if event.modifierFlags.contains(.command) {
                    self.rewriteFrontMost()
                    return nil
                }
            case UInt16(kVK_ANSI_F):
                if event.modifierFlags.contains(.command) {
                    self.focusSearchBar()
                    return nil
                }
            case UInt16(kVK_ANSI_P):
                if event.modifierFlags.contains(.command) {
                    if event.modifierFlags.contains(.shift) {
                        togglePinFilter()
                    } else {
                        toggleFrontMostPinned()
                    }
                    return nil
                }
            default: break
            }
            return event
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

    func shouldAllowScrollForEditor(event: NSEvent) -> Bool {
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

    func rewriteFrontMost() {
        guard let frontEntry = entries.first else {
            return
        }
        NotificationCenter.default.post(name: .rewriteFrontEntryRequested,
                                        object: frontEntry.id)
    }
    
    func toggleFrontMostPinned() {
        guard let frontEntry = entries.first else {
            return
        }
        NotificationCenter.default.post(name: .toggleEntryPinnedRequested,
                                        object: frontEntry.id)
    }
    
    func togglePinFilter() {
        statusOverlayContext.filterPinned.toggle()
    }
    
    func focusSearchBar() {
        guard showingWindows else {
            return
        }
        _ = statusOverlayComponents()
        statusOverlayBar?.makeKeyAndOrderFront(nil)
        NotificationCenter.default.post(name: .searchEntriesRequested, object: nil)
    }

    func beginEntriesUpdate() {
        entriesUpdateResetTask?.cancel()
        statusOverlayContext.setUpdatingEntries(true)
    }

    func finishEntriesUpdate(after delay: TimeInterval = 0.0) {
        entriesUpdateResetTask?.cancel()
        let task = DispatchWorkItem { [weak self] in
            self?.statusOverlayContext.setUpdatingEntries(false)
        }
        entriesUpdateResetTask = task
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: task)
    }

    func handleSearchTextChange(_ newValue: String) {
        guard searchText != newValue else {
            finishEntriesUpdate()
            return
        }
        beginEntriesUpdate()
        defer {
            finishEntriesUpdate()
        }
        searchText = newValue
        let previousWindows = windows
        entries = filteredEntries
        windows = filteredEntries.map { createWindow(for: $0) }
        closeWindowPairs(previousWindows)
        if entries.isEmpty {
            statusOverlayContext.update(index: 0, total: 0)
            let (overlayWindow, _) = statusOverlayComponents()
            if let _ = NSScreen.main ?? NSScreen.screens.first,
               let firstPreviousWindow = previousWindows.first?.window {
                let firstWindowFrame = firstPreviousWindow.frame
                let origin = NSPoint(
                    x: firstWindowFrame.midX - CGFloat(statusOverlayWidth) / 2,
                    y: firstWindowFrame.maxY + 40
                )
                overlayWindow.setFrame(NSRect(origin: origin, size: NSSize(width: statusOverlayWidth, height: statusOverlayHeight)), display: true)
                if !overlayWindow.isVisible {
                    overlayWindow.alphaValue = 0
                    overlayWindow.makeKeyAndOrderFront(nil)
                    NSAnimationContext.runAnimationGroup({ context in
                        context.duration = 0.18
                        overlayWindow.animator().alphaValue = 1
                    })
                } else {
                    overlayWindow.makeKeyAndOrderFront(nil)
                }
            }
        } else {
            layoutWindows(animated: false)
        }
        updateToggleMenuTitle()
    }
    
    func handleFilterPinnedChange(_ newValue: Bool) {
        guard statusOverlayContext.filterPinned == newValue else {
            return
        }
        beginEntriesUpdate()
        defer { finishEntriesUpdate() }
        let previousWindows = windows
        let previousEntries = entries
        entries = filteredEntries
        if newValue && entries.isEmpty {
            for (window, _) in previousWindows {
                window.orderOut(nil)
            }
            statusOverlayContext.update(index: 0, total: 0)
            let (overlayWindow, _) = statusOverlayComponents()
            if let _ = NSScreen.main ?? NSScreen.screens.first,
               let firstWindow = previousWindows.first?.window {
                let firstWindowFrame = firstWindow.frame
                let origin = NSPoint(
                    x: firstWindowFrame.midX - CGFloat(statusOverlayWidth) / 2,
                    y: firstWindowFrame.maxY + 40
                )
                overlayWindow.setFrame(NSRect(origin: origin, size: NSSize(width: statusOverlayWidth, height: statusOverlayHeight)), display: true)
                if !overlayWindow.isVisible {
                    overlayWindow.alphaValue = 0
                    overlayWindow.makeKeyAndOrderFront(nil)
                    NSAnimationContext.runAnimationGroup({ context in
                        context.duration = 0.18
                        overlayWindow.animator().alphaValue = 1
                    })
                } else {
                    overlayWindow.makeKeyAndOrderFront(nil)
                }
            }
        } else if !newValue && previousEntries.isEmpty && entries.isEmpty {
            statusOverlayContext.update(index: 0, total: 0)
        } else {
            windows = entries.map { createWindow(for: $0) }
            closeWindowPairs(previousWindows)
            layoutWindows(animated: false)
        }
        updateToggleMenuTitle()
        if newValue == false {
            statusOverlayContext.setUpdatingEntries(false)
        }
    }

    func paste(entry: CopiedContent) {
        switch entry.contentType {
        case .image:
            pasteImage(entry.imageData)
        default:
            paste(entry.rewritten ?? entry.original)
        }
    }

    func paste(_ string: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(string, forType: .string)
        sendPasteToLastActiveApp()
    }

    func pasteImage(_ data: Data?) {
        guard let data else {
            return
        }
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        if let image = NSImage(data: data) {
            pasteboard.writeObjects([image])
        } else {
            pasteboard.setData(data, forType: .tiff)
            pasteboard.setData(data, forType: .png)
        }
        sendPasteToLastActiveApp()
    }

    func sendPasteToLastActiveApp() {
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
    
    func copy(_ string: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(string, forType: .string)
    }

    func rotateWheel(direction: RotationDirection) {
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

    func wrapToFirstEntry() {
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
    func clearSearchTextIfNeeded() -> Bool {
        let trimmed = statusOverlayContext.searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false else {
            return false
        }
        statusOverlayContext.setSearchTextIfNeeded("")
        handleSearchTextChange("")
        return true
    }
}

private final class FloatingClipboardWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

private final class FocusableContainer: NSView {
    override var acceptsFirstResponder: Bool { true }
}

private final class StatusOverlayWindow: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

private final class ClickThroughView: NSView {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
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

extension WindowController {
    @objc
    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        if menuItem == clearItem {
            return !clipboard.history.isEmpty
        }
        return true
    }
}

