//
//  GreetMeModels.swift
//  GreetMe iMessage Extension
//
//  Model structs matching the JSON payloads produced by the GreetMe
//  iMessage endpoints:
//   - GET  /api/imessage/catalog          (browse home data)
//   - POST /api/imessage/create-card      (create + gate + optional checkout)
//   - GET  /api/imessage/card/[id]        (single card display data)
//   - POST /api/voice-note/upload         (voice note audio upload)
//

import Foundation

// MARK: - Catalog (browse home)

/// Full catalog response for the browse home screen.
struct GreetMeCatalog: Decodable {
    let totalCards: Int
    let categories: [GreetMeCatalogCategory]
    let popular: [GreetMeCatalogCard]
}

/// A category tab with its cards.
struct GreetMeCatalogCategory: Decodable, Identifiable, Hashable {
    let id: String
    let name: String
    let count: Int
    let cards: [GreetMeCatalogCard]
}

/// A single catalog card the user can browse and pick. The numeric `id`
/// resolves to a real catalog card id on the GreetMe backend.
struct GreetMeCatalogCard: Decodable, Identifiable, Hashable {
    let id: Int
    let title: String
    let categoryName: String
    let coverImageUrl: String
    let price: Double
}

// MARK: - Create request

/// Request body for POST /api/imessage/create-card.
/// Mirrors the inputs the web share flow accepts.
struct CreateCardRequest: Encodable {
    let cardId: Int?
    let customCardId: String?
    let from: String
    let to: String
    let note: String?
    let youtube: YouTubePayload?
    let voiceNoteUrl: String?
    let cashGift: CashGiftPayload?
    let signatureUrl: String?

    struct YouTubePayload: Encodable {
        let enabled: Bool
        let videoId: String
        let url: String
        let title: String
        let startSeconds: Int
    }

    /// Cash App peer-to-peer gift. GreetMe never moves money; the recipient
    /// requests it via a Cash App deep link on the live card.
    struct CashGiftPayload: Encodable {
        let cashtag: String
        let amount: Double
    }
}

// MARK: - Responses

/// Flat response payload returned by the create / fetch endpoints.
struct GreetMeCardPayload: Decodable {
    let id: String
    let shareUrl: String
    let previewUrl: String
    let title: String
    let coverImageUrl: String
    let senderName: String
    let recipientName: String
    let hasMusic: Bool
    let hasYoutube: Bool
    let hasVoiceNote: Bool
    let hasCashGift: Bool

    // Present only on the create response.
    let requiresPayment: Bool?
    let checkoutUrl: String?

    /// URL for the in-extension preview page (`/imessage-preview/...`).
    var previewPageURL: URL {
        GreetMeConfig.previewURL(for: id)
    }

    /// Canonical public share link on greetme.me (used for MSMessage taps / web).
    var canonicalShareURL: URL {
        GreetMeConfig.shareURL(for: id)
    }
}

/// Response of POST /api/voice-note/upload: { "url": "/objects/voice-notes/..." }
struct VoiceNoteUploadResponse: Decodable {
    let url: String
}

/// Error body shape: { "error": "..." }
struct GreetMeErrorResponse: Decodable {
    let error: String
}
