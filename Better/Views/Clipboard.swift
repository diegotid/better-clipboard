//
//  Clipboard.swift
//  Better
//
//  Created by Diego Rivera on 2/11/25.
//

import SwiftUI

struct Clipboard: View {
    @EnvironmentObject var clipboard: ClipboardController

    @State private var currentVariant = Variant.defaultVariant

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Current Language: \(displayName(for: currentVariant.language))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("Style: \(shortStyleDescription(currentVariant.style))")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .padding(.bottom, 4)
            if clipboard.history.isEmpty {
                Text("Copied text will appear here translated.")
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 12)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(clipboard.history) { text in
                            VStack(alignment: .leading, spacing: 6) {
                                Text(text.variants[currentVariant] ?? text.original)
                                    .font(.body)
                                Text(text.original)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                HStack {
                                    Button("Copy translation") {
                                        NSPasteboard.general.clearContents()
                                        NSPasteboard.general.setString(text.variants[currentVariant] ?? text.original, forType: .string)
                                    }
                                    Button("Copy original") {
                                        NSPasteboard.general.clearContents()
                                        NSPasteboard.general.setString(text.original, forType: .string)
                                    }
                                }
                            }
                            .padding(8)
                            .background(.windowBackground)
                            .cornerRadius(8)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxHeight: 320)
            }
            HStack {
                Button("Clear history") {
                    clipboard.history.removeAll()
                }
                Spacer()
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(NSColor.windowBackgroundColor).opacity(0.9))
        )
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .padding(8)
    }
    
    private func displayName(for language: Locale.Language) -> String {
        let locale = Locale.current
        if let code = language.languageCode?.identifier,
           let name = locale.localizedString(forLanguageCode: code) {
            return name.capitalized
        }
        return String(describing: language)
    }
    
    private func shortStyleDescription(_ style: Style) -> String {
        [
            "Formality: \(style.formality.rawValue)",
            "Technicality: \(style.technicality.rawValue)",
            "Verbosity: \(style.verbosity.rawValue)",
            "Warmth: \(style.warmth.rawValue)",
            "Humor: \(style.humor.rawValue)",
            "Emoji: \(style.emoji.rawValue)"
        ]
        .joined(separator: ", ")
    }
}
