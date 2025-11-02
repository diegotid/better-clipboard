//
//  ClipboardWatcher.swift
//  Better
//
//  Created by Diego Rivera on 2/11/25.
//

import AppKit

final class ClipboardWatcher {
    private var lastChange = NSPasteboard.general.changeCount
    private var timer: Timer?

    func start(onChange: @escaping (String) -> Void) {
        stop()
        timer = Timer.scheduledTimer(withTimeInterval: 0.7, repeats: true) { _ in
            let board = NSPasteboard.general
            guard board.changeCount != self.lastChange else {
                return
            }
            self.lastChange = board.changeCount
            if let str = board.string(forType: .string) {
                onChange(str)
            }
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }
}
