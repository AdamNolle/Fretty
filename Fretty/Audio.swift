import AVFoundation
import UIKit

/// Karplus–Strong plucked-string synth, matching the design's Web Audio implementation.
final class GuitarSynth {
    static let shared = GuitarSynth()

    private let engine = AVAudioEngine()
    private let eq = AVAudioUnitEQ(numberOfBands: 1)
    private var players: [AVAudioPlayerNode] = []
    private var nextPlayer = 0
    private var cache: [Int: AVAudioPCMBuffer] = [:]
    private let format: AVAudioFormat
    private var started = false
    var enabled = true

    private init() {
        format = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 1)!
        NotificationCenter.default.addObserver(forName: AVAudioSession.interruptionNotification, object: nil, queue: .main) { [weak self] _ in
            self?.started = false
        }
        NotificationCenter.default.addObserver(forName: .AVAudioEngineConfigurationChange, object: engine, queue: .main) { [weak self] _ in
            self?.started = false
        }
    }

    private var graphBuilt = false
    private func buildGraph() {
        guard !graphBuilt else { return }
        graphBuilt = true
        let band = eq.bands[0]
        band.filterType = .lowPass
        band.frequency = 3400
        band.bypass = false
        let sub = AVAudioMixerNode()
        engine.attach(sub)
        engine.attach(eq)
        engine.connect(sub, to: eq, format: format)
        engine.connect(eq, to: engine.mainMixerNode, format: format)
        for _ in 0..<14 {
            let p = AVAudioPlayerNode()
            engine.attach(p)
            engine.connect(p, to: sub, fromBus: 0, toBus: sub.nextAvailableInputBus, format: format)
            players.append(p)
        }
        engine.prepare()
    }

    private func ensureStarted() -> Bool {
        if started && engine.isRunning { return true }
        do {
            let session = AVAudioSession.sharedInstance()
            if recording {
                try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .mixWithOthers, .allowBluetoothA2DP])
            } else {
                try session.setCategory(.playback, options: [.mixWithOthers])
            }
            try session.setActive(true)
            buildGraph()
            if !engine.isRunning { try engine.start() }
            guard engine.isRunning else { return false }
            players.forEach { if $0.engine != nil { $0.play() } }
            started = true
        } catch {
            started = false
        }
        return started
    }

    private var recording = false

    /// Switches the shared audio session so the microphone and the synth can run together.
    func setRecording(_ on: Bool) {
        guard on != recording else { return }
        recording = on
        started = false
        if on {
            let session = AVAudioSession.sharedInstance()
            try? session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .mixWithOthers, .allowBluetoothA2DP])
            try? session.setActive(true)
        }
        _ = ensureStarted()
    }

    /// Call early so the first pluck has no start-up lag.
    func warmUp() { _ = ensureStarted() }

    private func buffer(for midi: Int) -> AVAudioPCMBuffer {
        if let b = cache[midi] { return b }
        let sr = format.sampleRate
        let freq = 440 * pow(2, Double(midi - 69) / 12)
        let n = max(2, Int((sr / freq).rounded()))
        let len = AVAudioFrameCount(sr * 1.5)
        let buf = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: len)!
        buf.frameLength = len
        let d = buf.floatChannelData![0]
        var ring = (0..<n).map { _ in Float.random(in: -1...1) }
        var idx = 0
        for i in 0..<Int(len) {
            let nx = (idx + 1) % n
            let v = (ring[idx] + ring[nx]) * 0.4975
            d[i] = ring[idx]
            ring[idx] = v
            idx = nx
        }
        cache[midi] = buf
        return buf
    }

    func pluck(_ midi: Int, delay: Double = 0, volume: Float = 0.3) {
        guard enabled, ensureStarted() else { return }
        let p = players[nextPlayer]
        nextPlayer = (nextPlayer + 1) % players.count
        p.volume = volume
        let host = mach_absolute_time() + AVAudioTime.hostTime(forSeconds: delay)
        p.scheduleBuffer(buffer(for: midi), at: delay > 0 ? AVAudioTime(hostTime: host) : nil, options: [.interrupts])
        if !p.isPlaying, engine.isRunning { p.play() }
    }

    func strum(_ v: Voicing) {
        var k = 0.0
        for (s, f) in v.frets.enumerated() {
            guard let f else { continue }
            pluck(Music.OPEN[s] + f, delay: 0.035 * k, volume: 0.2)
            k += 1
        }
    }

    func chime() {
        for (i, m) in [60, 64, 67, 72].enumerated() { pluck(m + 12, delay: Double(i) * 0.09, volume: 0.16) }
    }
}

enum Haptics {
    static func success() { UINotificationFeedbackGenerator().notificationOccurred(.success) }
    static func error() { UINotificationFeedbackGenerator().notificationOccurred(.error) }
    static func tap() { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
}
