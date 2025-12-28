//
//  ProgrammingLanguage.swift
//  Better
//
//  Created by Diego Rivera on 22/11/25.
//

import SwiftUI

struct ProgrammingLanguage: Equatable, Codable, Hashable {
    let name: String
    let color: Color?
    
    private static let colorMap: [String: String] = [
        "Swift": "FF8A5B",
        "C": "A8B9CC",
        "C++": "659AD2",
        "C/C++": "659AD2",
        "TypeScript": "3178C6",
        "JavaScript": "F7C500",
        "PHP": "9B7FC5",
        "Shell": "7ED321",
        "Ruby": "E74C3C",
        "C#": "68C67A",
        "Java": "EA2D2E",
        "Python": "FFD43B",
        "Go": "00ADD8",
        "Rust": "F74C00",
        "Kotlin": "A97BFF",
        "SQL": "FF6B9D",
        "HTML": "FF6347",
        "CSS": "9B59B6",
        "SCSS": "E91E63",
        "JSON": "95A5A6",
        "Markdown": "083FA1",
        "YAML": "E74C3C",
        "Code": "7F8C8D"
    ]
    
    private enum CodingKeys: String, CodingKey {
        case name
        case colorHex
    }
    
    init(name: String) {
        self.name = name
        self.color = Self.colorMap[name].map { Color(hex: $0) }
    }
    
    static func colorMapContains(_ name: String) -> Bool {
        Self.colorMap[name] != nil
    }
    
    private init(name: String, color: Color?) {
        self.name = name
        self.color = color
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decode(String.self, forKey: .name)
        if let hexString = try container.decodeIfPresent(String.self, forKey: .colorHex) {
            color = Color(hex: hexString)
        } else {
            color = Self.colorMap[name].map { Color(hex: $0) }
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(name, forKey: .name)
        if let color = color, let hexString = color.toHex() {
            try container.encode(hexString, forKey: .colorHex)
        }
    }
}

extension Color {
    func toHex() -> String? {
        guard let comps = components else {
            return nil
        }
        let r = Int(comps.red * 255)
        let g = Int(comps.green * 255)
        let b = Int(comps.blue * 255)
        return String(format: "%02X%02X%02X", r, g, b)
    }
}
