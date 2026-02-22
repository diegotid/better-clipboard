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
    
    struct Registration {
        let id: UInt32
        let keyCode: UInt32
        let modifiers: UInt32
        let handler: () -> Void
    }

    private var hotKeyRefs: [UInt32: EventHotKeyRef] = [:]
    private var eventHandler: EventHandlerRef?
    private var callbacks: [UInt32: () -> Void] = [:]
    
    private init() {}
    
    func register(keyCode: UInt32, modifiers: UInt32, handler: @escaping () -> Void) {
        registerAll([
            Registration(id: 1, keyCode: keyCode, modifiers: modifiers, handler: handler)
        ])
    }

    func registerAll(_ registrations: [Registration]) {
        unregister()
        guard !registrations.isEmpty else {
            return
        }
        let signature: OSType = 0x4254_524C
        let target = GetEventDispatcherTarget()
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
                hotKeyCenter.invoke(id: hotKeyID.id)
            }
            return noErr
        }, 1, &type, Unmanaged.passUnretained(self).toOpaque(), &eventHandler)
        if result != noErr {
            NSLog("Failed to install hot key handler: \(result)")
            return
        }
        for registration in registrations {
            var hotKeyRef: EventHotKeyRef?
            let hotKeyID = EventHotKeyID(signature: signature, id: registration.id)
            let status = RegisterEventHotKey(
                registration.keyCode,
                registration.modifiers,
                hotKeyID,
                target,
                0,
                &hotKeyRef
            )
            guard status == noErr, let hotKeyRef else {
                continue
            }
            hotKeyRefs[registration.id] = hotKeyRef
            callbacks[registration.id] = registration.handler
        }
    }
    
    func unregister() {
        if let handler = eventHandler {
            RemoveEventHandler(handler)
            eventHandler = nil
        }
        for hotKey in hotKeyRefs.values {
            UnregisterEventHotKey(hotKey)
        }
        hotKeyRefs.removeAll()
        callbacks.removeAll()
    }
}

private extension KeyboardListener {
    func invoke(id: UInt32) {
        guard let callback = callbacks[id] else {
            return
        }
        callback()
    }
}

extension Notification.Name {
    static let historyHotKeyChanged = Notification.Name("historyHotKeyChanged")
    static let translationHotKeyChanged = Notification.Name("translationHotKeyChanged")
    static let enabledContentTypesChanged = Notification.Name("enabledContentTypesChanged")
}
