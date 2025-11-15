//
//  StatusOverlayBar.swift
//  Better
//
//  Created by Diego Rivera on 13/11/25.
//

import SwiftUI

struct StatusOverlayBar: View {
    var width: Int = 360
    var onWrapToFirst: () -> Void = {}
    @ObservedObject var context: StatusOverlayContext

    @FocusState private var searchFieldFocused: Bool

    private var isSearching: Bool {
        context.searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
    }

    private var shouldShowWrapButton: Bool {
        !isSearching && context.totalCount > 1 && context.currentIndex > 1 //== context.totalCount
    }

    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 22, weight: .light))
                .foregroundStyle(.secondary)
                .padding(.leading, -4)
            TextField(
                "Search",
                text: $context.searchText,
                prompt: Text("Search")
                    .font(.system(size: 21, weight: .light))
                    .foregroundStyle(.secondary)
            )
            .textFieldStyle(.plain)
            .font(.system(size: 21, weight: .light))
            .foregroundStyle(.primary)
            .padding(.leading, 4)
            .padding(.top, 1)
            .focused($searchFieldFocused)
            Spacer()
            if isSearching {
                Button {
                    context.searchText = ""
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 22, weight: .light))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .padding(.trailing, -4)
                .help("Clear search")
            } else {
                HStack(spacing: 10) {
                    if shouldShowWrapButton {
                        Button(action: {
                            onWrapToFirst()
                        }) {
                            HStack {
                                HStack {
                                    Image(systemName: "command")
                                    Image(systemName: "arrow.up")
                                        .padding(.leading, -5)
                                }
                                .padding(4)
                                .scaleEffect(0.95)
                                .background(
                                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                                        .fill(.ultraThickMaterial)
                                )
                                Text("Top")
                                    .font(.body)
                                    .padding(.trailing, 8)
                            }
                            .padding(3)
                            .fixedSize()
                            .background(
                                RoundedRectangle(cornerRadius: 7, style: .continuous)
                                    .fill(.secondary.opacity(0.3))
                            )
                        }
                        .buttonStyle(.plain)
                        .opacity(0.85)
                        .scaleEffect(0.85)
                        .keyboardShortcut(.upArrow, modifiers: .command)
                        .help("Jump back to the newest entry")
                    }
                    Text("\(context.currentIndex) of \(context.totalCount)")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(.primary)
                        .fixedSize()
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .frame(width: CGFloat(width), alignment: .leading)
        .onReceive(NotificationCenter.default.publisher(for: .searchEntriesRequested)) { _ in
            searchFieldFocused = true
        }
        .onReceive(NotificationCenter.default.publisher(for: .wrapToFirstEntryRequested)) { _ in
            guard shouldShowWrapButton else {
                return
            }
            onWrapToFirst()
        }
    }
}
