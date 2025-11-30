//
//  ClipboardWatcher.swift
//  Better
//
//  Created by Diego Rivera on 2/11/25.
//

internal import AppKit

enum ClipboardContent {
    case text(String)
    case image(Data)
}

final class ClipboardWatcher {
    private var lastChange = NSPasteboard.general.changeCount
    private var timer: Timer?

    func start(onChange: @escaping (ClipboardContent) -> Void) {
        stop()
        timer = Timer.scheduledTimer(withTimeInterval: 0.7, repeats: true) { _ in
            let board = NSPasteboard.general
            guard board.changeCount != self.lastChange else {
                return
            }
            self.lastChange = board.changeCount
            if let imageData = board.data(forType: .tiff) ?? board.data(forType: .png) {
                onChange(.image(imageData))
            } else if let str = board.string(forType: .string) {
                onChange(.text(str))
            }
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }
}
