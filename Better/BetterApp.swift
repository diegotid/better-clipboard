//
//  BetterApp.swift
//  Better
//
//  Created by Diego Rivera on 2/11/25.
//

import SwiftUI

@main
struct BetterApp: App {
    @StateObject private var clipboardController: ClipboardController
    private let menuBarController: MenuBarController

    init() {
        let clipboard = ClipboardController()
        _clipboardController = StateObject(wrappedValue: clipboard)
        menuBarController = MenuBarController(clipboard: clipboard)
        NSApplication.shared.setActivationPolicy(.accessory)
    }

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}
