//
//  StatusOverlayBar.swift
//  Better
//
//  Created by Diego Rivera on 13/11/25.
//

import SwiftUI

struct StatusOverlayBar: View {
    var width: Int
    var onWrapToFirst: () -> Void = {}
    @ObservedObject var context: StatusOverlayContext

    @FocusState private var searchFieldFocused: Bool
    @State private var hasAppeared = false

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
            .focusable(false)
            Spacer()
            if isSearching {
                if context.totalCount == 0 {
                    Text("No results")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .padding(.trailing, 12)
                }
                Button {
                    context.searchText = ""
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 22, weight: .light))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .padding(.trailing, 4)
                .help("Clear search")
            } else {
                HStack(spacing: 10) {
                    if shouldShowWrapButton {
                        goTopButton()
                    }
                    if context.totalCount == 0 && context.filterPinned {
                        Text("No pinned entries")
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(.secondary)
                    } else if context.totalCount > 0 {
                        Text("\(context.currentIndex) of \(context.totalCount)")
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(.primary)
                            .fixedSize()
                    }
                }
            }
            toggleFilterPinnedButton()
        }
        .padding(.leading, 20)
        .padding(.trailing, 12)
        .padding(.vertical, 12)
        .frame(width: CGFloat(width), alignment: .leading)
        .onAppear {
            searchFieldFocused = false
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                hasAppeared = true
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .searchEntriesRequested)) { _ in
            if hasAppeared {
                searchFieldFocused = true
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .wrapToFirstEntryRequested)) { _ in
            guard shouldShowWrapButton else {
                return
            }
            onWrapToFirst()
        }
    }
    
    @ViewBuilder
    private func toggleFilterPinnedButton() -> some View {
        Button(action: {
            context.filterPinned.toggle()
        }) {
            HStack {
                HStack {
                    Image(systemName: "command")
                }
                .padding(4)
                .scaleEffect(0.95)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(.ultraThickMaterial)
                )
                HStack {
                    Image(systemName: "shift")
                }
                .padding(4)
                .scaleEffect(0.95)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(.ultraThickMaterial)
                )
                .padding(.leading, -6)
                Text("P")
                    .padding(.vertical, 3)
                    .padding(.horizontal, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(.ultraThickMaterial)
                    )
                    .padding(.leading, -6)
                HStack {
                    Image(systemName: context.filterPinned ? "xmark" : "line.3.horizontal.decrease")
                        .font(.system(size: context.filterPinned ? 18 : 16))
                        .padding(.horizontal, context.filterPinned ? 2 : 1)
                }
                .padding(4)
                .padding(.leading, -3)
                HStack {
                    Image(systemName: "pin")
                        .foregroundStyle(context.filterPinned ? .white : .primary)
                        .padding(.top, 1)
                }
                .padding(4)
                .padding(.leading, -9)
            }
            .padding(3)
            .fixedSize()
            .background(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(context.filterPinned
                          ? AnyShapeStyle(Color.accentColor.opacity(0.9))
                          : AnyShapeStyle(.secondary.opacity(0.3)))
            )
        }
        .buttonStyle(.plain)
        .opacity(0.85)
        .scaleEffect(0.85)
        .keyboardShortcut("p", modifiers: [.command, .shift])
        .help(context.filterPinned ? "Show all entries" : "Show pinned only")
    }
    
    @ViewBuilder
    private func goTopButton() -> some View {
        Button(action: {
            onWrapToFirst()
        }) {
            HStack {
                HStack {
                    Image(systemName: "command")
                }
                .padding(4)
                .scaleEffect(0.95)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(.ultraThickMaterial)
                )
                HStack {
                    Image(systemName: "arrow.up")
                }
                .padding(4)
                .scaleEffect(0.95)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(.ultraThickMaterial)
                )
                .padding(.leading, -6)
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
}
