//
//  PurchaseManager.swift
//  Better
//
//  Public mirror implementation. Source builds stay on the free tier.
//

import SwiftUI

// Keep the public mirror purchase boundary identical to the private app:
// only this file should differ between private and public branches.
@MainActor
@Observable final class PurchaseManager {
    static let shared = PurchaseManager()
    static let unlockProductID = "studio.cuatro.Better.unlock"
    static let freeMaxCopiedEntries = 10
    static let freeMaxPinnedEntries = 3

    var isLoading = false
    var isUnlocked = false
    var lifetimePriceDisplay: String?
    var supportsPurchases = false

    var canPurchaseLifetimeUnlock: Bool {
        false
    }

    init() {}

    func prepare() async {
        await Self.enforceHistoryLimitIfLocked()
    }

    func loadProducts() async {}

    @discardableResult
    func refreshUnlockedState() async -> Bool {
        isUnlocked = false
        return false
    }

    @discardableResult
    func purchaseLifetimeUnlock() async -> Bool {
        false
    }

    @discardableResult
    func restorePurchases() async -> Bool {
        false
    }

    static func enforceHistoryLimitIfLocked() async {
        let defaults = UserDefaults.standard
        let current = defaults.object(forKey: "maxHistoryEntries") as? Int ?? freeMaxCopiedEntries
        if current != freeMaxCopiedEntries {
            defaults.set(freeMaxCopiedEntries, forKey: "maxHistoryEntries")
        }
    }
}
