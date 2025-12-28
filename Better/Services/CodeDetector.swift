//
//  CodeDetector.swift
//  Better
//
//  Created by Diego Rivera on 22/11/25.
//

import Foundation
import SwiftUI

struct CodeDetector {
    static let maxWordCount = 20
    static let minCodeLength = 3
    static let minTextLength = 16
    static let minNewlineCount = 2
    static let minStructuralChars = 2
    static let codeThreshold: Double = 0.05
    static let structuralDensityThreshold: Double = 0.06
    static let highStructuralDensityThreshold: Double = 0.10
    
    static func detectCode(in text: String) -> ProgrammingLanguage? {
        let normalizedText = normalizeQuotes(in: text)
        let trimmed = normalizedText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= minCodeLength else {
            return nil
        }
        if let jsonLanguage = detectJSON(in: trimmed) {
            return jsonLanguage
        }
        let lines = trimmed.split(whereSeparator: \.isNewline)
        let wordCount = trimmed.split { $0.isWhitespace || $0.isNewline }.count
        let hasNewline = lines.count >= minNewlineCount
        let structuralChars = trimmed.filter { "{}[]:;,()<>=".contains($0) }.count
        let textLength = trimmed.count
        let structuralDensity = Double(structuralChars) / Double(max(1, textLength))
        let looksLikeCode = hasCodeIndicators(trimmed)
            || structuralDensity > structuralDensityThreshold
            || trimmed.range(of: #"\b(import|from|class|struct|enum|func|def|let|var|const|public|private|static|return)\b"#, options: .regularExpression) != nil
        guard looksLikeCode else {
            return nil
        }
        guard textLength >= minTextLength, (hasNewline || structuralChars >= minStructuralChars || wordCount <= maxWordCount) else {
            return nil
        }
        if let langName = detectLanguageWithEnry(snippet: trimmed) {
            return ProgrammingLanguage(name: langName)
        }
        if structuralDensity > highStructuralDensityThreshold {
            if trimmed.hasPrefix("{") || trimmed.hasPrefix("[") {
                let hasQuotedKeys = trimmed.range(of: #"\"[^\"]+\"\s*:"#, options: .regularExpression) != nil
                let hasKeyValuePairs = trimmed.contains(":") && trimmed.contains("\"")
                if hasQuotedKeys || hasKeyValuePairs {
                    return ProgrammingLanguage(name: "JSON")
                }
            }
            return ProgrammingLanguage(name: "Code")
        }
        return nil
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
}

private extension CodeDetector {
    static func detectLanguageWithEnry(snippet: String) -> String? {
        let helperURL = Bundle.main.url(forResource: "langdetect", withExtension: nil)
            ?? Bundle.main.url(forResource: "enry", withExtension: nil)
        guard let helperURL else {
            return nil
        }
        do {
            let process = Process()
            process.executableURL = helperURL
            process.arguments = []
            let stdout = Pipe()
            let stderr = Pipe()
            process.standardOutput = stdout
            process.standardError = stderr
            let stdinPipe = Pipe()
            process.standardInput = stdinPipe
            try process.run()
            if let data = (snippet + "\n").data(using: .utf8) {
                stdinPipe.fileHandleForWriting.write(data)
            }
            try? stdinPipe.fileHandleForWriting.close()
            process.waitUntilExit()
            let terminationStatus = process.terminationStatus
            guard terminationStatus == 0 else {
                return nil
            }
            let outData = stdout.fileHandleForReading.readDataToEndOfFile()
            guard var out = String(data: outData, encoding: .utf8) else {
                return nil
            }
            out = out.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !out.isEmpty else {
                return nil
            }
            struct Candidate { let language: String; let percent: Double }
            struct HelperPayload: Decodable {
                let language: String?
                let top5: [String]?
            }

            func parseCandidatesFromJSON(_ output: String) -> [Candidate] {
                guard let data = output.data(using: .utf8) else { return [] }
                guard let obj = try? JSONSerialization.jsonObject(with: data, options: []) else {
                    return []
                }
                if let payload = try? JSONDecoder().decode(HelperPayload.self, from: data) {
                    var cands: [Candidate] = []
                    if let lang = payload.language, !lang.isEmpty {
                        cands.append(Candidate(language: lang, percent: 100))
                    }
                    if let top = payload.top5 {
                        for (idx, lang) in top.enumerated() where !lang.isEmpty {
                            let pct = max(100 - Double(idx) * 5, 1)
                            cands.append(Candidate(language: lang, percent: pct))
                        }
                    }
                    if !cands.isEmpty {
                        return cands
                    }
                }
                if let arr = obj as? [[String: Any]] {
                    var candidates: [Candidate] = []
                    for item in arr {
                        let lang = (item["Language"] as? String)
                            ?? (item["language"] as? String)
                            ?? (item["name"] as? String)
                        let pct = (item["Percentage"] as? Double)
                            ?? (item["percentage"] as? Double)
                            ?? (item["percent"] as? Double)
                        if let lang, let pct {
                            candidates.append(Candidate(language: lang, percent: pct))
                        }
                    }
                    return candidates.sorted { $0.percent > $1.percent }
                }
                if let dict = obj as? [String: Any] {
                    if let lang = (dict["language"] as? String) ?? (dict["Language"] as? String) {
                        return [Candidate(language: lang, percent: 100.0)]
                    }
                    if dict.keys.contains("filename") || dict.keys.contains("total_lines") || dict.keys.contains("mime") || dict.keys.contains("type") {
                        return []
                    }
                    var candidates: [Candidate] = []
                    for (k, v) in dict {
                        if let pct = v as? Double {
                            candidates.append(Candidate(language: k, percent: pct))
                        }
                    }
                    return candidates.sorted { $0.percent > $1.percent }
                }
                return []
            }

            func parseCandidatesFromText(_ output: String) -> [Candidate] {
                let lines = output.split(separator: "\n").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                var candidates: [Candidate] = []
                for lineSub in lines {
                    let line = String(lineSub)
                    if let match = line.range(of: #"([0-9]+(\.[0-9]+)?)%"#, options: .regularExpression) {
                        let pctStr = String(line[match]).replacingOccurrences(of: "%", with: "")
                        let pct = Double(pctStr) ?? 0
                        let namePart = line[..<match.lowerBound]
                            .replacingOccurrences(of: ":", with: "")
                            .trimmingCharacters(in: .whitespacesAndNewlines)
                        if !namePart.isEmpty {
                            candidates.append(Candidate(language: namePart, percent: pct))
                        }
                    }
                }
                return candidates.sorted { $0.percent > $1.percent }
            }

            var candidates = parseCandidatesFromJSON(out)
            if candidates.isEmpty {
                candidates = parseCandidatesFromText(out)
            }
            let ignored = Set(["Text", "Markdown", "Rich Text Format", "reStructuredText", "Org", "TeX", "LaTeX"])
            candidates = candidates.filter { !ignored.contains($0.language) }
            guard let best = candidates.first else {
                return nil
            }
            if let mapped = candidates.first(where: { ProgrammingLanguage.colorMapContains($0.language) }) {
                return mapped.language
            }
            let minPercent = 60.0
            guard best.percent >= minPercent else {
                return nil
            }
            return best.language
        } catch {
            return nil
        }
    }

    
    static func detectJSON(in text: String) -> ProgrammingLanguage? {
        guard text.hasPrefix("{") || text.hasPrefix("[") else { return nil }
        guard let data = text.data(using: .utf8) else { return nil }
        if let _ = try? JSONSerialization.jsonObject(with: data, options: []) {
            return ProgrammingLanguage(name: "JSON")
        }
        return nil
    }

    static func normalizeQuotes(in text: String) -> String {
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
    
    static func hasCodeIndicators(_ text: String) -> Bool {
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
    
    static func reformatIndentation(_ text: String, language: ProgrammingLanguage?) -> String {
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

    static func configureCodeIndent(language: ProgrammingLanguage?) -> NSParagraphStyle {
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
    
    static func applySyntaxHighlighting(
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
    
    static func applyJSONSyntaxHighlighting(
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
