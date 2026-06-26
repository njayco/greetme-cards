//
//  CardSendPreviewView.swift
//  GreetMe iMessage Extension
//
//  Preview a created card before sending, with options to edit or send.
//

import SwiftUI

struct CardSendPreviewView: View {
    let payload: GreetMeCardPayload
    let onSend: (GreetMeCardPayload) -> Void
    let onEdit: () -> Void
    let onOpenURL: (URL) -> Void

    var body: some View {
        ZStack {
            GreetMeTheme.background.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 16) {
                    header
                    cardPreview
                    extras
                    actionButtons
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
        }
        .navigationTitle("Preview")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(GreetMeTheme.background, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Edit", action: onEdit)
                    .foregroundColor(GreetMeTheme.gold)
            }
        }
    }

    private var header: some View {
        VStack(spacing: 6) {
            Text(payload.title)
                .font(.title3.weight(.bold))
                .multilineTextAlignment(.center)
                .foregroundColor(GreetMeTheme.textPrimary)
            Text("To \(payload.recipientName) · From \(payload.senderName)")
                .font(.subheadline)
                .foregroundColor(GreetMeTheme.textSecondary)
            Text("Review your card before sending.")
                .font(.caption)
                .foregroundColor(GreetMeTheme.textMuted)
        }
    }

    @ViewBuilder
    private var cardPreview: some View {
        CardWebView(url: payload.previewPageURL)
            .frame(minHeight: 420)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(GreetMeTheme.border, lineWidth: 1)
            )
    }

    private var coverFallback: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(GreetMeTheme.surfaceElevated)
            AsyncImage(url: URL(string: payload.coverImageUrl)) { phase in
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
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private var extras: some View {
        let items = extraItems
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

    private var extraItems: [String] {
        var items: [String] = []
        if payload.hasVoiceNote { items.append("Voice Note") }
        if payload.hasYoutube { items.append("Music Clip") }
        if payload.hasCashGift { items.append("Cash Gift") }
        if payload.hasMusic { items.append("Music") }
        return items
    }

    private var actionButtons: some View {
        VStack(spacing: 12) {
            Button(action: send) {
                HStack {
                    Spacer()
                    Label("Send", systemImage: "paperplane.fill")
                        .font(.headline)
                        .foregroundColor(GreetMeTheme.background)
                    Spacer()
                }
                .padding(.vertical, 16)
                .background(GreetMeTheme.gold)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }

            Button {
                onOpenURL(payload.canonicalShareURL)
            } label: {
                HStack {
                    Spacer()
                    Label("Open in Browser", systemImage: "safari")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(GreetMeTheme.gold)
                    Spacer()
                }
                .padding(.vertical, 14)
                .background(GreetMeTheme.surface)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(GreetMeTheme.border, lineWidth: 1)
                )
            }
        }
    }

    private func send() {
        if payload.requiresPayment == true,
           let checkout = payload.checkoutUrl,
           let url = URL(string: checkout) {
            onOpenURL(url)
        }
        // Inserts into the message field; extension dismisses so user can tap Send in Messages.
        onSend(payload)
    }
}
