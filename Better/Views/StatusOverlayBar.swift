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
    
    @AppStorage("maxHistoryEntries")
    private var maxHistoryEntries: Int = PurchaseManager.freeMaxCopiedEntries
    
    @FocusState private var searchFieldFocused: Bool
    @State private var hasAppeared = false
    @State private var showingFilterMenu = false
    @State private var showingCapacityInfo = false

    private let borderCornerRadius: CGFloat = 22
    private let glowPeriod: TimeInterval = 2.4

    private var isSearching: Bool {
        context.searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
    }

    private var shouldShowWrapButton: Bool {
        !isSearching && context.totalCount > 1 && context.currentIndex > 1
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
            .onKeyPress(.escape) {
                if isSearching {
                    context.searchText = ""
                    searchFieldFocused = false
                    return .handled
                }
                return .ignored
            }
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
                    if context.totalCount == 0 && context.filtered {
                        Text("No items match your filter")
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(.secondary)
                    } else if context.totalCount > 0 {
                        Text("\(context.currentIndex) of \(context.totalCount)")
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(.primary)
                            .fixedSize()
                        if !context.filtered {
                            goProButton(accentuate: context.totalCount == maxHistoryEntries)
                        }
                    }
                }
                .padding(.trailing, 6)
            }
            toggleFilterButton()
        }
        .padding(.leading, 20)
        .padding(.trailing, 9)
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
    
    @ViewBuilder
    private func toggleFilterButton() -> some View {
        Menu {
            Toggle(isOn: $context.filterPinned) {
                Label("Only pinned", systemImage: context.filterPinned ? "pin.slash" : "pin")
                    .padding(.leading, 18)
            }
            .keyboardShortcut("p", modifiers: [.command, .shift])
            .help(context.filterPinned ? "Switch pinned only off" : "Switch pinned only on")
            Divider()
            ForEach(CopiedContentType.allCases, id: \.self) { type in
                typeToggle(type: type)
            }
        } label: {
            HStack(alignment: .center) {
                Image(systemName: "line.3.horizontal.decrease")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.secondary)
                if context.filterPinned {
                    Image(systemName: "pin.fill")
                        .font(.system(size: 12, weight: .medium))
                }
                if let filterType = context.filterType {
                    Image(systemName: filterType.symbolName)
                        .font(.system(size: 15, weight: .medium))
                }
                Image(systemName: "chevron.down")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            .frame(height: 34)
            .padding(.horizontal, 10)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(context.filtered
                                  ? Color.accentColor.opacity(0.6)
                                  : Color.secondary.opacity(0.1))
                    )
            )
        }
        .buttonStyle(.plain)
    }
    
    @ViewBuilder
    private func typeToggle(type: CopiedContentType) -> some View {
        Toggle(isOn: Binding(get: {
            context.filterType == type
        }, set: { newValue in
            context.filterType = newValue ? type : nil
        })) {
            Image(systemName: type.symbolName)
            Text("Only \(String(describing: type))s")
                .padding(.leading, 18)
        }
    }
    
    @ViewBuilder
    private func goTopButton() -> some View {
        Button(action: {
            onWrapToFirst()
        }) {
            HStack(spacing: 0) {
                Image(systemName: "command")
                Image(systemName: "arrow.up")
            }
            .font(.system(size: 12, weight: .light))
            .foregroundStyle(.secondary)
        }
        .buttonStyle(.plain)
        .keyboardShortcut(.upArrow, modifiers: .command)
        .help("Jump back to the newest entry")
    }
    
    @ViewBuilder
    private func goProButton(accentuate: Bool = false) -> some View {
        Button(action: {
            showingCapacityInfo = true
        }) {
            Image(systemName: "info.circle")
                .font(.system(size: 15, weight: accentuate ? .semibold : .light))
                .foregroundStyle(accentuate ? Color.accentColor : .secondary)
        }
        .buttonStyle(.plain)
        .help("About clipboard history size")
        .padding(.leading, 2)
        .popover(isPresented: $showingCapacityInfo) {
            capacityInfoPopover()
        }
    }
    
    @ViewBuilder
    private func capacityInfoPopover() -> some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "info.circle")
                    Text("Clipboard History Size")
                        .font(.headline)
                }
                Text("Oldest items are replaced when the limit is reached.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Text("Maximum items: \(maxHistoryEntries)")
                    .bold()
            }
            Button {
                showingCapacityInfo = false
                NotificationCenter.default.post(name: .openSettingsRequested, object: nil)
            } label: {
                HStack {
                    Image(systemName: "gear")
                    Text("Change Limit...")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .padding(20)
        .frame(width: 240)
    }
}

private extension StatusOverlayBar {
    func glowSegment(start: CGFloat, end: CGFloat, lineWidth: CGFloat) -> some View {
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
    
    func glowSegmentPart(from: CGFloat,
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
}
