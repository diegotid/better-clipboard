//
//  BetterApp.swift
//  Better
//
//  Created by Diego Rivera on 2/11/25.
//

import SwiftUI

@main
struct BetterApp: App {
    @StateObject private var clipboardController = ClipboardController()

    init() {
        NSApplication.shared.setActivationPolicy(.accessory)
    }

    var body: some Scene {
        MenuBarExtra("Better", systemImage: "sparkles") {
            Clipboard()
                .environmentObject(clipboardController)
        }
        .menuBarExtraStyle(.window)
    }
}
