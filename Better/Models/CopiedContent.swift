//
//  CopiedContent.swift
//  Better
//
//  Created by Diego Rivera on 2/11/25.
//

import Foundation

enum CopiedContentType: String, Codable {
    case text
    case emoji
    case image
    case link
}

struct CopiedContent: Identifiable, Codable, Hashable {
    let id: UUID
    let date: Date
    let original: String
    let contentType: CopiedContentType
    var isPinned: Bool
    var linkMetatags: LinkMetatags?
    let imageData: Data?
    
    var rewritten: String?
    var translatedTo: Locale.Language?

    init(
        id: UUID = UUID(),
        original: String,
        date: Date,
        contentType: CopiedContentType = .text,
        linkMetatags: LinkMetatags? = nil,
        imageData: Data? = nil
    ) {
        self.id = id
        self.date = date
        self.original = original
        self.contentType = contentType
        self.isPinned = false
        self.linkMetatags = linkMetatags
        self.imageData = imageData
    }

    enum CodingKeys: String, CodingKey {
        case id
        case date
        case original
        case contentType
        case isPinned
        case linkMetatags
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
        isPinned = try container.decode(Bool.self, forKey: .isPinned)
        linkMetatags = try container.decodeIfPresent(LinkMetatags.self, forKey: .linkMetatags)
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
        try container.encode(isPinned, forKey: .isPinned)
        try container.encode(linkMetatags, forKey: .linkMetatags)
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
    
    mutating func pin() {
        isPinned = true
    }
    
    mutating func unpin() {
        isPinned = false
    }
}

struct LinkMetatags: Equatable, Codable, Hashable {
    let title: String?
    let description: String?
    let image: URL?
}
