//
//  CenteringClip.swift
//  Better
//
//  Created by Diego Rivera on 21/12/25.
//

internal import AppKit

class CenteringClip: NSClipView {
    override var documentView: NSView? {
        didSet {
            if let view = documentView {
                NotificationCenter.default.removeObserver(self,
                                                          name: NSView.frameDidChangeNotification,
                                                          object: oldValue)
                view.postsFrameChangedNotifications = true
                NotificationCenter.default.addObserver(self,
                                                       selector: #selector(documentViewFrameChanged),
                                                       name: NSView.frameDidChangeNotification,
                                                       object: view)
            }
        }
    }
    
    override func constrainBoundsRect(_ proposedBounds: NSRect) -> NSRect {
        var rect = super.constrainBoundsRect(proposedBounds)
        guard let documentView = documentView else {
            return rect
        }
        let documentHeight = documentView.frame.height
        let documentWidth = documentView.frame.width
        let clipViewHeight = bounds.height
        let clipViewWidth = bounds.width
        if documentHeight < clipViewHeight {
            rect.origin.y = -(clipViewHeight - documentHeight) / 2
        }
        if documentWidth < clipViewWidth {
            rect.origin.x = -(clipViewWidth - documentWidth) / 2
        }
        return rect
    }
    
    override func viewBoundsChanged(_ notification: Notification) {
        super.viewBoundsChanged(notification)
        let currentBounds = bounds
        setBoundsOrigin(constrainBoundsRect(currentBounds).origin)
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}

private extension CenteringClip {
    @objc
    func documentViewFrameChanged(_ notification: Notification) {
        let currentBounds = bounds
        setBoundsOrigin(constrainBoundsRect(currentBounds).origin)
    }
}
