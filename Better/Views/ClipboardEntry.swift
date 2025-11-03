//
//  ClipboardEntry.swift
//  Better
//
//  Created by Diego Rivera on 3/11/25.
//

import SwiftUI

struct ClipboardEntry: View {
    let entry: TransformedText
    let isFrontMost: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(displayText)
                .font(.title3.weight(.semibold))
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
            Text(entry.original)
                .font(.caption)
                .foregroundStyle(.secondary)
            if isFrontMost {
                HStack(spacing: 12) {
                    Button("Copy translation") {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(displayText, forType: .string)
                    }
                    Button("Copy original") {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(entry.original, forType: .string)
                    }
                }
                .buttonStyle(.borderless)
                .font(.caption)
            }
            Spacer()
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var displayText: String {
        if let variant = entry.variants.first?.value {
            return variant
        }
        return entry.original
    }
}
