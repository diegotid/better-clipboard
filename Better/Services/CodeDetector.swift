//
//  CodeDetector.swift
//  Better
//
//  Created by Diego Rivera on 22/11/25.
//

import Foundation
import SwiftUI
internal import AppKit

struct CodeDetector {
    static let codeThreshold: Double = 0.05

    static func detectCode(in text: String) -> ProgrammingLanguage? {
        let normalizedText = normalizeQuotes(in: text)
        let trimmed = normalizedText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 3 else {
            return nil
        }
        let commentPatterns: [(pattern: String, language: ProgrammingLanguage)] = [
            ("//", ProgrammingLanguage(name: "C-style", color: Color(hex: "7F8C8D"))),
            ("#", ProgrammingLanguage(name: "Script", color: Color(hex: "7ED321"))),
            ("/*", ProgrammingLanguage(name: "C-style", color: Color(hex: "7F8C8D"))),
            ("<!--", ProgrammingLanguage(name: "HTML", color: Color(hex: "FF6347"))),
            ("--", ProgrammingLanguage(name: "SQL", color: Color(hex: "FF6B9D"))),
            ("'''", ProgrammingLanguage(name: "Python", color: Color(hex: "5BA3D0"))),
            ("\"\"\"", ProgrammingLanguage(name: "Python", color: Color(hex: "5BA3D0")))
        ]
        for (pattern, language) in commentPatterns {
            if trimmed.hasPrefix(pattern) {
                return language
            }
        }
        if let jsonLanguage = detectJSON(in: trimmed) {
            return jsonLanguage
        }
        let structuralChars = trimmed.filter { "{}[]:,".contains($0) }.count
        let textLength = trimmed.count
        let structuralDensity = Double(structuralChars) / Double(textLength)
        if structuralDensity > 0.10 {
            if trimmed.hasPrefix("{") || trimmed.hasPrefix("[") {
                let hasQuotedKeys = trimmed.range(of: #""[^"]+"\s*:"#, options: .regularExpression) != nil
                let hasKeyValuePairs = trimmed.contains(":") && trimmed.contains("\"")
                if hasQuotedKeys || hasKeyValuePairs {
                    return ProgrammingLanguage(name: "JSON", color: Color(hex: "95A5A6"))
                }
            }
            return ProgrammingLanguage(name: "Code", color: Color(hex: "7F8C8D"))
        }
        let lines = trimmed.components(separatedBy: .newlines)
        let nonCommentLines = lines.filter { line in
            let trimmedLine = line.trimmingCharacters(in: .whitespaces)
            return !trimmedLine.isEmpty && !trimmedLine.hasPrefix("//") && !trimmedLine.hasPrefix("#")
        }
        let textToAnalyze = nonCommentLines.isEmpty ? trimmed : nonCommentLines.joined(separator: "\n")
        let words = textToAnalyze.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }
        let totalWords = words.count
        guard totalWords > 0 else {
            return nil
            }
        var codeWordCount = 0
        for option in codePatterns {
            if let regex = try? NSRegularExpression(pattern: option.pattern, options: []) {
                let matches = regex.matches(in: textToAnalyze, range: NSRange(textToAnalyze.startIndex..., in: textToAnalyze))
                codeWordCount += matches.count
            }
        }
        let codeRatio = Double(codeWordCount) / Double(totalWords)
        if codeRatio < Self.codeThreshold {
            if hasCodeIndicators(textToAnalyze) {
                return ProgrammingLanguage(name: "Code", color: .blue)
            }
            return nil
        }
        for option in codePatterns {
            if textToAnalyze.range(of: option.pattern, options: .regularExpression) != nil {
                return option.language
            }
        }
        if hasCodeIndicators(textToAnalyze) {
            return ProgrammingLanguage(name: "Code", color: .blue)
        }
        return nil
    }

    private static func detectJSON(in text: String) -> ProgrammingLanguage? {
        guard text.hasPrefix("{") || text.hasPrefix("[") else { return nil }
        guard let data = text.data(using: .utf8) else { return nil }
        if let _ = try? JSONSerialization.jsonObject(with: data, options: []) {
            return ProgrammingLanguage(name: "JSON", color: Color(hex: "95A5A6"))
        }
        return nil
    }

    private static func normalizeQuotes(in text: String) -> String {
        var result = text
        let replacements: [String: String] = [
            "“": "\"",
            "”": "\"",
            "‘": "'",
            "’": "'"
        ]
        for (curly, straight) in replacements {
            result = result.replacingOccurrences(of: curly, with: straight)
        }
        return result
    }
    
