//
//  ProPopover.swift
//  Better
//
//  Created by Diego Rivera on 8/12/25.
//

import SwiftUI

struct ProPopover: View {
    var onPurchase: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "sparkles")
                    .foregroundStyle(.yellow)
                Text("Better Pro")
                    .font(.title3)
                    .bold()
            }
            Text("Unlock unlimited clipboard history and unlimited pinned entries. Keep everything you copy, forever.")
                .fixedSize(horizontal: false, vertical: true)
            VStack(alignment: .leading, spacing: 6) {
                Label("Unlimited history entries", systemImage: "infinity")
                Label("Unlimited pinned items", systemImage: "pin.fill")
            }
            .font(.callout)
            .foregroundStyle(.secondary)
            HStack {
                Spacer()
                Button(action: onPurchase) {
                    Text("Purchase Pro")
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(16)
        .frame(width: 280)
    }
}
