//
//  TransformedText.swift
//  Better
//
//  Created by Diego Rivera on 2/11/25.
//

import Foundation

struct TransformedText: Identifiable, Hashable {
    let id = UUID()
    let original: String
    let variants: [Variant: String]
    let date: Date
    
    init(original: String, date: Date) {
        self.original = original
        self.variants = [:]
        self.date = date
    }
}
