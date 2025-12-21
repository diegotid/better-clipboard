//
//  ScaledScrollView.swift
//  Better
//
//  Created by Diego Rivera on 21/12/25.
//

internal import AppKit

final class ScaledScroll: NSScrollView {
    private var isCode: Bool
    private var isEmoji: Bool = false
    
    init(isCode: Bool) {
        self.isCode = isCode
        super.init(frame: .zero)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func setIsCode(_ newValue: Bool) {
        self.isCode = newValue
        updateScale()
    }
    
    func setIsEmoji(_ newValue: Bool) {
        guard newValue != isEmoji else { return }
        isEmoji = newValue
        updateContentViewForEmoji()
        updateElasticity()
    }
    
    override func resize(withOldSuperviewSize oldSize: NSSize) {
        super.resize(withOldSuperviewSize: oldSize)
        updateScale()
        recenterEmojiIfNeeded()
    }
    
    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        updateScale()
        recenterEmojiIfNeeded()
    }
    
    func recenterEmojiIfNeeded() {
        guard isEmoji,
              let textView = documentView as? NSTextView,
              let layoutManager = textView.layoutManager,
              let textContainer = textView.textContainer else {
            return
        }
        syncEmojiLayoutWidth(textView: textView, textContainer: textContainer)
        layoutManager.ensureLayout(for: textContainer)
        let textHeight = layoutManager.usedRect(for: textContainer).height
        let availableHeight = contentView.bounds.height
        let currentInsets = textView.textContainerInset
        let verticalInset = max(0, (availableHeight - textHeight) / 2)
        textView.textContainerInset = NSSize(width: currentInsets.width, height: verticalInset)
    }
}

private extension ScaledScroll {
    func updateScale() {
        guard !isEmoji, let window = window else {
            return
        }
        let baseWindowHeight: CGFloat = 400.0
        let currentWindowHeight = window.frame.height
        let scale = currentWindowHeight / baseWindowHeight
        guard let textView = documentView as? NSTextView else {
            return
        }
        let baseFontSize = NSFont.preferredFont(forTextStyle: .body).pointSize
        let scaledFontSize = baseFontSize * scale * (isCode ? 1.05 : 1.15)
        if let currentFont = textView.font {
            let isMonospaced = currentFont.fontDescriptor.symbolicTraits.contains(.monoSpace)
            textView.font = isMonospaced
                ? .monospacedSystemFont(ofSize: scaledFontSize, weight: .regular)
                : .systemFont(ofSize: scaledFontSize)
        }
    }
    
    func syncEmojiLayoutWidth(textView: NSTextView, textContainer: NSTextContainer) {
        let contentWidth = contentView.bounds.width
        let currentSize = textView.frame.size
        if currentSize.width != contentWidth {
            textView.setFrameSize(NSSize(width: contentWidth, height: currentSize.height))
        }
        textView.minSize = NSSize(width: contentWidth, height: textView.minSize.height)
        textContainer.containerSize = NSSize(width: contentWidth, height: CGFloat.greatestFiniteMagnitude)
    }

    func updateContentViewForEmoji() {
        let needsCenteringClip = isEmoji
        let currentClipView = contentView
        if needsCenteringClip, !(currentClipView is CenteringClip) {
            replaceContentView(with: CenteringClip(frame: currentClipView.frame))
        } else if !needsCenteringClip, currentClipView is CenteringClip {
            replaceContentView(with: NSClipView(frame: currentClipView.frame))
        }
    }

    func replaceContentView(with newClipView: NSClipView) {
        let oldClipView = contentView
        let document = documentView
        newClipView.drawsBackground = oldClipView.drawsBackground
        newClipView.backgroundColor = oldClipView.backgroundColor
        newClipView.autoresizingMask = oldClipView.autoresizingMask
        newClipView.documentView = document
        contentView = newClipView
        documentView = document
    }

    func updateElasticity() {
        let elasticity: NSScrollView.Elasticity = isEmoji ? .none : .automatic
        verticalScrollElasticity = elasticity
        horizontalScrollElasticity = elasticity
    }
}
