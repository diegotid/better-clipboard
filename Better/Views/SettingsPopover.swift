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
    @State private var maxHistoryInput: Int = PurchaseManager.defaultHistoryLimit
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
                        Text("Launch at login")
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
                    Text("Automatically start Better Clipboard when you log in.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Divider()
                    .padding(.vertical, 8)
                Section {
                    VStack(alignment: .leading) {
                        HStack {
                            Text("Maximum items")
                            Spacer()
                            TextField("", value: $maxHistoryInput, format: .number)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 60)
                                .multilineTextAlignment(.trailing)
                                .focused($historyFieldFocused)
                                .onSubmit {
                                    handleMaxHistoryChange(maxHistoryInput)
                                }
                                .disabled(!unlocked)
                        }
                        Text("Lowering this limit below your current history immediately deletes the oldest items to fit. New entries will replace the oldest ones when the limit is reached.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    if unlocked {
                        HStack {
                            Image(systemName: "lock.open")
                            Text("Pro unlocked")
                        }
                        .padding(.top, 6)
                        Text("Unlimited pinned entries available.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    } else {
                        VStack(alignment: .leading) {
                            HStack {
                                Text("Maximum pinned items")
                                Spacer()
                                TextField("", value: $maxPinnedEntries, format: .number)
                                    .textFieldStyle(.roundedBorder)
                                    .frame(width: 60)
                                    .multilineTextAlignment(.trailing)
                                    .disabled(!unlocked)
                            }
                            Text("Unlock Pro for unlimited pins and custom history size.")
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
                                Text("Pro (lifetime)")
                                Spacer()
                                Text(product.displayPrice)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 3)
                        }
                        .disabled(manager.isLoading)
                        .buttonStyle(.borderedProminent)
                        .tint(.green)
                        .padding(.top, 3)
                    }
                } header: {
                    HStack {
                        Text("History")
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
            maxHistoryInput = maxHistoryEntries
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
            maxHistoryInput = newValue
        }
        .onChange(of: historyFieldFocused) { _, isFocused in
            if !isFocused && maxHistoryInput != maxHistoryEntries {
                handleMaxHistoryChange(maxHistoryInput)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didResignActiveNotification)) { _ in
            applyPendingLimitIfNeeded()
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
        maxHistoryEntries = clamped
        maxHistoryInput = clamped
        if clipboard.history.count > clamped {
            clipboard.trimHistory(to: clamped)
        }
    }

    func applyPendingLimitIfNeeded() {
        if maxHistoryInput != maxHistoryEntries {
            handleMaxHistoryChange(maxHistoryInput)
        }
    }
}

#Preview {
    SettingsPopover()
        .environmentObject(ClipboardController())
}
