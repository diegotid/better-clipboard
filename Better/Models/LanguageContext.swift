//
//  LanguageContext.swift
//  Better
//
//  Created by Diego Rivera on 17/11/25.
//

import Combine
import Foundation
import Translation

final class LanguageContext: ObservableObject {
    @Published var languages: [Locale.Language] = [Locale.current.language]
    
    init() {
        refreshLanguages()
    }
    
    func refreshLanguages() {
        guard #available(macOS 26.0, *) else {
            return
        }
        let availability = LanguageAvailability()
        Task {
            let supported = await availability.supportedLanguages
            var newLanguages: [Locale.Language] = [Locale.current.language]
            for language in supported {
                let status = await availability.status(from: Locale.current.language,
                                                       to: language)
                if status == .installed && language != Locale.current.language {
                    newLanguages.append(language)
                }
            }
            await MainActor.run {
                self.languages = newLanguages
            }
        }
    }
}
