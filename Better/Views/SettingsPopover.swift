//
//  SettingsPopover.swift
//  Better
//
//  Created by Diego Rivera on 20/11/25.
//

import SwiftUI
import ServiceManagement
import StoreKit
import Translation

struct SettingsPopover: View {
    @EnvironmentObject private var clipboard: ClipboardController
    
    @State private var launchAtLogin = false
    @State private var isProcessing = false
    @State private var errorMessage: String?
    @State private var unlocked: Bool = false
    @State private var manager = PurchaseManager()
    @State private var historyHotkeyDisplay: String = HotkeySettings.displayString(
        keyCode: UserDefaults.standard.object(forKey: HotkeySettings.keyCodeKey) as? Int ?? HotkeySettings.defaultKeyCode,
        modifiers: UserDefaults.standard.object(forKey: HotkeySettings.modifiersKey) as? Int ?? HotkeySettings.defaultModifiers
    )
    @State private var translationHotkeyDisplay: String = HotkeySettings.displayString(
        keyCode: UserDefaults.standard.object(forKey: HotkeySettings.translationKeyCodeKey) as? Int ?? HotkeySettings.defaultTranslationKeyCode,
        modifiers: UserDefaults.standard.object(forKey: HotkeySettings.translationModifiersKey) as? Int ?? HotkeySettings.defaultTranslationModifiers
    )
    @State private var maxHistoryInput: Int = PurchaseManager.freeMaxCopiedEntries
    @State private var enabledContentTypes: Set<CopiedContentType> = Set(CopiedContentType.allCases)
    @State private var isTranslationAvailable = true
    
    @FocusState private var historyFieldFocused: Bool
    
    @AppStorage("maxHistoryEntries")
    private var maxHistoryEntries: Int = PurchaseManager.freeMaxCopiedEntries

    private func caption(for type: CopiedContentType) -> String {
        switch type {
        case .text: return "Text is always saved"
        case .image: return "Don't add"
        case .link: return "Show as plain text"
        case .code: return "Show as plain text"
        case .emoji: return "Show at default size"
        }
    }
    
    var body: some View {
        Form {
            HStack(alignment: .top) {
                VStack(alignment: .leading) {
                    Section {
                        HStack {
                            Text("Content type")
                            Spacer()
                            Text("When disabled")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .padding(.trailing, 6)
                        }
                        ForEach(CopiedContentType.allCases, id: \.self) { type in
                            Toggle(isOn: Binding(
                                get: {
                                    enabledContentTypes.contains(type)
                                },
                                set: { isOn in
                                    if isOn {
                                        enabledContentTypes.insert(type)
                                    } else {
                                        enabledContentTypes.remove(type)
                                    }
                                })
                            ) {
                                HStack {
                                    Image(systemName: type.symbolName)
                                        .frame(width: 22, alignment: .center)
                                    Text(String(describing: type).capitalized)
                                        .frame(minWidth: 54, alignment: .leading)
                                    Spacer()
                                    Text(caption(for: type))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .padding(.trailing, 6)
                                        .opacity(type == .text ? 1.0 : 0.6)
                                }
                            }
                            .disabled(type == .text)
                        }
                    } header: {
                        Text("Saved Content")
                            .bold()
                            .padding(.bottom, 9)
                    } footer: {
                        Text("Choose which types of content are saved to your clipboard history.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Section {
                        VStack(alignment: .leading) {
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
                        if !unlocked {
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
                        } else {
                            HStack {
                                Image(systemName: "lock.open")
                                Text("Pro unlocked")
                            }
                            .padding(.top, 12)
                            Text("Unlimited pinned entries available.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                                .padding(.bottom, 3)
                        }
                    } header: {
                        Text("History")
                            .bold()
                            .padding(.top, 9)
                    }
                }
                Divider()
                    .padding(.horizontal, 14)
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
                    Section {
                        HStack {
                            Text("Show history")
                            Spacer()
                            HotkeyCaptureField(display: $historyHotkeyDisplay) { keyCode, modifiers in
                                historyHotkeyDisplay = HotkeySettings.displayString(keyCode: keyCode, modifiers: modifiers)
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
                            Text("Translate selection")
                            Spacer()
                            HotkeyCaptureField(display: $translationHotkeyDisplay) { keyCode, modifiers in
                                translationHotkeyDisplay = HotkeySettings.displayString(keyCode: keyCode, modifiers: modifiers)
                                UserDefaults.standard.set(keyCode, forKey: HotkeySettings.translationKeyCodeKey)
                                UserDefaults.standard.set(modifiers, forKey: HotkeySettings.translationModifiersKey)
                                NotificationCenter.default.post(name: .translationHotKeyChanged, object: nil)
                            }
                        }
                        .padding(.top, 2)
                        .disabled(!isTranslationAvailable)
                        .opacity(isTranslationAvailable ? 1.0 : 0.6)
                        if !isTranslationAvailable {
                            Text("Translation requires macOS 26 and a supported Mac.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        } else {
                            Text("Click to change the shortcut. Avoid conflicts with system shortcuts.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    } header: {
                        Text("Keyboard Shortcuts")
                            .bold()
                            .padding(.top, 9)
                    }
                    Spacer()
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
                }
            }
        }
        .padding()
        .frame(width: 525)
        .onAppear {
            maxHistoryInput = maxHistoryEntries
            loadLaunchAtLoginState()
            updateTranslationAvailability()
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
        .onAppear {
            loadEnabledContentTypes()
        }
        .onChange(of: enabledContentTypes) { _, newValue in
            persistEnabledContentTypes(newValue)
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
    func loadEnabledContentTypes() {
        if let stored = UserDefaults.standard.array(forKey: "enabledContentTypes") as? [String] {
            let types = stored.compactMap { CopiedContentType(rawValue: $0) }
            if !types.isEmpty {
                enabledContentTypes = Set(types)
                return
            }
        }
        enabledContentTypes = Set(CopiedContentType.allCases)
    }

    func persistEnabledContentTypes(_ types: Set<CopiedContentType>) {
        let raw = types.map { $0.rawValue }
        UserDefaults.standard.set(raw, forKey: "enabledContentTypes")
        NotificationCenter.default.post(name: .enabledContentTypesChanged, object: nil)
    }

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
        let isPreview = ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
        if isPreview {
            await MainActor.run {
                self.unlocked = false
            }
            return
        }
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

    func updateTranslationAvailability() {
        guard #available(macOS 26.0, *) else {
            isTranslationAvailable = false
            return
        }
        Task {
            let availability = LanguageAvailability()
            let supported = await availability.supportedLanguages
            await MainActor.run {
                isTranslationAvailable = !supported.isEmpty
            }
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
