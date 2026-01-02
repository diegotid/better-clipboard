//
//  HotkeySettings.swift
//  Better
//
//  Created by Diego Rivera on 11/01/26.
//

import Carbon.HIToolbox
import SwiftUI

enum HotkeySettings {
    static let keyCodeKey = "historyHotKeyCode"
    static let modifiersKey = "historyHotKeyModifiers"
    static let defaultKeyCode = Int(kVK_ANSI_V)
    static let defaultModifiers = Int(cmdKey | shiftKey)

    static func displayString(keyCode: Int, modifiers: Int) -> String {
        let symbols: [(UInt32, String)] = [
            (UInt32(cmdKey), "⌘"),
            (UInt32(shiftKey), "⇧"),
            (UInt32(optionKey), "⌥"),
            (UInt32(controlKey), "⌃")
        ]
        let mods = symbols.compactMap { modifiers & Int($0.0) != 0 ? $0.1 : nil }.joined()
        let key = keyName(for: keyCode)
        return mods + key
    }

    static func carbonModifiers(from flags: NSEvent.ModifierFlags) -> UInt32 {
        var carbon: UInt32 = 0
        if flags.contains(.command) { carbon |= UInt32(cmdKey) }
        if flags.contains(.shift) { carbon |= UInt32(shiftKey) }
        if flags.contains(.option) { carbon |= UInt32(optionKey) }
        if flags.contains(.control) { carbon |= UInt32(controlKey) }
        return carbon
    }

    private static func keyName(for keyCode: Int) -> String {
        let mapping: [Int: String] = [
            Int(kVK_Return): "Return",
            Int(kVK_Tab): "Tab",
            Int(kVK_Space): "Space",
            Int(kVK_Delete): "Delete",
            Int(kVK_Escape): "Esc",
            Int(kVK_UpArrow): "↑",
            Int(kVK_DownArrow): "↓",
            Int(kVK_LeftArrow): "←",
            Int(kVK_RightArrow): "→",
            Int(kVK_ANSI_Comma): ",",
            Int(kVK_ANSI_Period): ".",
            Int(kVK_ANSI_Slash): "/",
            Int(kVK_ANSI_Semicolon): ";",
            Int(kVK_ANSI_Quote): "'",
            Int(kVK_ANSI_LeftBracket): "[",
            Int(kVK_ANSI_RightBracket): "]",
            Int(kVK_ANSI_Backslash): "\\",
            Int(kVK_ANSI_Minus): "-",
            Int(kVK_ANSI_Equal): "=",
            Int(kVK_ANSI_Grave): "`"
        ]
        if let letter = letter(for: keyCode) {
            return letter
        }
        if let number = number(for: keyCode) {
            return number
        }
        if let mapped = mapping[keyCode] {
            return mapped
        }
        return String(format: "0x%02X", keyCode)
    }

    private static func letter(for keyCode: Int) -> String? {
        let letters: [(Int, String)] = [
            (Int(kVK_ANSI_A), "A"), (Int(kVK_ANSI_B), "B"), (Int(kVK_ANSI_C), "C"),
            (Int(kVK_ANSI_D), "D"), (Int(kVK_ANSI_E), "E"), (Int(kVK_ANSI_F), "F"),
            (Int(kVK_ANSI_G), "G"), (Int(kVK_ANSI_H), "H"), (Int(kVK_ANSI_I), "I"),
            (Int(kVK_ANSI_J), "J"), (Int(kVK_ANSI_K), "K"), (Int(kVK_ANSI_L), "L"),
            (Int(kVK_ANSI_M), "M"), (Int(kVK_ANSI_N), "N"), (Int(kVK_ANSI_O), "O"),
            (Int(kVK_ANSI_P), "P"), (Int(kVK_ANSI_Q), "Q"), (Int(kVK_ANSI_R), "R"),
            (Int(kVK_ANSI_S), "S"), (Int(kVK_ANSI_T), "T"), (Int(kVK_ANSI_U), "U"),
            (Int(kVK_ANSI_V), "V"), (Int(kVK_ANSI_W), "W"), (Int(kVK_ANSI_X), "X"),
            (Int(kVK_ANSI_Y), "Y"), (Int(kVK_ANSI_Z), "Z")
        ]
        return letters.first(where: { $0.0 == keyCode })?.1
    }

    private static func number(for keyCode: Int) -> String? {
        let numbers: [(Int, String)] = [
            (Int(kVK_ANSI_0), "0"), (Int(kVK_ANSI_1), "1"), (Int(kVK_ANSI_2), "2"),
            (Int(kVK_ANSI_3), "3"), (Int(kVK_ANSI_4), "4"), (Int(kVK_ANSI_5), "5"),
            (Int(kVK_ANSI_6), "6"), (Int(kVK_ANSI_7), "7"), (Int(kVK_ANSI_8), "8"),
            (Int(kVK_ANSI_9), "9")
        ]
        return numbers.first(where: { $0.0 == keyCode })?.1
    }
}
