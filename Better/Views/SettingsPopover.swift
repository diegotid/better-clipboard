//
//  SettingsPopover.swift
//  Better
//
//  Created by Diego Rivera on 20/11/25.
//

import SwiftUI
import ServiceManagement
import StoreKit

struct SettingsPopover: View {
    @EnvironmentObject private var clipboard: ClipboardController
    
    @State private var launchAtLogin = false
    @State private var isProcessing = false
    @State private var errorMessage: String?
    @State private var unlocked: Bool = false
    @State private var maxPinnedEntries: Int = 3
    @State private var pendingMaxHistoryEntries: Int?
    @State private var showHistoryTrimConfirmation = false
    @State private var lastSavedMaxHistoryEntries: Int = PurchaseManager.defaultHistoryLimit
    @State private var maxHistoryInput: Int = PurchaseManager.defaultHistoryLimit
    @State private var maxHistoryApplied: Bool = false
    @State private var manager = PurchaseManager()
    
    @FocusState private var historyFieldFocused: Bool
    
    @AppStorage("maxHistoryEntries")
    private var maxHistoryEntries: Int = PurchaseManager.defaultHistoryLimit
    
    var body: some View {
        Form {
            VStack(alignment: .leading) {
                Section {
                    Toggle(isOn: Binding(get: {
                        launchAtLogin
                    }, set: { newValue in
                        toggleLaunchAtLogin(newValue)
                    })) {
                        Text("Launch Better at login")
                    }
                    .padding(.top, 7)
                    .disabled(isProcessing)
                    if let errorMessage {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                            .font(.footnote)
                    }
                } header: {
                    Text("General")
                        .bold()
                } footer: {
                    Text("Enable this option to automatically start Better when you launch MacOS.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Divider()
                    .padding(.vertical, 8)
                Section {
                    VStack(alignment: .leading) {
                        HStack {
                            Text("Max history entries")
                            Spacer()
                            TextField("", value: $maxHistoryInput, format: .number)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 60)
                                .multilineTextAlignment(.trailing)
                                .focused($historyFieldFocused)
                                .disabled(!unlocked)
                        }
                        Text("New entries will replace the oldest ones when the limit is reached.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    if unlocked {
                        Button(action: {
                            handleMaxHistoryChange(maxHistoryInput)
                        }) {
                            Text(maxHistoryApplied ? "Applied" : "Apply changes")
                                .frame(maxWidth: .infinity)
                        }
                        .disabled(maxHistoryInput == maxHistoryEntries)
                        .buttonStyle(.borderedProminent)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 4)
                        HStack {
                            Image(systemName: "lock.open")
                            Text("Clipboard size unlocked")
                        }
                        .padding(.top, 6)
                        Text("Unlimited pinned entries available.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    } else {
                        VStack(alignment: .leading) {
                            HStack {
                                Text("Max pinned entries")
                                Spacer()
                                TextField("", value: $maxPinnedEntries, format: .number)
                                    .textFieldStyle(.roundedBorder)
                                    .frame(width: 60)
                                    .multilineTextAlignment(.trailing)
                                    .disabled(!unlocked)
                            }
                            Text("Unlock clipboard size to get unlimited pinned entries.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    if let product = manager.products.first, !unlocked {
                        Button(action: {
                            Task {
                                let purchased = await manager.purchase(product)
                                if purchased {
                                    self.unlocked = true
                                }
                            }
                        }) {
                            HStack {
                                Image(systemName: "lock.open")
                                Text("Unlock Lifetime")
                                Spacer()
                                Text(product.displayPrice)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 3)
                        }
                        .disabled(manager.isLoading)
                        .buttonStyle(.borderedProminent)
                        .padding(.top, 3)
                    }
                } header: {
                    HStack {
                        Text("Clipboard size")
                            .bold()
                        if !unlocked {
                            Image(systemName: "lock.fill")
                        }
                    }
                }
                .padding(.bottom, 3)
            }
        }
        .padding()
        .frame(width: 240)
        .onAppear {
            lastSavedMaxHistoryEntries = maxHistoryEntries
            maxHistoryInput = maxHistoryEntries
            maxHistoryApplied = false
            loadLaunchAtLoginState()
            Task {
                await manager.loadProducts()
                await checkLifetimeUnlocked()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .restorePurchasesRequested)) { _ in
            Task {
                await checkLifetimeUnlocked()
            }
        }
        .onChange(of: maxHistoryEntries) { _, newValue in
            lastSavedMaxHistoryEntries = newValue
            maxHistoryInput = newValue
            maxHistoryApplied = false
        }
        .onChange(of: maxHistoryInput) { _, newValue in
            if newValue != maxHistoryEntries {
                maxHistoryApplied = false
            }
        }
        .onChange(of: historyFieldFocused) { _, isFocused in
            if !isFocused && maxHistoryInput != maxHistoryEntries {
                handleMaxHistoryChange(maxHistoryInput)
            }
        }
        .alert("Reduce history limit?", isPresented: $showHistoryTrimConfirmation) {
            Button("Cancel", role: .cancel) {
                pendingMaxHistoryEntries = nil
                maxHistoryInput = lastSavedMaxHistoryEntries
                maxHistoryApplied = false
            }
            Button("Remove Old Entries", role: .destructive) {
                guard let newLimit = pendingMaxHistoryEntries else { return }
                maxHistoryEntries = newLimit
                lastSavedMaxHistoryEntries = newLimit
                clipboard.trimHistory(to: newLimit)
                pendingMaxHistoryEntries = nil
                maxHistoryInput = newLimit
                maxHistoryApplied = true
            }
        } message: {
            if let newLimit = pendingMaxHistoryEntries {
                let toRemove = max(clipboard.history.count - newLimit, 0)
                Text("This will delete the \(toRemove) oldest entr\(toRemove == 1 ? "y" : "ies") so the clipboard fits the new limit.")
            }
        }
    }
}

private extension SettingsPopover {
    func loadLaunchAtLoginState() {
        let service = SMAppService.mainApp
        launchAtLogin = service.status == .enabled || service.status == .requiresApproval
    }

    func toggleLaunchAtLogin(_ isOn: Bool) {
        let service = SMAppService.mainApp
        isProcessing = true
        errorMessage = nil
        Task {
            do {
                if isOn {
                    try service.register()
                } else {
                    try await service.unregister()
                }
                await MainActor.run {
                    loadLaunchAtLoginState()
                }
            } catch {
                await MainActor.run {
                    launchAtLogin.toggle()
                    errorMessage = "Could not update login item: \(error.localizedDescription)"
                }
            }
            await MainActor.run {
                isProcessing = false
            }
        }
    }
    
    func checkLifetimeUnlocked() async {
        var foundEntitlement = false
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result,
               transaction.productID == PurchaseManager.unlockProductID {
                foundEntitlement = true
                break
            }
        }
        await MainActor.run {
            self.unlocked = foundEntitlement
        }
    }
    
    func handleMaxHistoryChange(_ newValue: Int) {
        let clamped = min(max(newValue, 1), 100)
        let currentSize = clipboard.history.count
        if clamped < currentSize {
            pendingMaxHistoryEntries = clamped
            showHistoryTrimConfirmation = true
            maxHistoryInput = clamped
            maxHistoryApplied = false
            return
        }
        maxHistoryEntries = clamped
        lastSavedMaxHistoryEntries = clamped
        maxHistoryInput = clamped
        maxHistoryApplied = true
    }
}

#Preview {
    SettingsPopover()
        .environmentObject(ClipboardController())
}
