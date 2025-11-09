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
    @Published var history: [CopiedText] = [] {
        didSet {
            saveHistory()
        }
    }
    
    private let CAPACITY: Int = 30

    private let watcher = ClipboardWatcher()
    private let historyFileURL: URL = {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let folder = dir.appendingPathComponent("Better", isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder.appendingPathComponent("clipboard-history.json")
    }()

    init() {
        loadHistory()
        start()
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
                await MainActor.run {
                    let entry = CopiedText(original: trimmed, date: Date())
                    let dedupedHistory = self.history.filter { $0.original != trimmed }
                    let updated = [entry] + dedupedHistory
                    self.history = Array(updated.prefix(self.CAPACITY))
                }
            }
        }
    }

    private func saveHistory() {
        do {
            let data = try JSONEncoder().encode(history)
            try data.write(to: historyFileURL, options: .atomic)
        } catch {
            print("Failed to save clipboard history: \(error)")
        }
    }

    private func loadHistory() {
        guard FileManager.default.fileExists(atPath: historyFileURL.path) else {
            return
        }
        do {
            let data = try Data(contentsOf: historyFileURL)
            let loaded = try JSONDecoder().decode([CopiedText].self, from: data)
            history = Array(loaded.prefix(CAPACITY))
        } catch {
            print("Failed to load clipboard history: \(error)")
        }
    }
}
