//
//  HotkeyCaptureField.swift
//  Better
//
//  Repurposed as inline hotkey capture field (no popover).
//

import SwiftUI
import Carbon.HIToolbox

struct HotkeyCaptureField: View {
    @Binding var display: String
    let onChange: (Int, Int) -> Void

    @State private var recording = false

    var body: some View {
        Button(action: {
            recording = true
        }) {
            Text(display)
                .foregroundStyle(.secondary)
                .frame(width: 66)
                .padding(.vertical, 5)
                .multilineTextAlignment(.center)
                .lineLimit(1)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(recording ? Color.accentColor.opacity(0.2) : Color(.controlBackgroundColor))
                        .overlay(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .stroke(Color.secondary.opacity(0.1))
                        )
                )
        }
        .buttonStyle(.plain)
        .background(
            HotkeyCaptureView(isRecording: $recording) { keyCode, modifiers in
                display = HotkeySettings.displayString(keyCode: keyCode, modifiers: modifiers)
                onChange(keyCode, modifiers)
                recording = false
            }
        )
    }
}

private struct HotkeyCaptureView: NSViewRepresentable {
    @Binding var isRecording: Bool
    let onCapture: (Int, Int) -> Void

    func makeNSView(context: Context) -> RecorderView {
        let view = RecorderView()
        view.onCapture = onCapture
        view.isRecording = isRecording
        return view
    }

    func updateNSView(_ nsView: RecorderView, context: Context) {
        nsView.isRecording = isRecording
        if isRecording {
            nsView.window?.makeFirstResponder(nsView)
        }
    }
}

private final class RecorderView: NSView {
    var onCapture: ((Int, Int) -> Void)?
    var isRecording: Bool = false

    override var acceptsFirstResponder: Bool { true }
    override var canBecomeKeyView: Bool { true }
    override var needsPanelToBecomeKey: Bool { true }

    override func keyDown(with event: NSEvent) {
        guard isRecording else { return }
        let keyCode = Int(event.keyCode)
        let mods = Int(HotkeySettings.carbonModifiers(from: event.modifierFlags))
        isRecording = false
        onCapture?(keyCode, mods)
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if isRecording {
            window?.makeFirstResponder(self)
        }
    }
}
