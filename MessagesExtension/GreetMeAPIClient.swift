//
//  GreetMeAPIClient.swift
//  GreetMe iMessage Extension
//
//  Small networking client that calls the GreetMe iMessage endpoints.
//

import Foundation

enum GreetMeAPIError: LocalizedError {
    case invalidResponse
    case server(String)
    case decoding

    var errorDescription: String? {
        switch self {
        case .invalidResponse: return "The server returned an unexpected response."
        case .server(let message): return message
        case .decoding: return "Could not read the server response."
        }
    }
}

struct GreetMeAPIClient {
    var session: URLSession = .shared

    /// Fetch the browse-home catalog (categories, popular cards, prices).
    func fetchCatalog() async throws -> GreetMeCatalog {
        var urlRequest = URLRequest(url: GreetMeConfig.catalogURL)
        urlRequest.httpMethod = "GET"

        let (data, response) = try await session.data(for: urlRequest)
        try Self.validate(response: response, data: data)
        do {
            return try JSONDecoder().decode(GreetMeCatalog.self, from: data)
        } catch {
            throw GreetMeAPIError.decoding
        }
    }

    /// Create a shared card. Returns the flat payload, which includes
    /// `requiresPayment` and an optional `checkoutUrl` when payment is needed.
    func createCard(_ request: CreateCardRequest) async throws -> GreetMeCardPayload {
        var urlRequest = URLRequest(url: GreetMeConfig.createCardURL)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.httpBody = try JSONEncoder().encode(request)

        let (data, response) = try await session.data(for: urlRequest)
        return try Self.decodePayload(data: data, response: response)
    }

    /// Fetch a single card's public display data by id.
    func fetchCard(id: String) async throws -> GreetMeCardPayload {
        var urlRequest = URLRequest(url: GreetMeConfig.cardFetchURL(id: id))
        urlRequest.httpMethod = "GET"

        let (data, response) = try await session.data(for: urlRequest)
        return try Self.decodePayload(data: data, response: response)
    }

    /// Upload a recorded voice note. Returns the object-storage URL string
    /// (e.g. "/objects/voice-notes/<uuid>.m4a") to pass as `voiceNoteUrl`.
    func uploadVoiceNote(data audioData: Data, mimeType: String, fileName: String) async throws -> String {
        let boundary = "Boundary-\(UUID().uuidString)"
        var urlRequest = URLRequest(url: GreetMeConfig.voiceNoteUploadURL)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"audio\"; filename=\"\(fileName)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: \(mimeType)\r\n\r\n".data(using: .utf8)!)
        body.append(audioData)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)
        urlRequest.httpBody = body

        let (data, response) = try await session.data(for: urlRequest)
        try Self.validate(response: response, data: data)
        do {
            return try JSONDecoder().decode(VoiceNoteUploadResponse.self, from: data).url
        } catch {
            throw GreetMeAPIError.decoding
        }
    }

    /// Download the cover image data for attaching to an MSMessage layout.
    func downloadImage(urlString: String) async throws -> Data {
        guard let url = URL(string: urlString) else { throw GreetMeAPIError.invalidResponse }
        let (data, response) = try await session.data(from: url)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw GreetMeAPIError.invalidResponse
        }
        return data
    }

    // MARK: - Helpers

    private static func validate(response: URLResponse, data: Data) throws {
        guard let http = response as? HTTPURLResponse else { throw GreetMeAPIError.invalidResponse }
        if !(200..<300).contains(http.statusCode) {
            if let errorBody = try? JSONDecoder().decode(GreetMeErrorResponse.self, from: data) {
                throw GreetMeAPIError.server(errorBody.error)
            }
            throw GreetMeAPIError.server("Request failed with status \(http.statusCode).")
        }
    }

    private static func decodePayload(data: Data, response: URLResponse) throws -> GreetMeCardPayload {
        try validate(response: response, data: data)
        do {
            return try JSONDecoder().decode(GreetMeCardPayload.self, from: data)
        } catch {
            throw GreetMeAPIError.decoding
        }
    }
}
