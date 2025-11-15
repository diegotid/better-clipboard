//
//  Translator.swift
//  Better
//
//  Created by Diego Rivera on 14/11/25.
//

import Foundation
import NaturalLanguage
import Translation
import SwiftUI

enum TranslatorError: LocalizedError {
    case languagePackMissing(source: Locale.Language, target: Locale.Language)
    case unsupportedPair(source: Locale.Language, target: Locale.Language)
    case undeterminedSourceLanguage

    var errorDescription: String? {
        switch self {
        case let .languagePackMissing(source, target):
            return "Offline translation for \(Self.displayName(for: source)) → \(Self.displayName(for: target)) is not installed. Install the language pack in System Settings › General › Translation."
        case let .unsupportedPair(source, target):
            return "Translation between \(Self.displayName(for: source)) and \(Self.displayName(for: target)) is not supported."
        case .undeterminedSourceLanguage:
            return "Could not determine the source language."
        }
    }

    private static func displayName(for language: Locale.Language) -> String {
        if let code = language.languageCode?.identifier {
            return code
        }
        return String(describing: language)
    }
}

private struct TranslatorKey: EnvironmentKey {
    static let defaultValue: Translator? = nil
}

extension EnvironmentValues {
    var translator: Translator? {
        get { self[TranslatorKey.self] }
        set { self[TranslatorKey.self] = newValue }
    }
}

actor Translator {
    private var targetLanguage: Locale.Language?
    private var sessions: [SessionKey: TranslationSession] = [:]
    private let availability = LanguageAvailability()

    func configure(target: Locale.Language? = nil) async {
        targetLanguage = target
        sessions.removeAll()
    }

    func reconfigureIfNeeded(target: Locale.Language?) async {
        guard targetLanguage != target else {
            return
        }
        targetLanguage = target
        sessions.removeAll()
    }

    func translate(_ text: String) async throws -> String {
        guard let targetLanguage else {
            return text
        }
        let sourceLanguage = Locale.Language(identifier: Locale.preferredLanguages.first ?? Locale.current.identifier)
        let key = SessionKey(source: sourceLanguage, target: targetLanguage)
        let session = try await sessionForTranslation(for: key)
        do {
            let response = try await session.translate(text)
            return response.targetText
        } catch {
            sessions.removeValue(forKey: key)
            throw error
        }
    }

    func detectLanguage(for text: String) -> Locale.Language? {
        let recognizer = NLLanguageRecognizer()
        recognizer.processString(text)
        guard let dominant = recognizer.dominantLanguage else {
            return nil
        }
        return Locale.Language(identifier: dominant.rawValue)
    }

    private func sessionForTranslation(for key: SessionKey) async throws -> TranslationSession {
        if let cached = sessions[key] {
            return cached
        }
        let status = await availability.status(from: key.source, to: key.target)
        switch status {
        case .installed:
            break
        case .supported:
            throw TranslatorError.languagePackMissing(source: key.source, target: key.target)
        case .unsupported:
            throw TranslatorError.unsupportedPair(source: key.source, target: key.target)
        @unknown default:
            throw TranslatorError.unsupportedPair(source: key.source, target: key.target)
        }
        let session = TranslationSession(installedSource: key.source, target: key.target)
        do {
            try await session.prepareTranslation()
            sessions[key] = session
            return session
        } catch {
            throw TranslatorError.languagePackMissing(source: key.source, target: key.target)
        }
    }

    private struct SessionKey: Hashable {
        let source: Locale.Language
        let target: Locale.Language
    }
}
