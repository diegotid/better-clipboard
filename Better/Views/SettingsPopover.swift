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
    @State private var maxHistoryInput: Int = PurchaseManager.freeMaxCopiedEntries
    @State private var manager = PurchaseManager()
    @State private var hotkeyDisplay: String = HotkeySettings.displayString(
        keyCode: UserDefaults.standard.object(forKey: HotkeySettings.keyCodeKey) as? Int ?? HotkeySettings.defaultKeyCode,
        modifiers: UserDefaults.standard.object(forKey: HotkeySettings.modifiersKey) as? Int ?? HotkeySettings.defaultModifiers
    )
    
    @FocusState private var historyFieldFocused: Bool
    
    @AppStorage("maxHistoryEntries")
    private var maxHistoryEntries: Int = PurchaseManager.freeMaxCopiedEntries
    
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
                    Text("Start Better Clipboard automatically when you log in")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Divider()
                    .padding(.vertical, 14)
                Section {
                    VStack(alignment: .leading) {
                        HStack {
                            Text("Show history shortcut")
                            Spacer()
                            HotkeyCaptureField(display: $hotkeyDisplay) { keyCode, modifiers in
                                hotkeyDisplay = HotkeySettings.displayString(keyCode: keyCode, modifiers: modifiers)
                                UserDefaults.standard.set(keyCode, forKey: HotkeySettings.keyCodeKey)
                                UserDefaults.standard.set(modifiers, forKey: HotkeySettings.modifiersKey)
                                NotificationCenter.default.post(name: .historyHotKeyChanged, object: nil)
                            }
                        }
                        .padding(.top, 2)
                        Text("Click to change the shortcut. Avoid conflicts with system shortcuts.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                        HStack {
                            Text("Maximum items")
                            Spacer()
                            TextField("", value: $maxHistoryInput, format: .number)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 72)
                                .multilineTextAlignment(.trailing)
                                .focused($historyFieldFocused)
                                .onSubmit {
                                    handleMaxHistoryChange(maxHistoryInput)
                                }
                                .disabled(!unlocked)
                        }
                        .padding(.top, 6)
                        Text(unlocked
                             ? """
                                Lowering this limit deletes the oldest items. New copies replace old ones when the limit is reached.
                                """
                             : """
                                New copies replace old ones when the limit is reached. Unlock Pro to change this limit.
                                """
                        )
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    if unlocked {
                        HStack {
                            Image(systemName: "lock.open")
                            Text("Pro unlocked")
                        }
                        .padding(.top, 12)
                        Text("Unlimited pinned entries available.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    } else {
                        VStack(alignment: .leading) {
                            HStack {
                                Text("Maximum pinned items")
                                Spacer()
                                Text("\(PurchaseManager.freeMaxPinnedEntries)")
                                    .foregroundStyle(.secondary)
                                    .padding(.trailing, 3)
                            }
                            .padding(.top, 6)
                            Text("Unlock Pro for unlimited pins.")
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
                        .padding(.top, 8)
                    }
                } header: {
                    Text("History")
                        .bold()
                }
                .padding(.bottom, 3)
            }
        }
        .padding()
        .frame(width: 250)
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
