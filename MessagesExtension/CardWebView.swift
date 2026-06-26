//
//  CardWebView.swift
//  GreetMe iMessage Extension
//
//  General-purpose WKWebView wrapper for displaying GreetMe web pages.
//  A Safari-compatible user agent is always set so that YouTube iframes and
//  other media load correctly inside the extension.
//

import SwiftUI
import WebKit

// MARK: - CardWebView (GreetMe pages)

struct CardWebView: UIViewRepresentable {
    let url: URL
    var allowScrolling: Bool = false

    // Matches Mobile Safari so YouTube iframes and other CDN-gated media load.
    private static let safariUA =
        "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) " +
        "AppleWebKit/605.1.15 (KHTML, like Gecko) " +
        "Version/17.0 Mobile/15E148 Safari/604.1"

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.customUserAgent = Self.safariUA
        webView.isOpaque = false
        webView.backgroundColor = UIColor(red: 0.106, green: 0.078, blue: 0.063, alpha: 1)
        webView.scrollView.backgroundColor = UIColor(red: 0.106, green: 0.078, blue: 0.063, alpha: 1)
        webView.scrollView.isScrollEnabled = allowScrolling
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        guard context.coordinator.loadedURL != url else { return }
        context.coordinator.loadedURL = url
        webView.load(URLRequest(url: url))
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator {
        var loadedURL: URL?
    }
}

// MARK: - YouTubeEmbedView

/// Embeds a YouTube video using loadHTMLString with youtube.com as the base
/// URL. This bypasses WKWebView's cross-origin iframe restrictions and ensures
/// the IFrame Player API loads and plays inline without leaving the extension.
struct YouTubeEmbedView: UIViewRepresentable {
    let videoId: String
    let startSeconds: Int

    private static let safariUA =
        "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) " +
        "AppleWebKit/605.1.15 (KHTML, like Gecko) " +
        "Version/17.0 Mobile/15E148 Safari/604.1"

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.customUserAgent = Self.safariUA
        webView.isOpaque = true
        webView.backgroundColor = .black
        webView.scrollView.backgroundColor = .black
        webView.scrollView.isScrollEnabled = false
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        guard context.coordinator.loaded == false else { return }
        context.coordinator.loaded = true

        let html = """
        <!DOCTYPE html>
        <html>
        <head>
        <meta name="viewport" content="width=device-width, initial-scale=1, maximum-scale=1">
        <style>
          * { margin: 0; padding: 0; box-sizing: border-box; }
          body {
            background: #000;
            width: 100vw;
            height: 100vh;
            display: flex;
            align-items: center;
            justify-content: center;
          }
          .wrap {
            width: 100%;
            position: relative;
            padding-bottom: 56.25%;
          }
          iframe {
            position: absolute;
            inset: 0;
            width: 100%;
            height: 100%;
            border: none;
          }
        </style>
        </head>
        <body>
        <div class="wrap">
          <iframe
            src="https://www.youtube.com/embed/\(videoId)?start=\(startSeconds)&playsinline=1&rel=0&modestbranding=1"
            allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture"
            allowfullscreen>
          </iframe>
        </div>
        </body>
        </html>
        """

        // Using youtube.com as the baseURL lets the iframe embed load without
        // cross-origin blocks and tells YouTube's player the page is trusted.
        webView.loadHTMLString(html, baseURL: URL(string: "https://www.youtube.com")!)
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator {
        var loaded = false
    }
}
