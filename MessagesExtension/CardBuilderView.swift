//
//  CardBuilderView.swift
//  GreetMe iMessage Extension
//
//  Root of the SwiftUI flow shown inside Messages. Presents the dark
//  "browse home" (categories, popular cards, prices, feature rows) backed by
//  the live /api/imessage/catalog endpoint, and pushes the customize screen
//  when a card is tapped.
//

import SwiftUI
import Combine

// MARK: - Catalog loader

@MainActor
final class CatalogModel: ObservableObject {
    @Published var catalog: GreetMeCatalog?
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let api = GreetMeAPIClient()

    func loadIfNeeded() async {
        guard catalog == nil, !isLoading else { return }
        await load()
    }

    func load() async {
        isLoading = true
        errorMessage = nil
        do {
            catalog = try await api.fetchCatalog()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}

// MARK: - Root

struct CardBuilderView: View {
    let onRequestExpand: () -> Void
    let onSend: (GreetMeCardPayload) -> Void
    let onOpenURL: (URL) -> Void

    @StateObject private var model = CatalogModel()
    @State private var path: [GreetMeCatalogCard] = []

    var body: some View {
        NavigationStack(path: $path) {
            HomeBrowseView(
                model: model,
                onSelect: { card in
                    onRequestExpand()
                    path.append(card)
                }
            )
            .navigationDestination(for: GreetMeCatalogCard.self) { card in
                CustomizeCardView(
                    card: card,
                    onSend: onSend,
                    onOpenURL: onOpenURL
                )
            }
        }
        .background(GreetMeTheme.background.ignoresSafeArea())
        .toolbarBackground(GreetMeTheme.background, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .tint(GreetMeTheme.gold)
        .preferredColorScheme(.dark)
        .task { await model.loadIfNeeded() }
    }
}

// MARK: - Browse home

struct HomeBrowseView: View {
    @ObservedObject var model: CatalogModel
    let onSelect: (GreetMeCatalogCard) -> Void

    @State private var searchText = ""
    /// nil == the "Popular" tab.
    @State private var selectedCategoryId: String?

    var body: some View {
        ZStack {
            GreetMeTheme.background.ignoresSafeArea()

            if model.isLoading && model.catalog == nil {
                ProgressView()
                    .tint(GreetMeTheme.gold)
            } else if let error = model.errorMessage, model.catalog == nil {
                errorState(error)
            } else if let catalog = model.catalog {
                content(catalog)
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(GreetMeTheme.background, for: .navigationBar)
    }

    @ViewBuilder
    private func content(_ catalog: GreetMeCatalog) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header(total: catalog.totalCards)
                searchField
                categoryTabs(catalog)

                if !searchText.trimmingCharacters(in: .whitespaces).isEmpty {
                    searchResults(catalog)
                } else if let catId = selectedCategoryId,
                          let category = catalog.categories.first(where: { $0.id == catId }) {
                    categoryGrid(category.cards)
                } else {
                    popularSection(catalog)
                    featureRows
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 28)
        }
        .scrollContentBackground(.hidden)
    }

    // MARK: Sections

    private func header(total: Int) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("GreetMe")
                .font(.system(size: 34, weight: .bold, design: .serif))
                .foregroundColor(GreetMeTheme.gold)
            Text("Cards worth keeping · \(total)+ designs")
                .font(.subheadline)
                .foregroundColor(GreetMeTheme.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 8)
    }

    private var searchField: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(GreetMeTheme.textMuted)
            TextField("", text: $searchText, prompt: Text("Search cards").foregroundColor(GreetMeTheme.textMuted))
                .foregroundColor(GreetMeTheme.textPrimary)
                .autocorrectionDisabled()
            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(GreetMeTheme.textMuted)
                }
            }
        }
        .padding(12)
        .background(GreetMeTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(GreetMeTheme.border, lineWidth: 1)
        )
    }

    private func categoryTabs(_ catalog: GreetMeCatalog) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                tabChip(title: "Popular", isSelected: selectedCategoryId == nil) {
                    selectedCategoryId = nil
                }
                ForEach(catalog.categories) { category in
                    tabChip(title: category.name, isSelected: selectedCategoryId == category.id) {
                        selectedCategoryId = category.id
                    }
                }
            }
            .padding(.vertical, 2)
        }
    }

    private func tabChip(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundColor(isSelected ? GreetMeTheme.background : GreetMeTheme.textSecondary)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(isSelected ? GreetMeTheme.gold : GreetMeTheme.surface)
                .clipShape(Capsule())
                .overlay(
                    Capsule().stroke(isSelected ? Color.clear : GreetMeTheme.border, lineWidth: 1)
                )
        }
    }

    private func popularSection(_ catalog: GreetMeCatalog) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("Popular Cards")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
                    ForEach(catalog.popular) { card in
                        Button {
                            onSelect(card)
                        } label: {
                            CardThumbnail(card: card, width: 150)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 2)
            }
        }
    }

    private func categoryGrid(_ cards: [GreetMeCatalogCard]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("\(cards.count) cards")
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)], spacing: 18) {
                ForEach(cards) { card in
                    Button { onSelect(card) } label: {
                        CardThumbnail(card: card, width: nil)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func searchResults(_ catalog: GreetMeCatalog) -> some View {
        let query = searchText.trimmingCharacters(in: .whitespaces).lowercased()
        var seen = Set<Int>()
        var matches: [GreetMeCatalogCard] = []
        for category in catalog.categories {
            for card in category.cards where !seen.contains(card.id) {
                if card.title.lowercased().contains(query) || card.categoryName.lowercased().contains(query) {
                    seen.insert(card.id)
                    matches.append(card)
                }
            }
        }
        return Group {
            if matches.isEmpty {
                VStack(spacing: 8) {
                    Text("No cards found")
                        .font(.headline)
                        .foregroundColor(GreetMeTheme.textPrimary)
                    Text("Try a different search.")
                        .font(.subheadline)
                        .foregroundColor(GreetMeTheme.textSecondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 40)
            } else {
                categoryGrid(matches)
            }
        }
    }

    private var featureRows: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("Make it unforgettable")
            featureRow(icon: "music.note", tint: GreetMeTheme.danger,
                       title: "GreetMe Clips",
                       subtitle: "Attach a 30-second song clip from YouTube.")
            featureRow(icon: "mic.fill", tint: GreetMeTheme.teal,
                       title: "Voice Notes",
                       subtitle: "Record a personal message in your own voice.")
            featureRow(icon: "dollarsign.circle.fill", tint: GreetMeTheme.gold,
                       title: "Cash Gifting",
                       subtitle: "Add a Cash App gift they can request in a tap.")
        }
    }

    private func featureRow(icon: String, tint: Color, title: String, subtitle: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(tint)
                .frame(width: 44, height: 44)
                .background(GreetMeTheme.surfaceElevated)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(GreetMeTheme.textPrimary)
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(GreetMeTheme.textSecondary)
            }
            Spacer()
        }
        .padding(12)
        .background(GreetMeTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(.title3.weight(.bold))
            .foregroundColor(GreetMeTheme.textPrimary)
    }

    private func errorState(_ message: String) -> some View {
        VStack(spacing: 14) {
            Text("Couldn't load cards")
                .font(.headline)
                .foregroundColor(GreetMeTheme.textPrimary)
            Text(message)
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .foregroundColor(GreetMeTheme.textSecondary)
            Button {
                Task { await model.load() }
            } label: {
                Text("Try again")
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

// MARK: - Card thumbnail

struct CardThumbnail: View {
    let card: GreetMeCatalogCard
    /// Fixed width for horizontal strips; nil to fill a grid cell.
    let width: CGFloat?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(GreetMeTheme.surfaceElevated)
                AsyncImage(url: URL(string: card.coverImageUrl)) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().scaledToFill()
                    case .failure:
                        Image(systemName: "photo")
                            .font(.title)
                            .foregroundColor(GreetMeTheme.textMuted)
                    default:
                        ProgressView().tint(GreetMeTheme.gold)
                    }
                }
            }
            .frame(width: width)
            .aspectRatio(3.0 / 4.0, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(GreetMeTheme.border, lineWidth: 1)
            )

            Text(card.title)
                .font(.subheadline.weight(.semibold))
                .foregroundColor(GreetMeTheme.textPrimary)
                .lineLimit(1)
            HStack {
                Text(card.categoryName)
                    .font(.caption)
                    .foregroundColor(GreetMeTheme.textSecondary)
                    .lineLimit(1)
                Spacer()
                Text(GreetMeTheme.priceLabel(card.price))
                    .font(.caption.weight(.bold))
                    .foregroundColor(card.price <= 0 ? GreetMeTheme.teal : GreetMeTheme.gold)
            }
        }
        .frame(width: width)
    }
}
