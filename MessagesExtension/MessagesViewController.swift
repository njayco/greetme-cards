//
//  MessagesViewController.swift
//  GreetMe iMessage Extension
//

import UIKit
import Messages
import SwiftUI

class MessagesViewController: MSMessagesAppViewController {

    private static let surfaceColor = UIColor(red: 0.106, green: 0.078, blue: 0.063, alpha: 1)

    private let viewModel = ExtensionViewModel()
    private var hostingController: UIHostingController<AnyView>?

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = Self.surfaceColor
        configureNavigationAppearance()
        mountExtensionUIIfNeeded()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        layoutHostingController()
    }

    override func willBecomeActive(with conversation: MSConversation) {
        super.willBecomeActive(with: conversation)
        applyCardContext(from: conversation)
        mountExtensionUIIfNeeded()
        refreshExtensionUI()
    }

    override func didBecomeActive(with conversation: MSConversation) {
        super.didBecomeActive(with: conversation)
        applyCardContext(from: conversation)
        mountExtensionUIIfNeeded()
        refreshExtensionUI()
    }

    override func didSelect(_ message: MSMessage, conversation: MSConversation) {
        super.didSelect(message, conversation: conversation)
        if let cardId = Self.extractCardId(from: message) {
            viewModel.mode = .viewCard(id: cardId)
            requestPresentationStyle(.expanded)
            refreshExtensionUI()
        }
    }

    override func willTransition(to presentationStyle: MSMessagesAppPresentationStyle) {
        super.willTransition(to: presentationStyle)
        layoutHostingController()
    }

    // MARK: - UI

    private func configureNavigationAppearance() {
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = Self.surfaceColor
        appearance.titleTextAttributes = [.foregroundColor: UIColor.white]
        UINavigationBar.appearance().standardAppearance = appearance
        UINavigationBar.appearance().scrollEdgeAppearance = appearance
        UINavigationBar.appearance().compactAppearance = appearance
        UINavigationBar.appearance().tintColor = UIColor(red: 0.79, green: 0.64, blue: 0.29, alpha: 1)
    }

    private func applyCardContext(from conversation: MSConversation) {
        if let message = conversation.selectedMessage,
           let cardId = Self.extractCardId(from: message),
           Self.isGreetMeCardURL(message.url) {
            viewModel.mode = .viewCard(id: cardId)
            if presentationStyle == .compact {
                requestPresentationStyle(.expanded)
            }
        } else if case .viewCard = viewModel.mode {
            // Keep preview while active.
        } else {
            viewModel.mode = .browse
        }
    }

    private func refreshExtensionUI() {
        mountExtensionUIIfNeeded()
        hostingController?.rootView = AnyView(makeExtensionRootView())
        layoutHostingController()
    }

    private func mountExtensionUIIfNeeded() {
        guard hostingController == nil else { return }

        let host = UIHostingController(rootView: AnyView(makeExtensionRootView()))
        host.view.backgroundColor = Self.surfaceColor
        host.view.isOpaque = true
        host.view.translatesAutoresizingMaskIntoConstraints = false

        addChild(host)
        view.addSubview(host.view)

        NSLayoutConstraint.activate([
            host.view.topAnchor.constraint(equalTo: view.topAnchor),
            host.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            host.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            host.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        ])

        host.didMove(toParent: self)
        hostingController = host
        layoutHostingController()
    }

    private func makeExtensionRootView() -> some View {
        ExtensionRootView(
            viewModel: viewModel,
            onRequestExpand: { [weak self] in
                self?.requestPresentationStyle(.expanded)
            },
            onSend: { [weak self] payload in
                self?.insertCard(payload)
            },
            onOpenURL: { [weak self] url in
                self?.extensionContext?.open(url, completionHandler: nil)
            },
            onBrowseCards: { [weak self] in
                self?.viewModel.mode = .browse
                self?.refreshExtensionUI()
            }
        )
        .id(viewModel.mode)
    }

    private func layoutHostingController() {
        hostingController?.view.setNeedsLayout()
        hostingController?.view.layoutIfNeeded()
    }

    // MARK: - MSMessage insertion

    private func insertCard(_ payload: GreetMeCardPayload) {
        guard let conversation = activeConversation else { return }

        Task {
            var coverImage: UIImage?
            if !payload.coverImageUrl.isEmpty {
                if let data = try? await GreetMeAPIClient().downloadImage(urlString: payload.coverImageUrl) {
                    coverImage = UIImage(data: data)
                }
            }

            await MainActor.run {
                let layout = MSMessageTemplateLayout()
                layout.image = coverImage
                layout.imageTitle = payload.title
                layout.imageSubtitle = "From \(payload.senderName)"
                layout.caption = Self.extrasSummary(for: payload)

                let message = MSMessage()
                message.layout = layout
                // Web URL for recipients without the extension; extension handles taps in-app.
                message.url = payload.canonicalShareURL

                conversation.insert(message) { error in
                    if let error = error {
                        print("Failed to insert GreetMe message: \(error.localizedDescription)")
                        return
                    }
                    // Return to the conversation with the card in the compose field;
                    // user taps the blue send button in Messages to deliver it.
                    self.dismiss()
                }
            }
        }
    }

    private static func extrasSummary(for payload: GreetMeCardPayload) -> String {
        var extras: [String] = []
        if payload.hasVoiceNote { extras.append("Voice Note") }
        if payload.hasYoutube { extras.append("Music Clip") }
        if payload.hasCashGift { extras.append("Cash Gift") }

        if extras.isEmpty {
            return "Tap to view your GreetMe"
        }
        return "Includes " + extras.joined(separator: " + ")
    }

    static func extractCardId(from message: MSMessage?) -> String? {
        extractCardId(from: message?.url)
    }

    static func extractCardId(from url: URL?) -> String? {
        guard let url else { return nil }

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
        if url.scheme?.lowercased() == "greetme" {
            return extractCardId(from: url) != nil
        }
        guard let host = url.host else { return false }
        return GreetMeConfig.isGreetMeHost(host)
    }
}

// MARK: - SwiftUI root

private struct ExtensionRootView: View {
    @ObservedObject var viewModel: ExtensionViewModel
    let onRequestExpand: () -> Void
    let onSend: (GreetMeCardPayload) -> Void
    let onOpenURL: (URL) -> Void
    let onBrowseCards: () -> Void

    var body: some View {
        ZStack {
            GreetMeTheme.background.ignoresSafeArea()
            Group {
                switch viewModel.mode {
                case .browse:
                    CardBuilderView(
                        onRequestExpand: onRequestExpand,
                        onSend: onSend,
                        onOpenURL: onOpenURL
                    )
                case .viewCard(let id):
                    NavigationStack {
                        CardViewerView(
                            cardId: id,
                            onOpenURL: onOpenURL,
                            onBrowseCards: onBrowseCards
                        )
                    }
                }
            }
        }
        .tint(GreetMeTheme.gold)
        .preferredColorScheme(.dark)
    }
}
