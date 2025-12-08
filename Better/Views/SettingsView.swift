//
//  SettingsView.swift
//  Better
//
//  Created by Diego Rivera on 20/11/25.
//

import SwiftUI
import ServiceManagement

struct SettingsView: View {
    @State private var launchAtLogin = false
    @State private var isProcessing = false
    @State private var errorMessage: String?

    var body: some View {
        Form {
            Section {
                Toggle(isOn: Binding(get: {
                    launchAtLogin
                }, set: { newValue in
                    toggleLaunchAtLogin(newValue)
                })) {
                    Text("Launch Better at login")
                }
                .disabled(isProcessing)
                if let errorMessage {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                        .font(.footnote)
                }
            } footer: {
                Text("Enable this option to start Better automatically when you sign in.")
            }
        }
        .padding()
        .frame(width: 420)
        .onAppear {
            loadLaunchAtLoginState()
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
}

