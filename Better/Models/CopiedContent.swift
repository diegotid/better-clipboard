//
//  CopiedContent.swift
//  Better
//
//  Created by Diego Rivera on 2/11/25.
//

import Foundation

enum CopiedContentType: String, Codable {
    case text
    case image
}

struct CopiedContent: Identifiable, Codable, Hashable {
    let id: UUID
    let date: Date
    let original: String
    let contentType: CopiedContentType
    let imageData: Data?
    
    var rewritten: String?
    var translatedTo: Locale.Language?

    init(original: String, date: Date, contentType: CopiedContentType = .text, imageData: Data? = nil) {
        self.id = UUID()
        self.date = date
        self.original = original
        self.contentType = contentType
        self.imageData = imageData
    }

    enum CodingKeys: String, CodingKey {
        case id
        case date
        case original
        case contentType
        case imageData
        case rewritten
        case translatedTo
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        date = try container.decode(Date.self, forKey: .date)
        original = try container.decode(String.self, forKey: .original)
        contentType = try container.decodeIfPresent(CopiedContentType.self, forKey: .contentType) ?? .text
        imageData = try container.decodeIfPresent(Data.self, forKey: .imageData)
        rewritten = try container.decodeIfPresent(String.self, forKey: .rewritten)
        translatedTo = try container.decodeIfPresent(Locale.Language.self, forKey: .translatedTo)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(date, forKey: .date)
        try container.encode(original, forKey: .original)
        try container.encode(contentType, forKey: .contentType)
        try container.encode(imageData, forKey: .imageData)
        try container.encode(rewritten, forKey: .rewritten)
        try container.encode(translatedTo, forKey: .translatedTo)
    }

    mutating func updateRewritten(_ value: String?) {
        rewritten = value
    }
    
    mutating func updateLanguage(_ value: Locale.Language?) {
        translatedTo = value
    }
}
