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

    func start(onChange: @escaping (ClipboardContent, Int) -> Void) {
        stop()
        timer = Timer.scheduledTimer(withTimeInterval: 0.7, repeats: true) { _ in
            let board = NSPasteboard.general
            guard board.changeCount != self.lastChange else {
                return
            }
            self.lastChange = board.changeCount
            if let text = ClipboardWatcher.readText(from: board) {
                onChange(.text(text), board.changeCount)
            } else if let imageData = board.data(forType: .tiff) ?? board.data(forType: .png) {
                onChange(.image(imageData), board.changeCount)
            }
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    private static func readText(from board: NSPasteboard) -> String? {
        if let plain = board.string(forType: .string), plain.isEmpty == false {
            return plain
        }
        if let rtfData = board.data(forType: .rtf),
           let attributed = NSAttributedString(rtf: rtfData, documentAttributes: nil),
           attributed.string.isEmpty == false {
            return attributed.string
        }
        if let rtfdData = board.data(forType: .rtfd),
           let attributed = NSAttributedString(rtfd: rtfdData, documentAttributes: nil),
           attributed.string.isEmpty == false {
            return attributed.string
        }
        if let attributedStrings = board.readObjects(forClasses: [NSAttributedString.self]) as? [NSAttributedString],
           let first = attributedStrings.first,
           first.string.isEmpty == false {
            return first.string
        }
        return nil
    }
}
