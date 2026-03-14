//
//  ClipboardWatcher.swift
//  Better
//
//  Public mirror implementation. Source builds show demo content instead of
//  monitoring the real macOS pasteboard.
//

import Foundation

enum ClipboardContent {
    case text(String)
    case image(Data)
}

// Keep the public mirror clipboard boundary identical to the private app:
// only this file and PurchaseManager.swift should differ between branches.
final class ClipboardWatcher {
    private var timer: Timer?
    private var nextChangeCount = 1
    private var nextSampleIndex = 0

    private let samples: [ClipboardContent] = [
        .text("https://cuatro.studio"),
        .text("let greeting = \"Hello, world!\""),
        .text("Draft product copy for launch week"),
        .text("🔥")
    ]

    func start(onChange: @escaping (ClipboardContent, Int) -> Void) {
        stop()
        nextSampleIndex = 0
        timer = Timer.scheduledTimer(withTimeInterval: 1.2, repeats: true) { [weak self] timer in
            guard let self else {
                timer.invalidate()
                return
            }
            guard self.nextSampleIndex < self.samples.count else {
                timer.invalidate()
                self.timer = nil
                return
            }

            let content = self.samples[self.nextSampleIndex]
            let changeCount = self.nextChangeCount
            self.nextSampleIndex += 1
            self.nextChangeCount += 1
            onChange(content, changeCount)
        }
        RunLoop.main.add(timer!, forMode: .common)
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }
}
