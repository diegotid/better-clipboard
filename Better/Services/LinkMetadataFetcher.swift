//
//  LinkMetadataFetcher.swift
//  Better
//
//  Created by Diego Rivera on 3/17/25.
//

import Foundation
internal import AppKit

struct LinkMetadataFetcher {
    func detectURL(in text: String) -> URL? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        func normalizedURL(from raw: String) -> URL? {
            guard let url = URL(string: raw),
                  let scheme = url.scheme?.lowercased(),
                  (scheme == "http" || scheme == "https"),
                  let host = url.host, !host.isEmpty else {
                return nil
            }
            return url
        }
        if let direct = normalizedURL(from: trimmed) {
            return direct
        }
        if let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) {
            let range = NSRange(trimmed.startIndex..<trimmed.endIndex, in: trimmed)
            if let match = detector.firstMatch(in: trimmed, options: [], range: range),
               match.range.length == range.length,
               let url = normalizedURL(from: match.url?.absoluteString ?? "") {
                return url
            }
        }
        if domainLike(trimmed),
           let url = normalizedURL(from: "https://\(trimmed)") {
            return url
        }
        return nil
    }
    
    func fetchLinkMetatags(for url: URL) async -> LinkMetatags? {
        do {
            let (html, finalURL) = try await fetchHTML(for: url)
            let base = finalURL ?? url
            return parseMetatags(from: html, baseURL: base)
        } catch {
            return nil
        }
    }
}

private extension LinkMetadataFetcher {
    func domainLike(_ text: String) -> Bool {
        guard !text.contains(where: { $0.isWhitespace || $0.isNewline }) else { return false }
        guard let first = text.first, first.isLetter || first.isNumber else { return false }
        let pattern = #"^[A-Za-z0-9](?:[A-Za-z0-9\-\._]*[A-Za-z0-9])?\.[A-Za-z]{2,}([/\?#].*)?$"#
        return text.range(of: pattern, options: .regularExpression) != nil
    }
    
    func fetchHTML(for url: URL) async throws -> (String, URL?) {
        var request = URLRequest(url: url, cachePolicy: .returnCacheDataElseLoad, timeoutInterval: 12)
        request.setValue("Mozilla/5.0", forHTTPHeaderField: "User-Agent")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let html = String(data: data, encoding: .utf8) else {
            throw URLError(.cannotDecodeRawData)
        }
        return (html, (response as? HTTPURLResponse)?.url)
    }
    
    func parseMetatags(from html: String, baseURL: URL) -> LinkMetatags? {
        let rawTitle = extractMeta(from: html, keys: ["og:title", "twitter:title"]) ??
        extractTagContent(from: html, tag: "title")
        let rawDescription = extractMeta(from: html, keys: ["og:description", "twitter:description"])
        let imageURLString = extractMeta(from: html, keys: ["og:image", "og:image:secure_url", "twitter:image", "twitter:image:src"])
        let title = rawTitle.flatMap(decodeHTMLEntities)
        let description = rawDescription.flatMap(decodeHTMLEntities)
        let imageURL = imageURLString.flatMap { URL(string: $0, relativeTo: baseURL) }
        if title != nil || description != nil || imageURL != nil {
            return LinkMetatags(title: title, description: description, image: imageURL)
        }
        return nil
    }
    
    func extractMeta(from html: String, keys: [String]) -> String? {
        for key in keys {
            let propertyPattern = "<meta[^>]*property=[\"']\(key)[\"'][^>]*content=[\"']([^\"']+)[\"'][^>]*>"
            if let match = firstMatch(in: html, pattern: propertyPattern) {
                return match
            }
            let namePattern = "<meta[^>]*name=[\"']\(key)[\"'][^>]*content=[\"']([^\"']+)[\"'][^>]*>"
            if let match = firstMatch(in: html, pattern: namePattern) {
                return match
            }
        }
        return nil
    }
    
    func extractTagContent(from html: String, tag: String) -> String? {
        let pattern = "<\(tag)[^>]*>(.*?)</\(tag)>"
        return firstMatch(in: html, pattern: pattern)
    }
    
    func firstMatch(in html: String, pattern: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern,
                                                   options: [.caseInsensitive, .dotMatchesLineSeparators]) else {
            return nil
        }
        let range = NSRange(html.startIndex..<html.endIndex, in: html)
        guard let match = regex.firstMatch(in: html, options: [], range: range),
              match.numberOfRanges > 1,
              let matchRange = Range(match.range(at: 1), in: html) else { return nil }
        return String(html[matchRange]).trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    func decodeHTMLEntities(_ string: String) -> String {
        guard let data = string.data(using: .utf8) else { return string }
        let options: [NSAttributedString.DocumentReadingOptionKey: Any] = [
            .documentType: NSAttributedString.DocumentType.html,
            .characterEncoding: String.Encoding.utf8.rawValue
        ]
        if let decoded = try? NSAttributedString(data: data, options: options, documentAttributes: nil).string {
            return decoded
        }
        return string
    }
}
