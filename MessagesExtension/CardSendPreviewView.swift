//
//  CardSendPreviewView.swift
//  GreetMe iMessage Extension
//
//  Preview of a created card before sending. Shows:
//   • Swipeable cover / inside pages (cover = native image, inside = web preview)
//   • Native voice-note player (local recording or server URL)
//   • In-app YouTube clip preview sheet
//   • Send and Edit actions
//

import SwiftUI
import AVFoundation
import Combine

// MARK: - Main view

struct CardSendPreviewView: View {
    let payload: GreetMeCardPayload
    /// Local recording file so the user can preview their voice note before it's sent.
    var localVoiceNoteURL: URL? = nil
    /// YouTube video id from the customization form.
    var youtubeVideoId: String? = nil
    /// Start offset (seconds) for the music clip.
    var youtubeStartSeconds: Int = 0
    let onSend: (GreetMeCardPayload) -> Void
    let onEdit: () -> Void
    let onOpenURL: (URL) -> Void

    @State private var selectedPage = 0
    @State private var showYouTubeSheet = false
    @StateObject private var audioPlayer = VoiceNotePreviewPlayer()

    var body: some View {
        ZStack {
            GreetMeTheme.background.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 20) {
                    header
                    cardPager
                    if payload.hasVoiceNote {
                        voiceNoteRow
                    }
                    if payload.hasYoutube {
                        musicClipRow
                    }
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
        .sheet(isPresented: $showYouTubeSheet) {
            YouTubePreviewSheet(
                videoId: youtubeVideoId ?? "",
                startSeconds: youtubeStartSeconds
            )
        }
        .task {
            // Load voice note audio: prefer local recording, fall back to server URL.
            if let local = localVoiceNoteURL {
                audioPlayer.load(url: local)
            } else if let urlStr = payload.voiceNoteUrl, let url = URL(string: urlStr) {
                audioPlayer.load(url: url)
            }
        }
        .onDisappear { audioPlayer.stop() }
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: 6) {
            Text(payload.title)
                .font(.title3.weight(.bold))
                .multilineTextAlignment(.center)
                .foregroundColor(GreetMeTheme.textPrimary)
            Text("To \(payload.recipientName) · From \(payload.senderName)")
                .font(.subheadline)
                .foregroundColor(GreetMeTheme.textSecondary)
            HStack(spacing: 4) {
                Image(systemName: "hand.draw")
                    .font(.caption2)
                Text("Swipe to see inside the card")
                    .font(.caption)
            }
            .foregroundColor(GreetMeTheme.textMuted)
        }
    }

    // MARK: - Paged card (Cover → Inside)

