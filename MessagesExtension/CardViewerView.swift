//
//  CardViewerView.swift
//  GreetMe iMessage Extension
//

import SwiftUI
import Combine

@MainActor
final class CardViewerModel: ObservableObject {
    @Published var card: GreetMeCardPayload?
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let api = GreetMeAPIClient()

    func load(cardId: String) async {
        isLoading = true
        errorMessage = nil
        do {
            card = try await api.fetchCard(id: cardId)
        } catch {
            errorMessage = error.localizedDescription
            card = nil
        }
        isLoading = false
    }
}

struct CardViewerView: View {
    let cardId: String
    let onOpenURL: (URL) -> Void
    let onBrowseCards: () -> Void

    @StateObject private var model = CardViewerModel()

    var body: some View {
        ZStack {
            GreetMeTheme.background.ignoresSafeArea()

            if model.isLoading && model.card == nil {
                ProgressView("Loading card…")
                    .tint(GreetMeTheme.gold)
                    .foregroundColor(GreetMeTheme.textSecondary)
            } else if let error = model.errorMessage, model.card == nil {
                errorState(error)
            } else if let card = model.card {
                cardContent(card)
            } else {
                Text("No card found.")
                    .foregroundColor(GreetMeTheme.textSecondary)
            }
        }
        .navigationTitle("GreetMe Card")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(GreetMeTheme.background, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Browse", action: onBrowseCards)
                    .foregroundColor(GreetMeTheme.gold)
            }
        }
        .task(id: cardId) { await model.load(cardId: cardId) }
    }

    private func cardContent(_ card: GreetMeCardPayload) -> some View {
        ScrollView {
            VStack(spacing: 16) {
                header(card)

                CardWebView(url: card.previewPageURL)
                    .frame(minHeight: 420)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(GreetMeTheme.border, lineWidth: 1)
                    )

                extras(card)
                openButton(card)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
    }

    private func header(_ card: GreetMeCardPayload) -> some View {
        VStack(spacing: 6) {
            Text(card.title)
                .font(.title3.weight(.bold))
                .multilineTextAlignment(.center)
                .foregroundColor(GreetMeTheme.textPrimary)
            Text("To \(card.recipientName) · From \(card.senderName)")
                .font(.subheadline)
                .foregroundColor(GreetMeTheme.textSecondary)
        }
    }

    private func coverFallback(_ card: GreetMeCardPayload) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(GreetMeTheme.surfaceElevated)
            AsyncImage(url: URL(string: card.coverImageUrl)) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().scaledToFill()
                case .failure:
                    Image(systemName: "photo")
                        .font(.largeTitle)
                        .foregroundColor(GreetMeTheme.textMuted)
                default:
                    ProgressView().tint(GreetMeTheme.gold)
                }
            }
        }
        .frame(maxWidth: 280)
        .aspectRatio(3.0 / 4.0, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    @ViewBuilder
    private func extras(_ card: GreetMeCardPayload) -> some View {
        let items = extraItems(for: card)
        if !items.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(items, id: \.self) { item in
                        Text(item)
                            .font(.caption.weight(.semibold))
                            .foregroundColor(GreetMeTheme.textPrimary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(GreetMeTheme.surfaceElevated)
                            .clipShape(Capsule())
                    }
                }
            }
        }
    }

    private func extraItems(for card: GreetMeCardPayload) -> [String] {
        var items: [String] = []
        if card.hasVoiceNote { items.append("Voice Note") }
        if card.hasYoutube { items.append("Music Clip") }
        if card.hasCashGift { items.append("Cash Gift") }
        if card.hasMusic { items.append("Music") }
        return items
    }

    private func openButton(_ card: GreetMeCardPayload) -> some View {
        Button {
            onOpenURL(card.canonicalShareURL)
        } label: {
            HStack {
                Spacer()
                Label("Open Full Card", systemImage: "arrow.up.right.square")
                    .font(.headline)
                    .foregroundColor(GreetMeTheme.background)
                Spacer()
            }
            .padding(.vertical, 16)
            .background(GreetMeTheme.gold)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
    }

    private func errorState(_ message: String) -> some View {
        VStack(spacing: 14) {
            Text("Couldn't load card")
                .font(.headline)
                .foregroundColor(GreetMeTheme.textPrimary)
            Text(message)
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .foregroundColor(GreetMeTheme.textSecondary)
            Button(action: onBrowseCards) {
                Text("Browse cards")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(GreetMeTheme.background)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(GreetMeTheme.gold)
                    .clipShape(Capsule())
            }
        }
        .padding(24)
    }
}
