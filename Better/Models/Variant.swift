//
//  Variant.swift
//  Better
//
//  Created by Diego Rivera on 2/11/25.
//

import Foundation

struct Variant: Hashable {
    let style: Style
    let language: Locale.Language
    
    static var defaultVariant: Variant {
        let systemLanguage = Locale.preferredLanguages.first.flatMap {
            Locale.Language(identifier: $0)
        } ?? Locale.Language(identifier: "en")
        return Variant(style: Style(), language: systemLanguage)
    }
}

extension Variant: Codable {
    enum CodingKeys: String, CodingKey {
        case style
        case languageIdentifier
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(style, forKey: .style)
        try container.encode(language.languageCode, forKey: .languageIdentifier)
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        style = try container.decode(Style.self, forKey: .style)
        let langId = try container.decode(String.self, forKey: .languageIdentifier)
        language = Locale.Language(identifier: langId)
    }
}