    private static func hasCodeIndicators(_ text: String) -> Bool {
        let semicolonCount = text.filter { $0 == ";" }.count
        let bracketCount = text.filter { $0 == "{" || $0 == "}" }.count
        let parenCount = text.filter { $0 == "(" }.count
        let bracketPairs = text.filter { $0 == "[" }.count
        let angleCount = text.filter { $0 == "<" }.count
        let equalCount = text.filter { $0 == "=" }.count
        let colonCount = text.filter { $0 == ":" }.count
        let totalSyntaxChars = semicolonCount + bracketCount + parenCount + bracketPairs
        let textLength = text.count
        let syntaxDensity = Double(totalSyntaxChars) / Double(textLength)
        let hasMultipleSemicolons = semicolonCount >= 2
        let hasMultipleBrackets = bracketCount >= 2
        let hasParenthesesWithBrackets = parenCount >= 1 && bracketCount >= 1
        let hasHighSyntaxDensity = syntaxDensity > 0.05
        let hasAssignmentPattern = text.contains("=") && (text.contains(";") || text.contains("\n"))
        let hasOperators = text.range(of: #"[\+\-\*/%&\|^~<>!]="#, options: .regularExpression) != nil
        let hasFunctionCall = text.range(of: #"\w+\s*\([^)]*\)"#, options: .regularExpression) != nil
        let hasArrayOrGeneric = bracketPairs >= 1 || angleCount >= 2
        let hasMultipleEquals = equalCount >= 2
        let hasMultipleColons = colonCount >= 2
        let hasKeyValuePattern = colonCount >= 1 && (text.contains("{") || text.contains("["))
        var indicators = 0
        if hasMultipleSemicolons { indicators += 1 }
        if hasMultipleBrackets { indicators += 1 }
        if hasParenthesesWithBrackets { indicators += 1 }
        if hasHighSyntaxDensity { indicators += 1 }
        if hasAssignmentPattern { indicators += 1 }
        if hasOperators { indicators += 1 }
        if hasFunctionCall { indicators += 1 }
        if hasArrayOrGeneric { indicators += 1 }
        if hasMultipleEquals { indicators += 1 }
        if hasMultipleColons { indicators += 1 }
        if hasKeyValuePattern { indicators += 1 }
        return indicators >= 2
    }
    
    private static func color(fromHex hex: String) -> Color? {
        var hexString = hex.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        hexString = hexString.replacingOccurrences(of: "#", with: "")
        guard hexString.count == 6,
              let rgb = Int(hexString, radix: 16) else {
            return nil
        }
        let red = Double((rgb >> 16) & 0xFF) / 255.0
        let green = Double((rgb >> 8) & 0xFF) / 255.0
        let blue = Double(rgb & 0xFF) / 255.0
        return Color(red: red, green: green, blue: blue)
    }
    
    static func configureCodeStyling(
        for textView: NSTextView,
        language: ProgrammingLanguage?
    ) {
        textView.font = .monospacedSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isContinuousSpellCheckingEnabled = false
        textView.isGrammarCheckingEnabled = false
        textView.textColor = .textColor
        textView.insertionPointColor = .clear
        textView.isAutomaticTextCompletionEnabled = false
        textView.smartInsertDeleteEnabled = false
        let reformattedText = reformatIndentation(textView.string, language: language)
        textView.string = reformattedText
        let paragraphStyle = configureCodeIndent(language: language)
        applySyntaxHighlighting(to: textView, language: language, paragraphStyle: paragraphStyle)
    }
    
    private static func reformatIndentation(_ text: String, language: ProgrammingLanguage?) -> String {
        let indentationSensitiveLanguages = ["Python", "YAML", "Markdown"]
        if let lang = language?.name, indentationSensitiveLanguages.contains(lang) {
            return text
        }
        let lines = text.components(separatedBy: .newlines)
        var reformatted: [String] = []
        var indentLevel = 0
        let indentString = "    " // 4 spaces
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty {
                reformatted.append("")
                continue
            }
            let startsWithClosing = trimmed.hasPrefix("}") || trimmed.hasPrefix("]") || trimmed.hasPrefix(")")
            if startsWithClosing {
                indentLevel = max(0, indentLevel - 1)
            }
            let indentation = String(repeating: indentString, count: indentLevel)
            reformatted.append(indentation + trimmed)
            var charsToCount = trimmed
            if startsWithClosing {
                charsToCount = String(trimmed.dropFirst())
            }
            let openCount = charsToCount.filter { $0 == "{" || $0 == "[" || $0 == "(" }.count
            let closeCount = charsToCount.filter { $0 == "}" || $0 == "]" || $0 == ")" }.count
            indentLevel += (openCount - closeCount)
            indentLevel = max(0, indentLevel)
        }
        return reformatted.joined(separator: "\n")
    }

    private static func configureCodeIndent(language: ProgrammingLanguage?) -> NSParagraphStyle {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.headIndent = 0
        paragraphStyle.firstLineHeadIndent = 0
        paragraphStyle.tabStops = []
        let tabWidth: CGFloat = 4.0
        let font = NSFont.monospacedSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
        let charWidth = ("    " as NSString).size(withAttributes: [.font: font]).width / 4.0
        paragraphStyle.defaultTabInterval = charWidth * tabWidth
        for i in 1...20 {
            let location = charWidth * tabWidth * CGFloat(i)
            let tabStop = NSTextTab(textAlignment: .left, location: location)
            paragraphStyle.tabStops.append(tabStop)
        }
        return paragraphStyle
    }
    
    private static func applySyntaxHighlighting(
        to textView: NSTextView,
        language: ProgrammingLanguage?,
        paragraphStyle: NSParagraphStyle
    ) {
        guard let storage = textView.textStorage else {
            return
        }
        let fullRange = NSRange(location: 0, length: storage.length)
        let text = storage.string
        storage.removeAttribute(.foregroundColor, range: fullRange)
        storage.addAttribute(.paragraphStyle, value: paragraphStyle, range: fullRange)
        if language?.name == "JSON" {
            applyJSONSyntaxHighlighting(to: storage, text: text, fullRange: fullRange)
            return
        }
        let keywordColor = NSColor.systemPurple
        let stringColor = NSColor.systemRed
        let commentColor = NSColor.systemGreen
        let numberColor = NSColor.systemBlue
        let functionColor = NSColor.systemTeal
        let keywords = [
            "func", "function", "def", "class", "struct", "enum", "interface", "type",
            "var", "let", "const", "int", "string", "bool", "float", "double",
            "if", "else", "for", "while", "switch", "case", "return", "break",
            "import", "export", "from", "as", "public", "private", "static",
            "async", "await", "try", "catch", "throw", "throws"
        ]
        for keyword in keywords {
            let pattern = "\\b\(keyword)\\b"
            if let regex = try? NSRegularExpression(pattern: pattern) {
                let matches = regex.matches(in: text, range: fullRange)
                for match in matches {
                    storage.addAttribute(.foregroundColor, value: keywordColor, range: match.range)
                }
            }
        }
        let stringPattern = "\"[^\"]*\"|'[^']*'"
        if let stringRegex = try? NSRegularExpression(pattern: stringPattern) {
            let matches = stringRegex.matches(in: text, range: fullRange)
            for match in matches {
                storage.addAttribute(.foregroundColor, value: stringColor, range: match.range)
            }
        }
        let commentPattern = "//.*|/\\*[\\s\\S]*?\\*/|#.*"
        if let commentRegex = try? NSRegularExpression(pattern: commentPattern) {
            let matches = commentRegex.matches(in: text, range: fullRange)
            for match in matches {
                storage.addAttribute(.foregroundColor, value: commentColor, range: match.range)
            }
        }
        let numberPattern = "\\b\\d+\\.?\\d*\\b"
        if let numberRegex = try? NSRegularExpression(pattern: numberPattern) {
            let matches = numberRegex.matches(in: text, range: fullRange)
            for match in matches {
                storage.addAttribute(.foregroundColor, value: numberColor, range: match.range)
            }
        }
        let functionPattern = "\\w+(?=\\s*\\()"
        if let functionRegex = try? NSRegularExpression(pattern: functionPattern) {
            let matches = functionRegex.matches(in: text, range: fullRange)
            for match in matches {
                storage.addAttribute(.foregroundColor, value: functionColor, range: match.range)
            }
        }
    }
    
    private static func applyJSONSyntaxHighlighting(
        to storage: NSTextStorage,
        text: String,
        fullRange: NSRange
    ) {
        let keyColor = NSColor.systemPurple        // Keys (property names)
        let stringValueColor = NSColor.systemRed   // String values
        let numberColor = NSColor.systemBlue       // Numbers
        let booleanColor = NSColor.systemOrange    // true/false/null
        let allStringsPattern = #""[^"]*""#
        if let allStringsRegex = try? NSRegularExpression(pattern: allStringsPattern) {
            let matches = allStringsRegex.matches(in: text, range: fullRange)
            for match in matches {
                storage.addAttribute(.foregroundColor, value: stringValueColor, range: match.range)
            }
        }
        let keyPattern = #""[^"]+"\s*:"#
        if let keyRegex = try? NSRegularExpression(pattern: keyPattern) {
            let matches = keyRegex.matches(in: text, range: fullRange)
            for match in matches {
                let matchText = (text as NSString).substring(with: match.range)
                if let quoteEndIndex = matchText.lastIndex(of: "\"") {
                    let distance = matchText.distance(from: matchText.startIndex, to: quoteEndIndex)
                    let keyRange = NSRange(location: match.range.location, length: distance + 1)
                    storage.addAttribute(.foregroundColor, value: keyColor, range: keyRange)
                }
            }
        }
        let numberPattern = #"(?<!")(-?\d+\.?\d*)(?!")"#
        if let numberRegex = try? NSRegularExpression(pattern: numberPattern) {
            let matches = numberRegex.matches(in: text, range: fullRange)
            for match in matches {
                let currentColor = storage.attribute(.foregroundColor, at: match.range.location, effectiveRange: nil) as? NSColor
                if currentColor != stringValueColor {
                    storage.addAttribute(.foregroundColor, value: numberColor, range: match.range)
                }
            }
        }
        let booleanPattern = #"\b(true|false|null)\b"#
        if let booleanRegex = try? NSRegularExpression(pattern: booleanPattern) {
            let matches = booleanRegex.matches(in: text, range: fullRange)
            for match in matches {
                storage.addAttribute(.foregroundColor, value: booleanColor, range: match.range)
            }
        }
    }
}