    private var cardPager: some View {
        VStack(spacing: 10) {
            TabView(selection: $selectedPage) {
                coverPage.tag(0)
                insidePage.tag(1)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .frame(minHeight: 440)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(GreetMeTheme.border, lineWidth: 1)
            )

            // Pill indicator
            HStack(spacing: 6) {
                ForEach(0..<2, id: \.self) { i in
                    Capsule()
                        .fill(i == selectedPage ? GreetMeTheme.gold : GreetMeTheme.textMuted.opacity(0.35))
                        .frame(width: i == selectedPage ? 20 : 6, height: 6)
                        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: selectedPage)
                }
                Text(selectedPage == 0 ? "Cover" : "Inside")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(GreetMeTheme.textMuted)
            }
        }
    }

    // Page 0 — native cover image
    private var coverPage: some View {
        ZStack {
            GreetMeTheme.surfaceElevated
            AsyncImage(url: URL(string: payload.coverImageUrl)) { phase in
                switch phase {
                case .success(let img):
                    img.resizable().scaledToFit()
                case .failure:
                    VStack(spacing: 10) {
                        Image(systemName: "photo")
                            .font(.largeTitle)
                            .foregroundColor(GreetMeTheme.textMuted)
                        Text("Cover image unavailable")
                            .font(.caption)
                            .foregroundColor(GreetMeTheme.textMuted)
                    }
                default:
                    ProgressView().tint(GreetMeTheme.gold)
                }
            }
        }
        .pageLabel("Cover", icon: "rectangle.portrait")
    }

    // Page 1 — full card experience (cover, inside, media) via the canonical share URL
    private var insidePage: some View {
        ZStack {
            GreetMeTheme.surfaceElevated
            CardWebView(url: payload.canonicalShareURL, allowScrolling: true)
        }
        .pageLabel("Inside + Media", icon: "rectangle.portrait.on.rectangle.portrait")
    }

    // MARK: - Voice note player

    private var voiceNoteRow: some View {
        HStack(spacing: 14) {
            Image(systemName: "waveform")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(GreetMeTheme.teal)
                .frame(width: 36, height: 36)
                .background(GreetMeTheme.surfaceElevated)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

            VStack(alignment: .leading, spacing: 5) {
                Text("Voice Note")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(GreetMeTheme.textPrimary)

                if audioPlayer.isReady && audioPlayer.duration > 0 {
                    ProgressView(value: audioPlayer.progress)
                        .tint(GreetMeTheme.teal)
                        .animation(.linear(duration: 0.1), value: audioPlayer.progress)
                    Text("\(timeString(audioPlayer.currentTime)) / \(timeString(audioPlayer.duration))")
                        .font(.caption2.monospacedDigit())
                        .foregroundColor(GreetMeTheme.textMuted)
                } else {
                    Text(audioPlayer.isReady ? "Tap play to preview" : "Loading…")
                        .font(.caption)
                        .foregroundColor(GreetMeTheme.textMuted)
                }
            }

            Spacer()

            Button {
                audioPlayer.toggle()
            } label: {
                Image(systemName: audioPlayer.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                    .font(.system(size: 40))
                    .foregroundColor(GreetMeTheme.teal)
            }
            .disabled(!audioPlayer.isReady)
        }
        .padding(14)
        .background(GreetMeTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    // MARK: - Music clip row

    private var musicClipRow: some View {
        Button {
            showYouTubeSheet = true
        } label: {
            HStack(spacing: 14) {
                Image(systemName: "music.note")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(GreetMeTheme.danger)
                    .frame(width: 36, height: 36)
                    .background(GreetMeTheme.surfaceElevated)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                VStack(alignment: .leading, spacing: 2) {
                    Text("Music Clip")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(GreetMeTheme.textPrimary)
                    Text("Tap to preview 30-second clip")
                        .font(.caption)
                        .foregroundColor(GreetMeTheme.textSecondary)
                }

                Spacer()

                Image(systemName: "play.circle.fill")
                    .font(.system(size: 40))
                    .foregroundColor(GreetMeTheme.danger)
            }
            .padding(14)
            .background(GreetMeTheme.surface)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(youtubeVideoId == nil)
    }

    // MARK: - Action buttons

    private var actionButtons: some View {
        VStack(spacing: 12) {
            Button(action: send) {
                HStack {
                    Spacer()
                    Label("Send Card", systemImage: "paperplane.fill")
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

    // MARK: - Helpers

    private func send() {
        audioPlayer.stop()
        if payload.requiresPayment == true,
           let checkout = payload.checkoutUrl,
           let url = URL(string: checkout) {
            onOpenURL(url)
        }
        onSend(payload)
    }

    private func timeString(_ t: TimeInterval) -> String {
        let s = max(0, Int(t))
        return String(format: "0:%02d", min(s, 99))
    }
}

// MARK: - Page label modifier

private extension View {
    func pageLabel(_ title: String, icon: String) -> some View {
        overlay(alignment: .bottomLeading) {
            Label(title, systemImage: icon)
                .font(.caption2.weight(.semibold))
                .foregroundColor(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(.black.opacity(0.5))
                .clipShape(Capsule())
                .padding(10)
        }
    }
}

// MARK: - Voice note audio player

@MainActor
final class VoiceNotePreviewPlayer: ObservableObject {
    @Published var isPlaying = false
    @Published var isReady = false
    @Published var duration: TimeInterval = 0
    @Published var currentTime: TimeInterval = 0

    var progress: Double {
        guard duration > 0 else { return 0 }
        return currentTime / duration
    }

    private var player: AVPlayer?
    private var timeObserver: Any?

    func load(url: URL) {
        stop()
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {}

        let item = AVPlayerItem(url: url)
        let p = AVPlayer(playerItem: item)
        player = p

        // Poll readiness and duration via periodic observer.
        let interval = CMTime(value: 1, timescale: 10)
        let observer = p.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            guard let self else { return }
            // Update duration once available.
            if let dur = p.currentItem?.duration, dur.isNumeric, dur.seconds > 0, self.duration == 0 {
                self.duration = dur.seconds
                self.isReady = true
            }
            let ct = time.seconds
            if !ct.isNaN { self.currentTime = ct }
        }
        timeObserver = observer

        // End-of-item reset.
        NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: item,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.isPlaying = false
                self?.currentTime = 0
                self?.player?.seek(to: .zero)
            }
        }

        // Mark ready for short local files once status is known.
        Task {
            for _ in 0..<30 {
                try? await Task.sleep(nanoseconds: 100_000_000)
                if let dur = p.currentItem?.duration, dur.isNumeric, dur.seconds > 0 {
                    self.duration = dur.seconds
                    self.isReady = true
                    break
                }
            }
        }
    }

    func toggle() { isPlaying ? pause() : play() }

    func play() {
        player?.play()
        isPlaying = true
    }

    func pause() {
        player?.pause()
        isPlaying = false
    }

    func stop() {
        player?.pause()
        isPlaying = false
        if let obs = timeObserver {
            player?.removeTimeObserver(obs)
            timeObserver = nil
        }
        player = nil
        isReady = false
        duration = 0
        currentTime = 0
    }
}

// MARK: - YouTube in-app preview sheet

struct YouTubePreviewSheet: View {
    let videoId: String
    let startSeconds: Int
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                if !videoId.isEmpty {
                    YouTubeEmbedView(videoId: videoId, startSeconds: startSeconds)
                        .ignoresSafeArea(edges: .bottom)
                } else {
                    Text("Invalid video link.")
                        .foregroundColor(.white)
                }
            }
            .navigationTitle("Music Clip Preview")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.black, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundColor(.white)
                }
            }
        }
    }
}
