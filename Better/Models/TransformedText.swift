//
//  TransformedText.swift
//  Better
//
//  Created by Diego Rivera on 2/11/25.
//

import Foundation

struct TransformedText: Identifiable, Codable, Hashable {
    let id: UUID
    let original: String
    let variants: [Variant: String]
    let date: Date

    init(original: String, date: Date) {
        self.id = UUID()
        self.original = original
        self.variants = [:]
        self.date = date
    }

    enum CodingKeys: String, CodingKey {
        case id
        case original
        case variants
        case date
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        original = try container.decode(String.self, forKey: .original)
        variants = try container.decode([Variant: String].self, forKey: .variants)
        date = try container.decode(Date.self, forKey: .date)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(original, forKey: .original)
        try container.encode(variants, forKey: .variants)
        try container.encode(date, forKey: .date)
    }
}
