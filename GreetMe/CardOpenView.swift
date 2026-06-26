//
//  CardOpenView.swift
//  GreetMe
//
//  Full-screen card preview when the app opens from a GreetMe card link.
//

import SwiftUI
import WebKit

struct CardOpenView: View {
    let cardId: String

    var body: some View {
        ZStack {
            Color(red: 0.106, green: 0.078, blue: 0.063).ignoresSafeArea()
            VStack(spacing: 0) {
                Text("GreetMe Card")
                    .font(.headline)
                    .foregroundColor(Color(red: 0.79, green: 0.64, blue: 0.29))
                    .padding(.vertical, 12)
                CardWebContainer(url: GreetMeCardURL.previewURL(for: cardId))
            }
        }
    }
}

private struct CardWebContainer: UIViewRepresentable {
    let url: URL

    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.isOpaque = false
        webView.backgroundColor = UIColor(red: 0.106, green: 0.078, blue: 0.063, alpha: 1)
        webView.load(URLRequest(url: url))
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {}
}
