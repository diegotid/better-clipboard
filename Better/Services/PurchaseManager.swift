//
//  PurchaseManager.swift
//  Better
//
//  Created by Diego Rivera on 8/12/25.
//

import StoreKit
import SwiftUI

@Observable class PurchaseManager {
    static let unlockProductID = "studio.cuatro.Better.unlock"
    static let defaultHistoryLimit = 15

    var products: [Product] = []
    var isLoading = false
    private var updateListenerTask: Task<Void, Error>?
    
    init() {
        updateListenerTask = listenForTransactions()
    }
    
    deinit {
        updateListenerTask?.cancel()
    }
    
    func listenForTransactions() -> Task<Void, Error> {
        return Task.detached {
            for await result in Transaction.updates {
                if case .verified(let transaction) = result {
                    await transaction.finish()
                }
            }
        }
    }
    
    func loadProducts() async {
        do {
            let productIDs = [Self.unlockProductID]
            products = try await Product.products(for: productIDs)
        } catch {
            print("Failed to load: \(error)")
        }
    }

    static func enforceHistoryLimitIfLocked() async {
        var unlocked = false
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result,
               transaction.productID == PurchaseManager.unlockProductID {
                unlocked = true
                break
            }
        }
        guard unlocked == false else { return }
        let defaults = UserDefaults.standard
        let current = defaults.object(forKey: "maxHistoryEntries") as? Int ?? defaultHistoryLimit
        if current != defaultHistoryLimit {
            defaults.set(defaultHistoryLimit, forKey: "maxHistoryEntries")
        }
    }
    
    func purchase(_ product: Product) async -> Bool {
        isLoading = true
        defer {
            isLoading = false
        }
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                switch verification {
                case .verified(let transaction):
                    await transaction.finish()
                    return true
                case .unverified:
                    return false
                }
            case .userCancelled, .pending:
                return false
            @unknown default:
                return false
            }
        } catch {
            return false
        }
    }
}
