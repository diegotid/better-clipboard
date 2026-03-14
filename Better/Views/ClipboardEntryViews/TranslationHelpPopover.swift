//
//  TranslationHelpPopover.swift
//  Better
//
//  Created by Diego Rivera on 22/11/25.
//

import SwiftUI

struct TranslationHelpPopover: View {
    let onRefresh: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Language Not Supported")
                .font(.title3)
            Text("How To Add Translation Languages:")
                .font(.headline)
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .top) {
                    Text("1.")
                        .font(.system(.body, design: .monospaced))
                        .foregroundStyle(.secondary)
                    Text("Open System Settings")
                }
                HStack(alignment: .top) {
                    Text("2.")
                        .font(.system(.body, design: .monospaced))
                        .foregroundStyle(.secondary)
                    Text("Go to General → Language & Region")
                }
                HStack(alignment: .top) {
                    Text("3.")
                        .font(.system(.body, design: .monospaced))
                        .foregroundStyle(.secondary)
                    Text("Click \"Translation Languages...\"")
                }
                HStack(alignment: .top) {
                    Text("4.")
                        .font(.system(.body, design: .monospaced))
                        .foregroundStyle(.secondary)
                    Text("Download the languages you want to translate from and to")
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .font(.callout)
            .padding(.bottom, 18)
            .padding(.leading, 6)
            HStack {
                Spacer()
                Button("Open System Settings") {
                    if let url = URL(string: "x-apple.systempreferences:com.apple.Localization-Settings.extension") {
                        NSWorkspace.shared.open(url)
                    }
                }
                .controlSize(.small)
                Button(action: onRefresh) {
                    Image(systemName: "arrow.clockwise")
                }
                .controlSize(.small)
            }
        }
        .padding(16)
        .frame(width: 300)
    }
}

#Preview {
    TranslationHelpPopover(onRefresh: {})
}
