//
//  LanguageFlag.swift
//  Better
//
//  Created by Diego Rivera on 16/11/25.
//

import SwiftUI

struct LanguageFlag: View {
    let locale: Locale
    let diameter: CGFloat
    
    var body: some View {
        let emoji = flagEmoji(for: locale) ?? "🌎"
        ZStack {
            GeometryReader { proxy in
                Text(emoji)
                    .font(.system(size: proxy.size.width * 2))
                    .frame(width: proxy.size.width * 1.6,
                           height: proxy.size.height * 1.6,
                           alignment: .center)
                    .position(x: proxy.size.width / 3.5, y: proxy.size.height / 2)
                    .clipped()
            }
        }
        .frame(width: diameter, height: diameter)
    }
    
    private func flagEmoji(for regionCode: String) -> String {
        let base: UInt32 = 0x1F1E6 // "A"
        return regionCode
            .uppercased()
            .unicodeScalars
            .compactMap { UnicodeScalar(base + $0.value - UnicodeScalar("A").value) }
            .map { String($0) }
            .joined()
    }

    private func flagEmoji(for locale: Locale) -> String? {
        if let region = locale.region?.identifier {
            return flagEmoji(for: region)
        }
        return nil
    }
}

