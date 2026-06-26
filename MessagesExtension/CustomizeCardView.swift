//
//  CustomizeCardView.swift
//  GreetMe iMessage Extension
//
//  Second screen of the flow: a large cover preview, To / From / note, and the
//  rich add-ons (YouTube clip, recorded Voice Note, Cash App gift) plus a price
//  summary and Preview / Send actions. Preview shows the card before sending;
//  Send inserts the MSMessage bubble into the conversation.
//

import SwiftUI

struct CustomizeCardView: View {
    let card: GreetMeCatalogCard
    let onSend: (GreetMeCardPayload) -> Void
    let onOpenURL: (URL) -> Void

    // Recipient / sender / note
    @State private var toName = ""
    @State private var fromName = ""
    @State private var note = ""

    // YouTube clip add-on
    @State private var youtubeEnabled = false
    @State private var youtubeLink = ""
    @State private var clipStartSeconds = ""
    @State private var youtubeResolvedTitle: String?
    @State private var youtubeResolvingTitle = false
    @State private var youtubeResolveError: String?

    // Cash gift add-on
    @State private var cashEnabled = false
    @State private var cashtag = ""
    @State private var cashAmount: Int?

    // Voice note add-on
    @StateObject private var recorder = VoiceRecorder()
    @State private var voiceNoteUrl: String?
    @State private var isUploadingVoice = false
    @State private var voiceError: String?

    @State private var isSubmitting = false
    @State private var errorMessage: String?
    @State private var showPreview = false
    @State private var previewPayload: GreetMeCardPayload?

    private let api = GreetMeAPIClient()
    private let cashPresets = [5, 10, 15, 20, 25, 50]
    private let addonPrice = 0.99

