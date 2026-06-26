//
//  VoiceRecorder.swift
//  GreetMe iMessage Extension
//
//  Thin AVAudioRecorder wrapper for capturing a short personal voice note
//  (capped at 30 seconds, AAC/.m4a) to a temporary file. The customize screen
//  observes this and uploads the file via GreetMeAPIClient.uploadVoiceNote.
//  Includes AVAudioPlayer-based playback so users can preview the note before
//  sending.
//
//  Requires NSMicrophoneUsageDescription in Info.plist.
//

import Foundation
import Combine
import AVFoundation

@MainActor
final class VoiceRecorder: NSObject, ObservableObject {
    @Published var isRecording = false
    @Published var elapsed: TimeInterval = 0
    @Published var recordedURL: URL?
    @Published var permissionDenied = false

    // Playback
    @Published var isPlaying = false
    @Published var playbackElapsed: TimeInterval = 0

    /// Hard cap on a voice note's length.
    let maxDuration: TimeInterval = 30

    private var recorder: AVAudioRecorder?
    private var timer: Timer?

    private var player: AVAudioPlayer?
    private var playbackTimer: Timer?

    func toggle() {
        isRecording ? stop() : start()
    }

    func start() {
        stopPlayback()
        AVAudioSession.sharedInstance().requestRecordPermission { [weak self] granted in
            DispatchQueue.main.async {
                guard let self else { return }
                if granted {
                    self.beginRecording()
                } else {
                    self.permissionDenied = true
                }
            }
        }
    }

    private func beginRecording() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord, mode: .default)
            try session.setActive(true)

            let url = FileManager.default.temporaryDirectory
                .appendingPathComponent("greetme-voice-\(UUID().uuidString).m4a")
            let settings: [String: Any] = [
                AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
                AVSampleRateKey: 44100,
                AVNumberOfChannelsKey: 1,
                AVEncoderAudioQualityKey: AVAudioQuality.medium.rawValue,
            ]
            let rec = try AVAudioRecorder(url: url, settings: settings)
            rec.delegate = self
            rec.record()

            recorder = rec
            recordedURL = nil
            elapsed = 0
            isRecording = true
            startTimer()
        } catch {
            isRecording = false
            recorder = nil
        }
    }

    func stop() {
        recorder?.stop()
        timer?.invalidate()
        timer = nil
        isRecording = false
        try? AVAudioSession.sharedInstance().setActive(false)
    }

    /// Discard the current recording so the user can start over.
    func reset() {
        stopPlayback()
        if let url = recordedURL {
            try? FileManager.default.removeItem(at: url)
        }
        recordedURL = nil
        elapsed = 0
        playbackElapsed = 0
    }

    // MARK: - Playback

    func togglePlayback() {
        isPlaying ? stopPlayback() : startPlayback()
    }

    func startPlayback() {
        guard let url = recordedURL else { return }
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default)
            try session.setActive(true)
            let p = try AVAudioPlayer(contentsOf: url)
            p.delegate = self
            p.play()
            player = p
            playbackElapsed = 0
            isPlaying = true
            startPlaybackTimer()
        } catch {
            isPlaying = false
        }
    }

    func stopPlayback() {
        player?.stop()
        player = nil
        playbackTimer?.invalidate()
        playbackTimer = nil
        isPlaying = false
        playbackElapsed = 0
    }

    private func startPlaybackTimer() {
        playbackTimer?.invalidate()
        playbackTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self, self.isPlaying, let p = self.player else { return }
                self.playbackElapsed = p.currentTime
            }
        }
    }

    private func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self, self.isRecording else { return }
                self.elapsed += 0.1
                if self.elapsed >= self.maxDuration {
                    self.stop()
                }
            }
        }
    }
}

extension VoiceRecorder: AVAudioRecorderDelegate {
    nonisolated func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        let url = recorder.url
        Task { @MainActor in
            if flag {
                self.recordedURL = url
            }
        }
    }
}

extension VoiceRecorder: AVAudioPlayerDelegate {
    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in
            self.isPlaying = false
            self.playbackElapsed = 0
            self.player = nil
            self.playbackTimer?.invalidate()
            self.playbackTimer = nil
        }
    }
}
