import SwiftUI
import AVFoundation

// MARK: Owner's voice note player

/// Plays the owner's note. Demo: the note is read out by the phone's voice in the
/// captain's language. BACKEND: replace with the owner's recorded audio file.
@MainActor
@Observable
final class NotePlayer: NSObject, AVSpeechSynthesizerDelegate {
    static let shared = NotePlayer()

    var playing = false
    var progress: Double = 0
    var finishedOnce = false

    private let synth = AVSpeechSynthesizer()
    private var tick: Task<Void, Never>? = nil
    private var started = Date()
    static let seconds: Double = 12

    override init() {
        super.init()
        synth.delegate = self
    }

    static func text(_ lang: Lang) -> String {
        switch lang {
        case .en: return "Hello. My car is in slot 41, basement B2. Please clean the wheels well, and don't move the wipers. Thank you."
        case .hi: return "नमस्ते। मेरी गाड़ी B2 में, स्लॉट 41 पर है। पहिये अच्छे से साफ़ करना, और वाइपर मत हिलाना। धन्यवाद।"
        case .te: return "నమస్తే. నా కారు B2 లో, స్లాట్ 41 లో ఉంది. చక్రాలు బాగా శుభ్రం చేయండి, వైపర్లు కదపకండి. ధన్యవాదాలు."
        }
    }

    func play(_ lang: Lang) {
        stop()
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio)
        try? AVAudioSession.sharedInstance().setActive(true)
        let u = AVSpeechUtterance(string: Self.text(lang))
        u.voice = AVSpeechSynthesisVoice(language: lang == .en ? "en-IN" : (lang == .hi ? "hi-IN" : "te-IN"))
        u.rate = AVSpeechUtteranceDefaultSpeechRate * 0.9
        playing = true
        progress = 0
        started = Date()
        synth.speak(u)
        tick = Task { @MainActor in
            while !Task.isCancelled && playing {
                progress = min(0.97, Date().timeIntervalSince(started) / Self.seconds)
                try? await Task.sleep(nanoseconds: 100_000_000)
            }
        }
    }

    func stop() {
        tick?.cancel()
        if synth.isSpeaking { synth.stopSpeaking(at: .immediate) }
        playing = false
    }

    nonisolated func speechSynthesizer(_ s: AVSpeechSynthesizer, didFinish u: AVSpeechUtterance) {
        Task { @MainActor in
            self.tick?.cancel()
            self.playing = false
            self.progress = 1
            self.finishedOnce = true
        }
    }
}

// MARK: W26n Owner's note (must listen once, right after "I'm at the vehicle")

struct OwnerNoteScreen: View {
    @Environment(CaptainStore.self) var store
    @Environment(WRouter.self) var router
    @State private var player = NotePlayer.shared
    @State private var wave = false

    var body: some View {
        WScreen(gutter: WSpace.gutterCaptain, scrolls: false) {
            WHeader(title: store.t("Owner’s note", "मालिक का संदेश", "యజమాని నోట్"))
        } content: {
            VStack(spacing: 18) {
                Spacer()
                Text(store.t("Listen before you start", "शुरू करने से पहले सुनें", "మొదలుపెట్టే ముందు వినండి"))
                    .wText(.section, weight: .semibold, size: 22)
                Text("\(store.current.owner) · \(store.current.society)").wText(.body)
                // Big play / pause with a moving sound wave.
                Button {
                    if player.playing { player.stop() } else { player.play(store.lang) }
                } label: {
                    ZStack {
                        Circle().fill(WColor.primaryTint).frame(width: 190, height: 190)
                            .scaleEffect(player.playing && wave ? 1.08 : 1)
                        Circle().fill(WColor.primary).frame(width: 124, height: 124)
                        Image(systemName: player.playing ? "pause.fill" : (player.finishedOnce ? "arrow.counterclockwise" : "play.fill"))
                            .font(.system(size: 44, weight: .semibold)).foregroundStyle(.white)
                    }
                }
                .buttonStyle(WPressStyle())
                .accessibilityLabel(player.playing ? "Pause" : "Play owner's note")
                HStack(spacing: 4) {
                    ForEach(0..<24, id: \.self) { i in
                        let h: CGFloat = [10, 18, 28, 14, 22, 34, 16, 26, 12, 30, 20, 24][i % 12]
                        Capsule()
                            .fill(Double(i) / 24 < player.progress ? WColor.primary : WColor.border)
                            .frame(width: 5, height: player.playing && wave ? h : h * 0.6)
                    }
                }
                .frame(height: 36)
                Text(player.finishedOnce
                     ? store.t("Done. You can play it again anytime from the side button.", "हो गया। साइड बटन से कभी भी फिर सुन सकते हैं।", "అయింది. పక్క బటన్ నుండి ఎప్పుడైనా మళ్ళీ వినవచ్చు.")
                     : store.t("Listen till the end to continue.", "आगे बढ़ने के लिए पूरा सुनें।", "కొనసాగడానికి పూర్తిగా వినండి."))
                    .wText(.caption).multilineTextAlignment(.center)
                Spacer()
            }
            .frame(maxWidth: .infinity)
        } footer: {
            WFooter {
                WButton(store.t("Continue", "आगे बढ़ें", "కొనసాగించండి"), size: .captain, enabled: player.finishedOnce) {
                    player.stop()
                    store.ownerNoteHeard = true
                    router.push(.faceCheck)
                }
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true)) { wave = true }
            // Auto-play only the first time, and only while this screen is really on top.
            // (SwiftUI can call onAppear again while popping back past this screen.)
            guard !store.ownerNoteHeard else { return }
            player.finishedOnce = false
            player.progress = 0
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                guard router.path.last == .ownerNote, !store.ownerNoteHeard, !player.playing else { return }
                player.play(store.lang)
            }
        }
        .onDisappear { if player.playing { player.stop() } }
    }
}

// MARK: Replay button: sits beside the screen title after the note was heard

/// Quiet, tertiary-style capsule. Never auto-plays; tap to hear the note again.
struct OwnerNoteButton: View {
    @Environment(CaptainStore.self) var store
    @State private var player = NotePlayer.shared

    var body: some View {
        if store.ownerNoteHeard {
            Button {
                if player.playing { player.stop() } else { player.play(store.lang) }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: player.playing ? "stop.fill" : "speaker.wave.2.fill").font(.system(size: 12, weight: .semibold))
                    Text(player.playing ? store.t("Playing", "चल रहा", "ప్లే అవుతోంది") : store.t("Owner’s note", "मालिक का संदेश", "యజమాని నోట్"))
                        .font(WFont.of(.small, weight: .medium, size: 12.5))
                        .lineLimit(1).fixedSize()
                }
                .foregroundStyle(WColor.secondary)
                .padding(.horizontal, 12).frame(height: 32)
                .background(WColor.canvas, in: Capsule())
                .overlay(Capsule().strokeBorder(WColor.border))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Play owner's note again")
        }
    }
}
