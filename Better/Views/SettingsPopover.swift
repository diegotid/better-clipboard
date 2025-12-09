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
    @State private var launchAtLogin = false
    @State private var isProcessing = false
    @State private var errorMessage: String?
    
    @State private var unlocked: Bool = false
    @State private var maxPinnedEntries: Int = 3
    @State private var manager = PurchaseManager()
    
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
                            TextField("", value: $maxHistoryEntries, format: .number)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 40)
                                .multilineTextAlignment(.trailing)
                                .disabled(!unlocked)
                        }
                        Text("New entries will replace the oldest ones when the limit is reached.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    if unlocked {
                        HStack {
                            Image(systemName: "lock.open")
                            Text("Clipboard size unlocked")
                        }
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
                                    .frame(width: 40)
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
    }

    private func loadLaunchAtLoginState() {
        let service = SMAppService.mainApp
        launchAtLogin = service.status == .enabled || service.status == .requiresApproval
    }

    private func toggleLaunchAtLogin(_ isOn: Bool) {
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
    
    private func checkLifetimeUnlocked() async {
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
}

#Preview {
    SettingsPopover()
}
