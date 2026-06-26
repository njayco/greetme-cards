//
//  CardWebView.swift
//  GreetMe iMessage Extension
//
//  Embeds the GreetMe card preview page inside the extension.
//

import SwiftUI
import WebKit

struct CardWebView: UIViewRepresentable {
    let url: URL

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.isOpaque = false
        webView.backgroundColor = UIColor(red: 0.106, green: 0.078, blue: 0.063, alpha: 1)
        webView.scrollView.backgroundColor = UIColor(red: 0.106, green: 0.078, blue: 0.063, alpha: 1)
        webView.scrollView.isScrollEnabled = false
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        guard context.coordinator.loadedURL != url else { return }
        context.coordinator.loadedURL = url
        webView.load(URLRequest(url: url))
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    final class Coordinator {
        var loadedURL: URL?
    }
}
