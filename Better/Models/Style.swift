//
//  Style.swift
//  Better
//
//  Created by Diego Rivera on 2/11/25.
//

public struct Style: Codable, Hashable, Sendable {
    public var formality: Formality = .neutral
    public var technicality: Technicality = .balanced
    public var verbosity: Verbosity = .concise
    public var warmth: Warmth = .neutral
    public var humor: Humor = .none
    public var emoji: EmojiPolicy = .minimal
    
    public init(
        formality: Formality = .neutral,
        technicality: Technicality = .balanced,
        verbosity: Verbosity = .concise,
        warmth: Warmth = .neutral,
        humor: Humor = .none,
        emoji: EmojiPolicy = .minimal
    ) {
        self.formality = formality
        self.technicality = technicality
        self.verbosity = verbosity
        self.warmth = warmth
        self.humor = humor
        self.emoji = emoji
    }

    public func toPromptDescriptor() -> String {
        """
        Style:
        - Formality: \(formality.rawValue)
        - Technicality: \(technicality.rawValue)
        - Verbosity: \(verbosity.rawValue)
        - Warmth: \(warmth.rawValue)
        - Humor: \(humor.rawValue)
        - Emoji: \(emoji.rawValue)
        """
    }
}

public enum Formality: String, Codable, CaseIterable, Sendable { case informal, neutral, formal }
public enum Technicality: String, Codable, CaseIterable, Sendable { case plain, balanced, highlyTechnical }
public enum Verbosity: String, Codable, CaseIterable, Sendable { case terse, concise, detailed, exhaustive }
public enum Warmth: String, Codable, CaseIterable, Sendable { case cool, neutral, warm }
public enum Humor: String, Codable, CaseIterable, Sendable { case none, light, playful, witty }
public enum EmojiPolicy: String, Codable, CaseIterable, Sendable { case none, minimal, allowed, frequent }
