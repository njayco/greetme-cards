//
//  ExtensionViewModel.swift
//  GreetMe iMessage Extension
//

import Combine
import Foundation

@MainActor
final class ExtensionViewModel: ObservableObject {
    enum Mode: Equatable, Hashable {
        case browse
        case viewCard(id: String)
    }

    @Published var mode: Mode = .browse
}
