//
//  ClipboardController.swift
//  Better
//
//  Created by Diego Rivera on 2/11/25.
//

import Combine
import Foundation

@MainActor
final class ClipboardController: ObservableObject {
    @Published var history: [TransformedText] = []

    private let watcher = ClipboardWatcher()
//    private let translator = Translator()

    init() {
        start()
//        Task {
//            await translator.configure(target: Locale.Language(identifier: targetCode))
//        }
    }

    func start() {
        watcher.start { [weak self] text in
            guard let self = self else {
                return
            }
            Task {
                let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else {
                    return
                }
//                    let target = Locale.Language(identifier: self.targetCode)
//                    await self.translator.reconfigureIfNeeded(target: target)
//                    let out = try await self.translator.translate(trimmed)
                await MainActor.run {
                    let text = TransformedText(original: trimmed, date: Date())
                    self.history.insert(text, at: 0)
                }
            }
        }
    }

    func stop() {
        watcher.stop()
    }

//    func setTarget(_ code: String) {
//        targetCode = code
//        Task {
//            await translator.configure(target: Locale.Language(identifier: code))
//        }
//    }
}
