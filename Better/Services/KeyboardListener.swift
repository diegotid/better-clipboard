//
//  KeyboardListener.swift
//  Better
//
//  Created by Diego Rivera on 2/11/25.
//

import Carbon.HIToolbox

@MainActor
final class KeyboardListener {
    static let shared = KeyboardListener()

    private var hotKeyRef: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?
    private var callback: (() -> Void)?

    private init() {}

    func register(keyCode: UInt32, modifiers: UInt32, handler: @escaping () -> Void) {
        unregister()
        callback = handler
        let signature: OSType = 0x4254_524C
        let hotKeyID = EventHotKeyID(signature: signature, id: 1)
        let target = GetEventDispatcherTarget()
        let status = RegisterEventHotKey(keyCode, modifiers, hotKeyID, target, 0, &hotKeyRef)
        guard status == noErr else {
            return
        }
        var type = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let result = InstallEventHandler(target, { (_: EventHandlerCallRef?, event: EventRef?, userData: UnsafeMutableRawPointer?) -> OSStatus in
            guard let userData, let event else {
                return noErr
            }
            let hotKeyCenter = Unmanaged<KeyboardListener>.fromOpaque(userData).takeUnretainedValue()
            var hotKeyID = EventHotKeyID()
            let error = GetEventParameter(event,
                                          UInt32(kEventParamDirectObject),
                                          UInt32(typeEventHotKeyID),
                                          nil,
                                          MemoryLayout<EventHotKeyID>.size,
                                          nil,
                                          &hotKeyID)
            if error == noErr {
                hotKeyCenter.invoke()
            }
            return noErr
        }, 1, &type, Unmanaged.passUnretained(self).toOpaque(), &eventHandler)
        if result != noErr {
            NSLog("Failed to install hot key handler: \(result)")
        }
    }

    func unregister() {
        if let handler = eventHandler {
            RemoveEventHandler(handler)
            eventHandler = nil
        }
        if let hotKey = hotKeyRef {
            UnregisterEventHotKey(hotKey)
            hotKeyRef = nil
        }
        callback = nil
    }

    private func invoke() {
        guard let callback else {
            return
        }
        callback()
    }
}
