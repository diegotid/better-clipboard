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
