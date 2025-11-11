//
//  CopiedText.swift
//  Better
//
//  Created by Diego Rivera on 2/11/25.
//

import Foundation

struct CopiedText: Identifiable, Codable, Hashable {
    let id: UUID
    let original: String
    var rewritten: String?
    let date: Date

    init(original: String, date: Date) {
        self.id = UUID()
        self.original = original
        self.rewritten = nil
        self.date = date
    }

    enum CodingKeys: String, CodingKey {
        case id
        case original
        case rewritten
        case date
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        original = try container.decode(String.self, forKey: .original)
        rewritten = try container.decodeIfPresent(String.self, forKey: .rewritten)
        date = try container.decode(Date.self, forKey: .date)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(original, forKey: .original)
        try container.encode(rewritten, forKey: .rewritten)
        try container.encode(date, forKey: .date)
    }

    mutating func updateRewritten(_ value: String?) {
        rewritten = value
    }
}
