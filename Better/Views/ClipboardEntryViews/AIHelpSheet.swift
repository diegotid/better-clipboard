//
//  AIHelpSheet.swift
//  Better
//
//  Created by Diego Rivera on 9/11/25.
//

import SwiftUI

struct AIHelpSheet: View {
    var onDismiss: () -> Void
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "apple.intelligence")
                .font(.system(size: 56, weight: .bold))
                .foregroundStyle(.accent)
                .padding(.top, 10)
            Text("Enable Apple Intelligence")
                .font(.title)
                .bold()
            Text("""
Better Clipboard can’t open Apple Writing Tools because Apple Intelligence is turned off or unavailable.

Requirements:
• macOS 15.1 or later on Apple silicon (M1 or newer)
• Siri & Dictation language set to the same language used for macOS
• Apple Intelligence enabled in System Settings → Privacy & Security → Apple Intelligence & Siri

Turn these settings on, then try Rewrite again.
""")
            Button("Got it") {
                onDismiss()
            }
            .keyboardShortcut(.defaultAction)
            .help("Dismiss this message")
        }
        .padding(32)
        .frame(width: 420, height: 420)
    }
}
