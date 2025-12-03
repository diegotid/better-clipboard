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

    private let borderCornerRadius: CGFloat = 22
    private let glowPeriod: TimeInterval = 2.4

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
        .overlay(alignment: .center) {
            borderBackground
        }
        .overlay(alignment: .center) {
            glowBorder
        }
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
    
    private var borderBackground: some View {
        RoundedRectangle(cornerRadius: borderCornerRadius, style: .continuous)
            .strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
            .padding(1)
            .allowsHitTesting(false)
    }

    @ViewBuilder
    private var glowBorder: some View {
        if shouldShowGlow {
            TimelineView(.animation) { timeline in
                let elapsed = timeline.date.timeIntervalSinceReferenceDate
                let progress = (elapsed.truncatingRemainder(dividingBy: glowPeriod)) / glowPeriod
                let start = CGFloat(progress)
                let span: CGFloat = 0.35
                let end = start + span
                let pulse = 1.0 + 0.08 * sin(elapsed * 2 * .pi / 1.3)
                ZStack {
                    RoundedRectangle(cornerRadius: borderCornerRadius, style: .continuous)
                        .stroke(Color.white.opacity(0.5), lineWidth: 3.4)
                        .padding(-7)
                        .blur(radius: 14)
                        .scaleEffect(pulse)
                        .opacity(0.9)
                        .shadow(color: Color.white.opacity(0.8), radius: 16)
                    glowSegment(start: start, end: end, lineWidth: 3.2)
                        .padding(-5)
                        .shadow(color: Color.white.opacity(0.9), radius: 16)
                    glowSegment(start: start + 0.18, end: end + 0.12, lineWidth: 2.2)
                        .opacity(0.9)
                        .padding(-4)
                        .shadow(color: Color.white.opacity(0.95), radius: 14)
                }
                .padding(1)
                .transition(.opacity.combined(with: .scale))
                .allowsHitTesting(false)
            }
        }
    }

    private var shouldShowGlow: Bool {
        guard context.isUpdatingEntries else {
            return false
        }
        return true
    }

    private func glowSegment(start: CGFloat, end: CGFloat, lineWidth: CGFloat) -> some View {
        let gradient = AngularGradient(
            colors: [
                Color.white.opacity(0.95),
                Color.white.opacity(0.4),
                Color.white.opacity(0.1),
                Color.white.opacity(0.95)
            ],
            center: .center
        )
        let normalizedStart = start.truncatingRemainder(dividingBy: 1)
        let normalizedEnd = end
        return ZStack {
            glowSegmentPart(from: normalizedStart,
                            to: min(normalizedEnd, 1),
                            gradient: gradient,
                            lineWidth: lineWidth)
            if normalizedEnd > 1 {
                glowSegmentPart(from: 0,
                                to: normalizedEnd - 1,
                                gradient: gradient,
                                lineWidth: lineWidth)
            }
        }
    }

    private func glowSegmentPart(from: CGFloat,
                                 to: CGFloat,
                                 gradient: AngularGradient,
                                 lineWidth: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: borderCornerRadius, style: .continuous)
            .trim(from: from, to: to)
            .stroke(gradient,
                    style: StrokeStyle(
                        lineWidth: lineWidth,
                        lineCap: .round,
                        lineJoin: .round
                    )
            )
            .blur(radius: 1.4)
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
