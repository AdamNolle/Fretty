import AVFoundation
import Observation
import Speech

/// Listens for spoken note names ("C", "F sharp", "B flat") and spoken commands ("next").
@Observable
final class VoiceListener {
    enum State: Equatable { case off, starting, listening, denied(String) }

    private(set) var state: State = .off
    /// Latest transcript fragment, shown so the user can see what was heard.
    private(set) var heard = ""

    @ObservationIgnored var onNote: ((Int) -> Void)?
    @ObservationIgnored var onNext: (() -> Void)?

    @ObservationIgnored private let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    @ObservationIgnored private let engine = AVAudioEngine()
    @ObservationIgnored private var request: SFSpeechAudioBufferRecognitionRequest?
    @ObservationIgnored private var task: SFSpeechRecognitionTask?
    @ObservationIgnored private var pending: (note: Int, at: Date)?
    @ObservationIgnored private var commitTask: Task<Void, Never>?
    @ObservationIgnored private var generation = 0

    var isOn: Bool { state == .listening || state == .starting }

    func toggle() { isOn ? stop() : start() }

    func start() {
        guard !isOn else { return }
        state = .starting
        Task { @MainActor in
            let speechOK = await withCheckedContinuation { c in
                SFSpeechRecognizer.requestAuthorization { c.resume(returning: $0 == .authorized) }
            }
            guard speechOK else { state = .denied("Allow Speech Recognition for Fretty in Settings to answer by voice."); return }
            let micOK = await AVAudioApplication.requestRecordPermission()
            guard micOK else { state = .denied("Allow microphone access for Fretty in Settings to answer by voice."); return }
            guard let recognizer, recognizer.isAvailable else { state = .denied("Speech recognition isn’t available right now."); return }
            do {
                GuitarSynth.shared.setRecording(true)
                try begin()
                state = .listening
            } catch {
                GuitarSynth.shared.setRecording(false)
                state = .denied("Couldn’t start the microphone.")
            }
        }
    }

    func stop() {
        commitTask?.cancel()
        teardown()
        heard = ""
        state = .off
        GuitarSynth.shared.setRecording(false)
    }

    /// Clears the transcript so the next utterance is parsed on its own.
    func reset() {
        guard state == .listening else { return }
        teardown()
        heard = ""
        try? begin()
    }

    private func teardown() {
        generation += 1
        pending = nil
        task?.cancel()
        task = nil
        request?.endAudio()
        request = nil
        if engine.isRunning { engine.stop() }
        engine.inputNode.removeTap(onBus: 0)
    }

    private func begin() throws {
        guard let recognizer else { return }
        let req = SFSpeechAudioBufferRecognitionRequest()
        req.shouldReportPartialResults = true
        req.taskHint = .confirmation
        req.contextualStrings = ["C", "D", "E", "F", "G", "A", "B", "sharp", "flat", "C sharp", "D flat", "D sharp",
                                 "E flat", "F sharp", "G flat", "G sharp", "A flat", "A sharp", "B flat", "next"]
        if recognizer.supportsOnDeviceRecognition { req.requiresOnDeviceRecognition = true }
        request = req

        let input = engine.inputNode
        let fmt = input.outputFormat(forBus: 0)
        input.removeTap(onBus: 0)
        input.installTap(onBus: 0, bufferSize: 1024, format: fmt) { [weak req] buf, _ in req?.append(buf) }
        engine.prepare()
        try engine.start()

        let gen = generation
        task = recognizer.recognitionTask(with: req) { [weak self] result, error in
            DispatchQueue.main.async {
                guard let self, gen == self.generation else { return }
                if let result { self.handle(result.bestTranscription.formattedString) }
                if error != nil || (result?.isFinal ?? false) {
                    // Requests time out after about a minute; keep listening.
                    if self.state == .listening { self.reset() }
                }
            }
        }
    }

    private func handle(_ text: String) {
        heard = text
        let parsed = Self.parse(text)
        if parsed.next { onNext?(); reset(); return }
        guard let p = parsed.note else { return }
        if parsed.hasAccidental {
            commit(p)
        } else {
            // Wait briefly in case "sharp"/"flat" follows the letter.
            pending = (p, Date())
            commitTask?.cancel()
            let gen = generation
            commitTask = Task { @MainActor [weak self] in
                try? await Task.sleep(for: .milliseconds(550))
                guard let self, !Task.isCancelled, gen == self.generation, let pd = self.pending, pd.note == p else { return }
                self.commit(p)
            }
        }
    }

    private func commit(_ p: Int) {
        commitTask?.cancel()
        pending = nil
        onNote?(p)
        reset()
    }

    // MARK: Parsing

    private static let letters: [String: Int] = [
        "c": 0, "see": 0, "sea": 0, "si": 0, "cee": 0,
        "d": 2, "dee": 2, "de": 2,
        "e": 4, "ee": 4,
        "f": 5, "eff": 5, "ef": 5,
        "g": 7, "gee": 7, "ji": 7,
        "a": 9, "ay": 9, "eh": 9,
        "b": 11, "bee": 11, "be": 11,
    ]

    static func parse(_ raw: String) -> (note: Int?, hasAccidental: Bool, next: Bool) {
        let s = raw.lowercased()
            .replacingOccurrences(of: "♯", with: " sharp ")
            .replacingOccurrences(of: "#", with: " sharp ")
            .replacingOccurrences(of: "♭", with: " flat ")
        let tokens = s.split(whereSeparator: { !$0.isLetter }).map(String.init)
        if tokens.contains(where: { ["next", "continue", "skip"].contains($0) }) { return (nil, false, true) }
        // Use the last letter mentioned, plus an accidental that directly follows it.
        var result: (Int, Bool)? = nil
        for (i, t) in tokens.enumerated() {
            guard let base = letters[t] else { continue }
            var p = base, acc = false
            if i + 1 < tokens.count {
                if tokens[i + 1] == "sharp" { p = (p + 1) % 12; acc = true }
                if tokens[i + 1] == "flat" { p = (p + 11) % 12; acc = true }
            }
            result = (p, acc)
        }
        guard let result else { return (nil, false, false) }
        return (result.0, result.1, false)
    }
}
