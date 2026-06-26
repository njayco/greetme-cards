//
//  GreetMeConfig.swift
//  GreetMe iMessage Extension
//

import Foundation

enum GreetMeConfig {
    /// Production web app domain. NO trailing slash.
    static let baseURL = "https://greetme.me"

    static var catalogURL: URL {
        URL(string: "\(baseURL)/api/imessage/catalog")!
    }

    static var createCardURL: URL {
        URL(string: "\(baseURL)/api/imessage/create-card")!
    }

    static func cardFetchURL(id: String) -> URL {
        URL(string: "\(baseURL)/api/imessage/card/\(id)")!
    }

    static var voiceNoteUploadURL: URL {
        URL(string: "\(baseURL)/api/voice-note/upload")!
    }

    /// Public card page (web app). Used on MSMessage bubbles for recipients.
    static func shareURL(for cardId: String) -> URL {
        URL(string: "\(baseURL)/c/\(cardId)")!
    }

    /// In-extension preview page for a created card.
    static func previewURL(for cardId: String) -> URL {
        URL(string: "\(baseURL)/imessage-preview/\(cardId)")!
    }

    static func isGreetMeHost(_ host: String) -> Bool {
        let h = host.lowercased()
        return h == "greetme.me" || h.hasSuffix(".greetme.me")
            || h.contains("greet-me") || h.contains("greetme")
    }
}
