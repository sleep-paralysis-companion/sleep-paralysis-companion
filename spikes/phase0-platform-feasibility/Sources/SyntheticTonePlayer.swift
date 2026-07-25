import AVFAudio
import Combine
import Foundation

@MainActor
final class SyntheticTonePlayer: ObservableObject {
    @Published private(set) var isPlaying = false
    @Published private(set) var status = "Stopped"

    private let engine = AVAudioEngine()
    private let node = AVAudioPlayerNode()
    private var buffer: AVAudioPCMBuffer?

    func start() async {
        guard !isPlaying else { return }

        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(
                .playback,
                mode: .default,
                options: [.allowAirPlay, .allowBluetoothA2DP]
            )
            try session.setActive(true)

            let format = AVAudioFormat(
                standardFormatWithSampleRate: 44_100,
                channels: 1
            )!
            let frameCount = AVAudioFrameCount(format.sampleRate)
            let tone = AVAudioPCMBuffer(
                pcmFormat: format,
                frameCapacity: frameCount
            )!
            tone.frameLength = frameCount

            let samples = tone.floatChannelData![0]
            for frame in 0 ..< Int(frameCount) {
                let phase = 2 * Double.pi * 220 * Double(frame) / format.sampleRate
                samples[frame] = Float(sin(phase) * 0.035)
            }

            if node.engine == nil {
                engine.attach(node)
                engine.connect(node, to: engine.mainMixerNode, format: format)
            }

            buffer = tone
            node.scheduleBuffer(tone, at: nil, options: .loops)
            try engine.start()
            node.play()
            isPlaying = true
            status = "Low-volume synthetic tone playing"
            await EvidenceLogger.shared.record("synthetic_tone_started")
        } catch {
            status = "Audio failed: \(error.localizedDescription)"
            await EvidenceLogger.shared.record(
                "synthetic_tone_failed",
                details: ["error": String(describing: error)]
            )
        }
    }

    func stop() async {
        node.stop()
        engine.stop()
        try? AVAudioSession.sharedInstance().setActive(
            false,
            options: .notifyOthersOnDeactivation
        )
        isPlaying = false
        status = "Stopped"
        await EvidenceLogger.shared.record("synthetic_tone_stopped")
    }
}
