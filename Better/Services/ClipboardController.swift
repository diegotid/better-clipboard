//
//  ClipboardController.swift
//  Better
//
//  Created by Diego Rivera on 2/11/25.
//

import Combine
import Foundation
import SwiftUI
import StoreKit

@MainActor
final class ClipboardController: ObservableObject {
    @Published var history: [CopiedContent] = [] {
        didSet {
            saveHistory()
        }
    }
    private var enabledContentTypes: Set<CopiedContentType> = Set(CopiedContentType.allCases)
    private var suppressedPasteboardChange: SuppressedPasteboardChange?
    
    @AppStorage("maxHistoryEntries")
    private var maxHistoryEntries: Int = PurchaseManager.freeMaxCopiedEntries
    
    private let watcher = ClipboardWatcher()
    private let linkFetcher = LinkMetadataFetcher()
    private let historyFileURL: URL = {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let folder = dir.appendingPathComponent("Better", isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder.appendingPathComponent("clipboard-history.json")
    }()
    private let enabledTypesKey = "enabledContentTypes"
    
    init() {
        loadHistory()
        NotificationCenter.default.addObserver(forName: .enabledContentTypesChanged, object: nil, queue: .main) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                self.loadEnabledContentTypes()
            }
        }
        start()
        NotificationCenter.default.addObserver(forName: .toggleEntryPinnedRequested, object: nil, queue: .main) { [weak self] notification in
            guard let self,
                  let targetID = notification.object as? UUID else {
                return
            }
            Task { @MainActor in
                self.togglePin(for: targetID)
            }
        }
    }
    
    func start() {
        watcher.start { [weak self] content, changeCount in
            guard let self = self else {
                return
            }
            Task {
                await MainActor.run {
                    if self.shouldIgnorePasteboardChange(changeCount, content: content) {
                        return
                    }
                    switch content {
                    case .text(let text):
                        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !trimmed.isEmpty else {
                            return
                        }
                        let lowerTrimmed = trimmed.lowercased()
                        if (lowerTrimmed.hasPrefix("http://") || lowerTrimmed.hasPrefix("https://")),
                           let url = self.linkFetcher.detectURL(in: trimmed),
                           let scheme = url.scheme?.lowercased(),
                           scheme == "http" || scheme == "https",
                           let host = url.host,
                           self.isLikelyWebHost(host),
                           self.enabledContentTypes.contains(.link) {
                            let entry = CopiedContent(original: trimmed,
                                                      contentType: .link)
                            self.insert(entry: entry)
                            Task.detached { [weak self] in
                                guard let self else { return }
                                let meta = await self.linkFetcher.fetchLinkMetatags(for: url)
                                await MainActor.run {
                                    if let meta {
                                        self.updateLinkMetadata(for: entry.id, metatags: meta)
                                    }
                                }
                            }
                            return
                        } else if lowerTrimmed.hasPrefix("www."),
                                  let url = URL(string: "https://\(trimmed)"),
                                  let host = url.host,
                                  self.isLikelyWebHost(host),
                                  self.enabledContentTypes.contains(.link) {
                            let entry = CopiedContent(original: trimmed,
                                                      contentType: .link)
                            self.insert(entry: entry)
                            Task.detached { [weak self] in
                                guard let self else { return }
                                let meta = await self.linkFetcher.fetchLinkMetatags(for: url)
                                await MainActor.run {
                                    if let meta {
                                        self.updateLinkMetadata(for: entry.id, metatags: meta)
                                    }
                                }
                            }
                            return
                        }
                        let noSpaces = trimmed.replacingOccurrences(of: " ", with: "")
                        let isEmojiOnly = !noSpaces.isEmpty && noSpaces.allSatisfy { $0.isEmoji }
                        let entryType: CopiedContentType = {
                            if isEmojiOnly && self.enabledContentTypes.contains(.emoji) {
                                return .emoji
                            }
                            return .text
                        }()
                        let entry = CopiedContent(original: trimmed,
                                                  contentType: entryType)
                        self.insert(entry: entry)
                    case .image(let imageData):
                        guard self.enabledContentTypes.contains(.image) else {
                            return
                        }
                        let imageName = "Image \(Date().formatted(date: .omitted, time: .shortened))"
                        let entry = CopiedContent(original: imageName,
                                                  contentType: .image,
                                                  imageData: imageData)
                        let updated = [entry] + self.history
                        self.history = Array(updated.prefix(self.maxHistoryEntries))
                    }
                }
            }
        }
    }
    
    func saveHistory() {
        do {
            let data = try JSONEncoder().encode(history)
            try data.write(to: historyFileURL, options: .atomic)
        } catch {
            print("Failed to save clipboard history: \(error)")
        }
    }

    func suppressPasteboardChange(_ changeCount: Int, content: ClipboardContent) {
        suppressedPasteboardChange = SuppressedPasteboardChange(
            changeCount: changeCount,
            timestamp: Date(),
            content: content
        )
    }
    
    func removeEntry(with id: UUID) {
        history.removeAll { $0.id == id }
    }
    
    func updateRewritten(for id: UUID, value: String?, language: Locale.Language?) {
        guard let index = history.firstIndex(where: { $0.id == id }) else {
            return
        }
        var entry = history[index]
        entry.updateRewritten(value)
        entry.updateLanguage(language)
        history[index] = entry
    }
}

private extension ClipboardController {
    struct SuppressedPasteboardChange {
        let changeCount: Int
        let timestamp: Date
        let content: ClipboardContent
    }

