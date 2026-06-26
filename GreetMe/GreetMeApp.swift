//
//  GreetMeApp.swift
//  GreetMe
//

import SwiftUI

@main
struct GreetMeApp: App {
    @State private var openedCardId: String?

    var body: some Scene {
        WindowGroup {
            Group {
                if let cardId = openedCardId {
                    CardOpenView(cardId: cardId)
                } else {
                    ContentView()
                }
            }
            .onOpenURL { url in
                if let cardId = GreetMeCardURL.extractCardId(from: url) {
                    openedCardId = cardId
                }
            }
        }
    }
}