    var body: some View {
        ZStack {
            GreetMeTheme.background.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    coverPreview
                    recipientSection
                    voiceNoteSection
                    youtubeSection
                    cashGiftSection
                    priceSummary
                    if let errorMessage {
                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundColor(GreetMeTheme.danger)
                    }
                    previewSendButtons
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 18)
            }
        }
        .navigationTitle("Customize")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(GreetMeTheme.background, for: .navigationBar)
        .tint(GreetMeTheme.gold)
        .navigationDestination(isPresented: $showPreview) {
            if let payload = previewPayload {
                CardSendPreviewView(
                    payload: payload,
                    onSend: onSend,
                    onEdit: { showPreview = false },
                    onOpenURL: onOpenURL
                )
            }
        }
        .onChange(of: recorder.recordedURL) { newURL in
            if let url = newURL { uploadVoice(url) }
        }
    }

    // MARK: - Cover preview

    private var coverPreview: some View {
        VStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(GreetMeTheme.surfaceElevated)
                AsyncImage(url: URL(string: card.coverImageUrl)) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().scaledToFill()
                    case .failure:
                        Image(systemName: "photo")
                            .font(.largeTitle)
                            .foregroundColor(GreetMeTheme.textMuted)
                    default:
                        ProgressView().tint(GreetMeTheme.gold)
                    }
                }
            }
            .frame(maxWidth: 240)
            .aspectRatio(3.0 / 4.0, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(GreetMeTheme.border, lineWidth: 1)
            )

            VStack(spacing: 4) {
                Text(card.title)
                    .font(.title3.weight(.bold))
                    .multilineTextAlignment(.center)
                    .foregroundColor(GreetMeTheme.textPrimary)
                Text("\(card.categoryName) · \(GreetMeTheme.priceLabel(card.price))")
                    .font(.subheadline)
                    .foregroundColor(GreetMeTheme.textSecondary)
            }
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - To / From / note

    private var recipientSection: some View {
        cardSection(title: "Who's it for?") {
            field("To", text: $toName, placeholder: "Recipient's name")
            divider
            field("From", text: $fromName, placeholder: "Your name")
            divider
            VStack(alignment: .leading, spacing: 6) {
                Text("Personal note")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(GreetMeTheme.textMuted)
                TextField("", text: $note, prompt: Text("Write a short message (optional)").foregroundColor(GreetMeTheme.textMuted), axis: .vertical)
                    .lineLimit(2...4)
                    .foregroundColor(GreetMeTheme.textPrimary)
            }
        }
    }

    // MARK: - Voice note

    private var voiceNoteSection: some View {
        cardSection {
            Toggle(isOn: Binding(
                get: { voiceNoteUrl != nil || recorder.isRecording || voiceToggleOn },
                set: { handleVoiceToggle($0) }
            )) {
                addonLabel(icon: "mic.fill", tint: GreetMeTheme.teal,
                           title: "Voice Note",
                           subtitle: "Record up to 30s · +\(GreetMeTheme.priceLabel(addonPrice))")
            }
            .tint(GreetMeTheme.teal)

            if voiceToggleOn {
                divider
                voiceControls
            }
        }
    }

    @State private var voiceToggleOn = false

    private var voiceControls: some View {
        VStack(alignment: .leading, spacing: 10) {
            if recorder.permissionDenied {
                Text("Microphone access is off. Enable it in Settings to record a voice note.")
                    .font(.caption)
                    .foregroundColor(GreetMeTheme.danger)
            }

            HStack(spacing: 12) {
                // Record / stop button
                Button {
                    recorder.toggle()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: recorder.isRecording ? "stop.fill" : "mic.fill")
                        Text(recorder.isRecording ? "Stop" : (recorder.recordedURL == nil ? "Record" : "Re-record"))
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 10)
                    .background(recorder.isRecording ? GreetMeTheme.danger : GreetMeTheme.teal)
                    .clipShape(Capsule())
                }

                // Play / pause preview button — shown once a recording exists locally
                if !recorder.isRecording, let _ = recorder.recordedURL {
                    Button {
                        recorder.togglePlayback()
                    } label: {
                        Image(systemName: recorder.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                            .font(.system(size: 32))
                            .foregroundColor(GreetMeTheme.teal)
                    }
                    .accessibilityLabel(recorder.isPlaying ? "Pause preview" : "Play preview")
                }

                if recorder.isRecording {
                    Text(timeString(recorder.elapsed))
                        .font(.subheadline.monospacedDigit())
                        .foregroundColor(GreetMeTheme.textSecondary)
                } else if recorder.isPlaying {
                    Text(timeString(recorder.playbackElapsed))
                        .font(.subheadline.monospacedDigit())
                        .foregroundColor(GreetMeTheme.textSecondary)
                } else if isUploadingVoice {
                    HStack(spacing: 6) {
                        ProgressView().tint(GreetMeTheme.gold)
                        Text("Uploading…").font(.caption).foregroundColor(GreetMeTheme.textSecondary)
                    }
                } else if voiceNoteUrl != nil {
                    Label("Attached", systemImage: "checkmark.circle.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(GreetMeTheme.teal)
                }
                Spacer()
            }

            if let voiceError {
                Text(voiceError).font(.caption).foregroundColor(GreetMeTheme.danger)
            }
        }
    }

    // MARK: - YouTube clip

    private var youtubeSection: some View {
        cardSection {
            Toggle(isOn: $youtubeEnabled) {
                addonLabel(icon: "music.note", tint: GreetMeTheme.danger,
                           title: "GreetMe Clip",
                           subtitle: "30s YouTube song · +\(GreetMeTheme.priceLabel(addonPrice))")
            }
            .tint(GreetMeTheme.teal)
            .onChange(of: youtubeEnabled) { enabled in
                if !enabled {
                    youtubeLink = ""
                    clipStartSeconds = ""
                    youtubeResolvedTitle = nil
                    youtubeResolveError = nil
                    youtubeResolvingTitle = false
                }
            }

            if youtubeEnabled {
                divider
                VStack(alignment: .leading, spacing: 10) {
                    TextField("", text: $youtubeLink, prompt: Text("Paste a YouTube link").foregroundColor(GreetMeTheme.textMuted))
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .foregroundColor(GreetMeTheme.textPrimary)
                        .onChange(of: youtubeLink) { newValue in
                            handleYouTubeLinkChange(newValue)
                        }
                    TextField("", text: $clipStartSeconds, prompt: Text("Start at (seconds)").foregroundColor(GreetMeTheme.textMuted))
                        .keyboardType(.numberPad)
                        .foregroundColor(GreetMeTheme.textPrimary)

                    youtubePreviewRow
                }
            }
        }
    }

    @ViewBuilder
    private var youtubePreviewRow: some View {
        let videoId = Self.extractVideoId(from: youtubeLink.trimmingCharacters(in: .whitespaces))
        if youtubeResolvingTitle {
            HStack(spacing: 6) {
                ProgressView().tint(GreetMeTheme.gold)
                Text("Looking up video…")
                    .font(.caption)
                    .foregroundColor(GreetMeTheme.textSecondary)
            }
        } else if let title = youtubeResolvedTitle, videoId != nil {
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(GreetMeTheme.teal)
                        .font(.caption)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(title)
                            .font(.caption.weight(.semibold))
                            .foregroundColor(GreetMeTheme.textPrimary)
                            .lineLimit(2)
                        let startSec = Int(clipStartSeconds.trimmingCharacters(in: .whitespaces)) ?? 0
                        if startSec > 0 {
                            Text("Starts at \(formatSeconds(startSec))")
                                .font(.caption2)
                                .foregroundColor(GreetMeTheme.textMuted)
                        }
                    }
                    Spacer()
                    if let url = URL(string: youtubeLink.trimmingCharacters(in: .whitespaces)) {
                        Button {
                            onOpenURL(url)
                        } label: {
                            Label("Preview", systemImage: "play.rectangle.fill")
                                .font(.caption.weight(.semibold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(GreetMeTheme.danger)
                                .clipShape(Capsule())
                        }
                    }
                }
            }
        } else if let resolveError = youtubeResolveError {
            Text(resolveError)
                .font(.caption)
                .foregroundColor(GreetMeTheme.danger)
        }
    }

    // MARK: - Cash gift

    private var cashGiftSection: some View {
        cardSection {
            Toggle(isOn: $cashEnabled) {
                addonLabel(icon: "dollarsign.circle.fill", tint: GreetMeTheme.gold,
                           title: "Cash Gift",
                           subtitle: "Sent via Cash App · free to add")
            }
            .tint(GreetMeTheme.teal)

            if cashEnabled {
                divider
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 6) {
                        Text("$").foregroundColor(GreetMeTheme.gold).font(.headline)
                        TextField("", text: $cashtag, prompt: Text("yourcashtag").foregroundColor(GreetMeTheme.textMuted))
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .foregroundColor(GreetMeTheme.textPrimary)
                    }
                    .padding(10)
                    .background(GreetMeTheme.surfaceElevated)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
                        ForEach(cashPresets, id: \.self) { amount in
                            Button {
                                cashAmount = (cashAmount == amount) ? nil : amount
                            } label: {
                                Text("$\(amount)")
                                    .font(.subheadline.weight(.semibold))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                                    .foregroundColor(cashAmount == amount ? GreetMeTheme.background : GreetMeTheme.textPrimary)
                                    .background(cashAmount == amount ? GreetMeTheme.gold : GreetMeTheme.surfaceElevated)
                                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                            }
                        }
                    }
                    Text("GreetMe doesn't move money — your recipient requests the gift in Cash App.")
                        .font(.caption2)
                        .foregroundColor(GreetMeTheme.textMuted)
                }
            }
        }
    }

    // MARK: - Price summary

    private var priceSummary: some View {
        VStack(spacing: 8) {
            summaryRow(label: card.title, value: GreetMeTheme.priceLabel(card.price))
            if youtubeEnabled {
                summaryRow(label: "GreetMe Clip", value: "+\(GreetMeTheme.priceLabel(addonPrice))")
            }
            if voiceNoteUrl != nil {
                summaryRow(label: "Voice Note", value: "+\(GreetMeTheme.priceLabel(addonPrice))")
            }
            if cashEnabled, let amount = cashAmount {
                summaryRow(label: "Cash gift (via Cash App)", value: "$\(amount)", muted: true)
            }
            Divider().background(GreetMeTheme.border)
            HStack {
                Text("Estimated total")
                    .font(.subheadline.weight(.bold))
                    .foregroundColor(GreetMeTheme.textPrimary)
                Spacer()
                Text(GreetMeTheme.priceLabel(estimatedTotal))
                    .font(.subheadline.weight(.bold))
                    .foregroundColor(GreetMeTheme.gold)
            }
            Text("Your first card in 48 hours is free — final price is confirmed at checkout.")
                .font(.caption2)
                .foregroundColor(GreetMeTheme.textMuted)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(14)
        .background(GreetMeTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var previewSendButtons: some View {
        VStack(spacing: 12) {
            if isSubmitting {
                HStack {
                    Spacer()
                    ProgressView().tint(GreetMeTheme.gold)
                    Spacer()
                }
                .padding(.vertical, 16)
            } else {
                HStack(spacing: 12) {
                    Button(action: previewCard) {
                        HStack {
                            Spacer()
                            Label("Preview", systemImage: "eye.fill")
                                .font(.headline)
                                .foregroundColor(GreetMeTheme.gold)
                            Spacer()
                        }
                        .padding(.vertical, 16)
                        .background(GreetMeTheme.surface)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(GreetMeTheme.gold.opacity(0.6), lineWidth: 1)
                        )
                    }
                    .disabled(!isValid)

                    Button(action: sendCard) {
                        HStack {
                            Spacer()
                            Label("Send", systemImage: "paperplane.fill")
                                .font(.headline)
                                .foregroundColor(GreetMeTheme.background)
                            Spacer()
                        }
                        .padding(.vertical, 16)
                        .background(isValid ? GreetMeTheme.gold : GreetMeTheme.gold.opacity(0.4))
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .disabled(!isValid)
                }
            }
        }
    }

    // MARK: - Reusable pieces

    private func cardSection<Content: View>(title: String? = nil, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            if let title {
                Text(title)
                    .font(.subheadline.weight(.bold))
                    .foregroundColor(GreetMeTheme.textPrimary)
            }
            content()
        }
        .padding(14)
        .background(GreetMeTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func field(_ label: String, text: Binding<String>, placeholder: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.caption.weight(.semibold))
                .foregroundColor(GreetMeTheme.textMuted)
            TextField("", text: text, prompt: Text(placeholder).foregroundColor(GreetMeTheme.textMuted))
                .foregroundColor(GreetMeTheme.textPrimary)
        }
    }

    private func addonLabel(icon: String, tint: Color, title: String, subtitle: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(tint)
                .frame(width: 36, height: 36)
                .background(GreetMeTheme.surfaceElevated)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(GreetMeTheme.textPrimary)
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(GreetMeTheme.textSecondary)
            }
        }
    }

    private var divider: some View {
        Divider().background(GreetMeTheme.border)
    }

    private func summaryRow(label: String, value: String, muted: Bool = false) -> some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundColor(muted ? GreetMeTheme.textMuted : GreetMeTheme.textSecondary)
                .lineLimit(1)
            Spacer()
            Text(value)
                .font(.subheadline)
                .foregroundColor(muted ? GreetMeTheme.textMuted : GreetMeTheme.textPrimary)
        }
    }

    // MARK: - Logic

    private var estimatedTotal: Double {
        var total = max(0, card.price)
        if youtubeEnabled { total += addonPrice }
        if voiceNoteUrl != nil { total += addonPrice }
        return total
    }

    private var isValid: Bool {
        !toName.trimmingCharacters(in: .whitespaces).isEmpty &&
        !fromName.trimmingCharacters(in: .whitespaces).isEmpty &&
        !recorder.isRecording &&
        !isUploadingVoice
    }

    private func handleVoiceToggle(_ on: Bool) {
        voiceToggleOn = on
        if !on {
            if recorder.isRecording { recorder.stop() }
            recorder.reset()
            voiceNoteUrl = nil
            voiceError = nil
        }
    }

    private func uploadVoice(_ url: URL) {
        isUploadingVoice = true
        voiceError = nil
        Task {
            do {
                let data = try Data(contentsOf: url)
                let serverUrl = try await api.uploadVoiceNote(
                    data: data,
                    mimeType: "audio/m4a",
                    fileName: url.lastPathComponent
                )
                await MainActor.run {
                    voiceNoteUrl = serverUrl
                    isUploadingVoice = false
                }
            } catch {
                await MainActor.run {
                    voiceError = error.localizedDescription
                    isUploadingVoice = false
                }
            }
        }
    }

    private func previewCard() {
        Task {
            guard let payload = await createCard() else { return }
            await MainActor.run {
                previewPayload = payload
                showPreview = true
            }
        }
    }

    private func sendCard() {
        Task {
            guard let payload = await createCard() else { return }
            await MainActor.run {
                deliverCard(payload)
            }
        }
    }

    private func deliverCard(_ payload: GreetMeCardPayload) {
        if payload.requiresPayment == true,
           let checkout = payload.checkoutUrl,
           let url = URL(string: checkout) {
            onOpenURL(url)
        }
        // Attach card to the conversation input; user confirms with the Messages send button.
        onSend(payload)
    }

    private func createCard() async -> GreetMeCardPayload? {
        await MainActor.run {
            errorMessage = nil
            isSubmitting = true
        }

        let request = buildCreateRequest()

        do {
            let payload = try await api.createCard(request)
            await MainActor.run { isSubmitting = false }
            return payload
        } catch {
            await MainActor.run {
                isSubmitting = false
                errorMessage = error.localizedDescription
            }
            return nil
        }
    }

    private func buildCreateRequest() -> CreateCardRequest {
        CreateCardRequest(
            cardId: card.id,
            customCardId: nil,
            from: fromName.trimmingCharacters(in: .whitespaces),
            to: toName.trimmingCharacters(in: .whitespaces),
            note: note.trimmingCharacters(in: .whitespaces).isEmpty ? nil : note,
            youtube: parseYouTube(),
            voiceNoteUrl: voiceNoteUrl,
            cashGift: parseCashGift(),
            signatureUrl: nil
        )
    }

    private func parseYouTube() -> CreateCardRequest.YouTubePayload? {
        guard youtubeEnabled else { return nil }
        let trimmed = youtubeLink.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, let videoId = Self.extractVideoId(from: trimmed) else { return nil }
        let start = Int(clipStartSeconds.trimmingCharacters(in: .whitespaces)) ?? 0
        return CreateCardRequest.YouTubePayload(
            enabled: true,
            videoId: videoId,
            url: trimmed,
            title: card.title,
            startSeconds: max(0, start)
        )
    }

    private func parseCashGift() -> CreateCardRequest.CashGiftPayload? {
        guard cashEnabled, let amount = cashAmount else { return nil }
        var tag = cashtag.trimmingCharacters(in: .whitespaces)
        tag = tag.replacingOccurrences(of: "$", with: "")
        guard !tag.isEmpty else { return nil }
        return CreateCardRequest.CashGiftPayload(cashtag: "$\(tag)", amount: Double(amount))
    }

    private func timeString(_ seconds: TimeInterval) -> String {
        String(format: "0:%02d", min(Int(seconds), Int(recorder.maxDuration)))
    }

    private func formatSeconds(_ totalSeconds: Int) -> String {
        let m = totalSeconds / 60
        let s = totalSeconds % 60
        return m > 0 ? "\(m)m \(s)s" : "\(s)s"
    }

    private func handleYouTubeLinkChange(_ newValue: String) {
        youtubeResolvedTitle = nil
        youtubeResolveError = nil
        let trimmed = newValue.trimmingCharacters(in: .whitespaces)
        guard let videoId = Self.extractVideoId(from: trimmed) else { return }
        _ = videoId
        youtubeResolvingTitle = true
        Task {
            await resolveYouTubeTitle(url: trimmed)
        }
    }

    private func resolveYouTubeTitle(url: String) async {
        guard let encoded = url.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let oembedURL = URL(string: "https://www.youtube.com/oembed?url=\(encoded)&format=json") else {
            await MainActor.run {
                youtubeResolvingTitle = false
                youtubeResolveError = "Invalid YouTube link."
            }
            return
        }
        do {
            let (data, _) = try await URLSession.shared.data(from: oembedURL)
            struct OEmbed: Decodable { let title: String }
            let decoded = try JSONDecoder().decode(OEmbed.self, from: data)
            await MainActor.run {
                youtubeResolvedTitle = decoded.title
                youtubeResolvingTitle = false
                youtubeResolveError = nil
            }
        } catch {
            await MainActor.run {
                youtubeResolvingTitle = false
                youtubeResolveError = "Couldn't find that video — double-check the link."
            }
        }
    }

    /// Extract an 11-character YouTube video id from common URL formats.
    static func extractVideoId(from url: String) -> String? {
        if let comps = URLComponents(string: url) {
            if let v = comps.queryItems?.first(where: { $0.name == "v" })?.value, v.count == 11 {
                return v
            }
            if comps.host?.contains("youtu.be") == true {
                let id = comps.path.replacingOccurrences(of: "/", with: "")
                if id.count == 11 { return id }
            }
        }
        return nil
    }
}
