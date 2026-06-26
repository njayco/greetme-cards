//
//  Theme.swift
//  GreetMe iMessage Extension
//
//  Shared dark "vintage bookshelf" palette and small formatting helpers used
//  across the extension UI. Matches the warm tan/gold + teal look of the web
//  app, adapted for the compact dark surface inside Messages.
//

import SwiftUI

extension Color {
    /// Create a Color from a hex string like "C9A24B" or "#C9A24B".
    init(hex: String) {
        let cleaned = hex.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "#", with: "")
        var value: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&value)
        let r, g, b: Double
        if cleaned.count == 6 {
            r = Double((value & 0xFF0000) >> 16) / 255
            g = Double((value & 0x00FF00) >> 8) / 255
            b = Double(value & 0x0000FF) / 255
        } else {
            r = 0; g = 0; b = 0
        }
        self.init(.sRGB, red: r, green: g, blue: b, opacity: 1)
    }
}

enum GreetMeTheme {
    static let background = Color(hex: "1B1410")
    static let surface = Color(hex: "271D16")
    static let surfaceElevated = Color(hex: "33271D")
    static let border = Color(hex: "4A3A2B")
    static let gold = Color(hex: "C9A24B")
    static let goldBright = Color(hex: "E0B95C")
    static let teal = Color(hex: "4EAAA2")
    static let textPrimary = Color(hex: "F5ECE0")
    static let textSecondary = Color(hex: "B8A88F")
    static let textMuted = Color(hex: "8A7A64")
    static let danger = Color(hex: "E06C5C")

    /// "Free" for zero/none, otherwise a "$0.99"-style label.
    static func priceLabel(_ price: Double) -> String {
        price <= 0 ? "Free" : String(format: "$%.2f", price)
    }
}
