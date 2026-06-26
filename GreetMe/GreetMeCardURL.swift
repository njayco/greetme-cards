//
//  GreetMeCardURL.swift
//  GreetMe
//

import Foundation

enum GreetMeCardURL {
    static let webBase = "https://greetme.me"

    static func previewURL(for cardId: String) -> URL {
        URL(string: "\(webBase)/imessage-preview/\(cardId)")!
    }

    static func shareURL(for cardId: String) -> URL {
        URL(string: "\(webBase)/c/\(cardId)")!
    }

    static func extractCardId(from url: URL) -> String? {
        if url.scheme?.lowercased() == "greetme" {
            if url.host == "c" || url.host == "card" {
                let id = url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
                return id.isEmpty ? nil : id
            }
            if let host = url.host, !host.isEmpty, (url.path.isEmpty || url.path == "/") {
                return host
            }
        }

        let parts = url.path.split(separator: "/").map(String.init)
        guard let last = parts.last, !last.isEmpty else { return nil }
        if parts.count >= 2, parts[parts.count - 2] == "c" || parts[parts.count - 2] == "card" {
            return last
        }
        if parts.count == 1 {
            return last
        }
        return nil
    }

    static func isGreetMeCardURL(_ url: URL?) -> Bool {
        guard let url else { return false }
        if url.scheme?.lowercased() == "greetme" { return extractCardId(from: url) != nil }
        guard let host = url.host?.lowercased() else { return false }
        return host == "greetme.me" || host.hasSuffix(".greetme.me")
            || host.contains("greet-me") || host.contains("greetme")
    }
}
