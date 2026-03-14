//
//  BetterApp.swift
//  Better
//
//  Created by Diego Rivera on 2/11/25.
//

import SwiftUI

private final class MenuBarControllerBox {
    var controller: WindowController?
}

@main
struct BetterApp: App {
    @StateObject
    private var clipboardController: ClipboardController
    private let menuBarControllerBox = MenuBarControllerBox()

    init() {
        let clipboard = ClipboardController()
        _clipboardController = StateObject(wrappedValue: clipboard)
        let controllerBox = menuBarControllerBox
        Task { [controllerBox] in
            let controller = await WindowController(clipboard: clipboard)
            controllerBox.controller = controller
            controller.presentInitialWindowsIfNeeded()
        }
        Task {
            await PurchaseManager.shared.prepare()
        }
        NSApplication.shared.setActivationPolicy(.accessory)
    }

    var body: some Scene {
        Settings {
            SettingsPopover()
                .environmentObject(clipboardController)
        }
    }
}
