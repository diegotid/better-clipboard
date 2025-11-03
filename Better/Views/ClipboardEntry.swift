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
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color(NSColor.windowBackgroundColor).opacity(isFrontMost ? 0.96 : 0.85))
                .shadow(color: .black.opacity(isFrontMost ? 0.25 : 0.15),
                        radius: isFrontMost ? 18 : 12,
                        x: 0,
                        y: isFrontMost ? 12 : 8)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(.white.opacity(isFrontMost ? 0.25 : 0.15), lineWidth: 1)
        )
    }

    private var displayText: String {
        if let variant = entry.variants.first?.value {
            return variant
        }
        return entry.original
    }
}