    func shouldIgnorePasteboardChange(_ changeCount: Int, content: ClipboardContent) -> Bool {
        guard let suppressedPasteboardChange else {
            return false
        }
        let age = Date().timeIntervalSince(suppressedPasteboardChange.timestamp)
        if age > 2.0 {
            self.suppressedPasteboardChange = nil
            return false
        }
        if changeCount == suppressedPasteboardChange.changeCount {
            self.suppressedPasteboardChange = nil
            return true
        }
        if matchesSuppressedContent(current: content, suppressed: suppressedPasteboardChange.content) {
            self.suppressedPasteboardChange = nil
            return true
        }
        if case .image = suppressedPasteboardChange.content {
            self.suppressedPasteboardChange = nil
            return true
        }
        if changeCount > suppressedPasteboardChange.changeCount {
            self.suppressedPasteboardChange = nil
        }
        return false
    }

    func matchesSuppressedContent(current: ClipboardContent,
                                  suppressed: ClipboardContent) -> Bool {
        switch (current, suppressed) {
        case (.text(let currentText), .text(let suppressedText)):
            return currentText == suppressedText
        case (.image(let currentData), .image(let suppressedData)):
            return currentData == suppressedData
        default:
            return false
        }
    }

    func insert(entry: CopiedContent) {
        let existing = history.first {
            $0.contentType != .image &&
            ($0.rewritten ?? $0.original) == entry.original
        }
        let dedupedHistory = history.filter {
            $0.contentType == .image || ($0.rewritten ?? $0.original) != entry.original
        }
        let updated = [existing ?? entry] + dedupedHistory
        history = Array(updated.prefix(maxHistoryEntries))
        if (entry.contentType == .text || entry.contentType == .emoji) && enabledContentTypes.contains(.code) {
            let entryID = entry.id
            let entryOriginal = entry.original
            Task.detached { [entryID, entryOriginal] in
                let codeLang = await MainActor.run {
                    CodeDetector.detectCode(in: entryOriginal)
                }
                await MainActor.run {
                    guard let index = self.history.firstIndex(where: { $0.id == entryID }) else {
                        return
                    }
                    var updatedEntry = self.history[index]
                    updatedEntry.setCodeLanguage(codeLang)
                    self.history[index] = updatedEntry
                }
            }
        }
    }
    
    func loadHistory() {
        guard FileManager.default.fileExists(atPath: historyFileURL.path) else {
            return
        }
        do {
            let data = try Data(contentsOf: historyFileURL)
            let loaded = try JSONDecoder().decode([CopiedContent].self, from: data)
            history = Array(loaded.prefix(maxHistoryEntries))
        } catch {
            print("Failed to load clipboard history: \(error)")
        }
    }
    
    func loadEnabledContentTypes() {
        if let stored = UserDefaults.standard.array(forKey: enabledTypesKey) as? [String] {
            let types = stored.compactMap { CopiedContentType(rawValue: $0) }
            if !types.isEmpty {
                enabledContentTypes = Set(types)
                return
            }
        }
        enabledContentTypes = Set(CopiedContentType.allCases)
    }
    
    func isLikelyWebHost(_ host: String) -> Bool {
        let parts = host.split(separator: ".")
        guard parts.count >= 2 else { return false }
        let tld = parts.last ?? ""
        let tldValid = (2...10).contains(tld.count) && tld.allSatisfy { $0.isLetter }
        return tldValid
    }
    
    func updateLinkMetadata(for id: UUID, metatags: LinkMetatags) {
        guard let index = history.firstIndex(where: { $0.id == id }) else { return }
        var entry = history[index]
        entry.linkMetatags = metatags
        history[index] = entry
    }
    
    func togglePin(for id: UUID) {
        guard let index = history.firstIndex(where: { $0.id == id }) else { return }
        let entry = history[index]
        if !entry.isPinned {
            Task {
                let isUnlocked = await checkIfUnlocked()
                await MainActor.run {
                    guard let refreshedIndex = self.history.firstIndex(where: { $0.id == id }) else { return }
                    guard self.history[refreshedIndex].isPinned == false else { return }
                    if !isUnlocked {
                        let pinnedCount = self.history.filter { $0.isPinned }.count
                        if pinnedCount >= PurchaseManager.freeMaxPinnedEntries {
                            return
                        }
                    }
                    var updatedEntry = self.history[refreshedIndex]
                    updatedEntry.isPinned.toggle()
                    self.history[refreshedIndex] = updatedEntry
                    NotificationCenter.default.post(name: .entryPinnedStateChanged, object: id)
                }
            }
        } else {
            var updatedEntry = entry
            updatedEntry.isPinned.toggle()
            history[index] = updatedEntry
            NotificationCenter.default.post(name: .entryPinnedStateChanged, object: id)
        }
    }
    
    private func checkIfUnlocked() async -> Bool {
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result,
               transaction.productID == PurchaseManager.unlockProductID {
                return true
            }
        }
        return false
    }
}

extension Character {
    var isEmoji: Bool {
        guard let scalar = unicodeScalars.first else { return false }
        return scalar.properties.isEmoji && (scalar.value > 0x238C || unicodeScalars.count > 1)
    }
}

extension ClipboardController {
    func trimHistory(to newLimit: Int) {
        guard newLimit >= 0 else { return }
        if history.count > newLimit {
            history = Array(history.prefix(newLimit))
        }
    }
}
