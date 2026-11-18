import Foundation
import Observation

// MARK: - Quiz types

enum QType { case find, name, sname, sfind, build, cname }

struct Cell: Equatable { let s: Int; let f: Int }
struct Win: Equatable { let from: Int; let to: Int }
struct ChordOpt: Equatable { let name: String; let correct: Bool }

struct Question {
    var type: QType
    var s = 0, f = 0, p = 0
    var win = Win(from: 0, to: 4)
    var strName = ""
    var big = "", alt = "", kicker = "", sub = ""
    var answers: [Int] = []
    var midi = 0, flat = false, nm = ""
    var v: Voicing? = nil
    var opts: [ChordOpt] = []
    var again = false

    var isChord: Bool { type == .build || type == .cname }
    var isStaff: Bool { type == .sname || type == .sfind }
    var need: [(s: Int, f: Int)] { v?.need ?? [] }
}

struct Answer {
    var correct: Bool
    var tap: Cell? = nil
    var choice: Int? = nil
    var choiceName: String? = nil
    var skip = false
    var stage: String? = nil
    var ms: Double = 0
    var title = "", detail = "", tip = ""
}

struct Miss: Hashable { let name: String; let whereText: String }

struct Session {
    var kind: Kind
    var zone: Zone
    var noteType: String, staffType: String, chordType: String
    var string: Int
    var naturals: Bool
    var fams: [String: Bool]
    var length: LengthMode
    var count: Int, secs: Int
    var i = 0
    var ans: Answer? = nil
    var bstage = "barre"
    var placed: [Cell] = []
    var retry: [(due: Int, q: Question)] = []
    var qStart = nowMs()
    var combo = 0, best = 0, correct = 0, answered = 0
    var times: [Double] = []
    var misses: [Miss] = []
    var runStart = 0
    var bestToasted = false
    var endsAt: Double = 0
    var q = Question(type: .find)

    func fam(_ g: ChordGroup) -> Bool { fams[g.rawValue] ?? false }
}

struct Summary {
    let kicker: String, hero: String, heroSub: String
    let banners: [String]
    let best: Int
    let avg: String
    let streak: Int
    let misses: [Miss]
    let kind: Kind
}

struct Toast: Equatable { let text: String; let id = UUID() }

// MARK: - Board rendering model

enum Mark: Equatable { case none, target, good, bad, chord, root, openStr }

struct CellView: Equatable {
    var mark: Mark = .none
    var label = ""
    var hl = false
    var muted = false
}

struct RowInfo: Identifiable {
    var id: Int { f }
    let f: Int
    let marked: Bool
    let isOpen: Bool
    let topWire: Bool
    let inlay: Bool
    let dbl: Bool
    let barreE: Bool
    let barreA: Bool
    let cells: [CellView]
}

struct StaffInfo: Equatable {
    let midi: Int, flat: Bool
    let name: String?
}

struct Board {
    var rows: [RowInfo] = []
    var from = 0, to = 4
    var activeStr = -1
    var voicing: Voicing? = nil
    var staff: StaffInfo? = nil
}

// MARK: - Model

enum Screen { case tabs, quiz, summary }
enum Tab: String { case play, progress, learn }
enum LearnMode: String { case notes, staff, chords }

@Observable
final class AppModel {
    var screen: Screen = .tabs
    var tab: Tab = .play
    var data: AppData = Persistence.load()
    var sess: Session? = nil
    var sum: Summary? = nil
    var learnMode: LearnMode = .notes
    var learnNote = 7
    var learnRoot = 7
    var learnQual = ""
    var learnVoice = 0
    var learnTap: Cell? = nil
    var toast: Toast? = nil

    /// Spoken answers for "name the note" questions.
    let voice = VoiceListener()

    // Preferences (the design exposes these as tweakable props with these defaults).
    var spelling = "Mixed"      // Mixed | Sharps | Flats
    var retryMissed = true

    init() {
        voice.onNote = { [weak self] p in self?.answerByVoice(p) }
        voice.onNext = { [weak self] in
            guard let self, self.sess?.ans != nil else { return }
            self.next()
        }
        #if DEBUG
        // Screenshot hooks, e.g. `-uiSeed 1 -uiTab learn -uiLearn chords -uiStart staff -uiAnswer 1`
        let ud = UserDefaults.standard
        if ud.bool(forKey: "uiSeed") { data = DebugSeed.make() }
        if let t = ud.string(forKey: "uiTab").flatMap(Tab.init(rawValue:)) { tab = t }
        if let l = ud.string(forKey: "uiLearn").flatMap(LearnMode.init(rawValue:)) { learnMode = l }
        if let k = ud.string(forKey: "uiKind").flatMap(Kind.init(rawValue:)) { data.cfg.kind = k }
        if let len = ud.string(forKey: "uiLength").flatMap(LengthMode.init(rawValue:)) { data.cfg.length = len }
        if let k = ud.string(forKey: "uiStart").flatMap(Kind.init(rawValue:)) {
            start(k)
            if let qt = ud.string(forKey: "uiQType") {
                for _ in 0..<200 where "\(sess!.q.type)" != qt { sess!.q = genQ(sess!, prev: nil) }
            }
            let ans = ud.integer(forKey: "uiAnswer")
            if ans == 1 { answer(true, Answer(correct: true)); advTask?.cancel() }
            if ans == 2 { answer(false, Answer(correct: false, skip: true)) }
            if ud.bool(forKey: "uiFinish") { finish() }
        }
        #endif
    }

    @ObservationIgnored private var advTask: Task<Void, Never>?
    @ObservationIgnored private var toastTask: Task<Void, Never>?
    @ObservationIgnored private var clockTask: Task<Void, Never>?

    // MARK: Persistence

    private func save() { Persistence.save(data) }
    func setCfg(_ edit: (inout Config) -> Void) {
        edit(&data.cfg)
        save()
    }

    var streakNow: Int {
        (data.lastDay == dayStr(Date()) || data.lastDay == daysAgo(1)) ? data.streak : 0
    }

    private func useFlat(_ p: Int) -> Bool {
        guard Music.isAcc(p) else { return false }
        if spelling == "Flats" { return true }
        if spelling == "Sharps" { return false }
        return Bool.random()
    }

    func showToast(_ text: String) {
        toastTask?.cancel()
        toast = Toast(text: text)
        toastTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(1.8))
            guard !Task.isCancelled else { return }
            self?.toast = nil
        }
    }

    // MARK: Question generation

    private func cells(_ zone: Zone, string: Int, naturals: Bool, maxF: Int) -> [Cell] {
        var c: [Cell] = []
        for s in 0..<6 {
            if string >= 0 && string != s { continue }
            let hi = min(zone.to, maxF)
            guard zone.from <= hi else { continue }
            for f in zone.from...hi {
                if naturals && Music.isAcc(Music.pc(s, f)) { continue }
                c.append(Cell(s: s, f: f))
            }
        }
        return c
    }

    private func filt(_ S: Session) -> (string: Int, naturals: Bool) {
        S.kind == .weak ? (-1, false) : (S.string, S.naturals)
    }

    private func pickNoteQ(_ S: Session, prev: Question?, pw: Double) -> Question {
        let zone = S.kind == .weak ? Zone.weak : S.zone
        let typeStr = (S.kind == .weak || S.noteType == "both") ? (Bool.random() ? "find" : "name") : S.noteType
        let kz = S.kind == .weak ? "Weak spots" : "Frets \(zone.sub)"
        let fl = filt(S)
        var c = cells(zone, string: fl.string, naturals: fl.naturals, maxF: 17)
        let c2 = c.filter { !(prev != nil && !prev!.isChord && !prev!.isStaff && prev!.s == $0.s && prev!.f == $0.f) }
        if !c2.isEmpty { c = c2 }
        let tbl = data[table: typeStr]
        let k = wpick(c) { pow(weight(tbl["\($0.s):\($0.f)"]), pw) }
        let p = Music.pc(k.s, k.f)
        var win = Win(from: zone.from, to: zone.to)
        if zone.local {
            let from = clamp(k.f - Int.random(in: 0..<5), 0, 13)
            win = Win(from: from, to: from + 4)
        }
        var q = Question(type: typeStr == "find" ? .find : .name, s: k.s, f: k.f, p: p, win: win, strName: Music.SN[k.s])
        if q.type == .find {
            let flat = useFlat(p)
            q.big = flat ? Music.NF[p] : Music.NS[p]
            q.alt = Music.isAcc(p) ? "= " + (flat ? Music.NS[p] : Music.NF[p]) : ""
            q.kicker = "Find the note · " + kz
            q.sub = "on the \(Music.SN[k.s]) string"
            for f in win.from...win.to where Music.pc(k.s, f) == p { q.answers.append(f) }
        } else {
            q.big = "What note?"
            q.kicker = "Name the note · " + kz
            q.sub = "\(Music.SN[k.s]) string, fret \(k.f)"
        }
        return q
    }

    private func pickStaffQ(_ S: Session, prev: Question?, pw: Double) -> Question {
        let zone = S.kind == .weak ? Zone.weak : Zone.staffZone(S.zone)
        let typeStr = (S.kind == .weak || S.staffType == "both") ? (Double.random(in: 0..<1) < 0.6 ? "sname" : "sfind") : S.staffType
        let fl = filt(S)
        var c = cells(zone, string: fl.string, naturals: fl.naturals, maxF: 12)
        let c2 = c.filter { !(prev != nil && prev!.isStaff && prev!.midi == Music.OPEN[$0.s] + $0.f) }
        if !c2.isEmpty { c = c2 }
        let k = wpick(c) { pow(weight(self.data.staff[String(Music.OPEN[$0.s] + $0.f)]), pw) }
        let midi = Music.OPEN[k.s] + k.f, p = midi % 12, flat = useFlat(p)
        var win = Win(from: zone.from, to: zone.to)
        if zone.local || zone.to - zone.from > 5 {
            let from = clamp(k.f - Int.random(in: 0..<5), 0, 8)
            win = Win(from: from, to: from + 4)
        }
        var q = Question(type: typeStr == "sname" ? .sname : .sfind, s: k.s, f: k.f, p: p, win: win, strName: Music.SN[k.s])
        q.midi = midi; q.flat = flat; q.nm = flat ? Music.NF[p] : Music.NS[p]
        q.kicker = "Read the staff" + (S.kind == .weak ? " · Weak spots" : "")
        q.big = q.type == .sname ? "What note is this?" : "Play this note"
        return q
    }

    private func chordOpts(_ v: Voicing) -> [ChordOpt] {
        var names: [String] = [v.name]
        if v.fam == "open" {
            var c = Chords.voicings.filter { $0.fam == "open" && $0.name != v.name }
            while names.count < 4 && !c.isEmpty {
                let k = wpick(c) { 1 + ($0.root == v.root ? 2 : 0) + ($0.qual == v.qual ? 2 : 0) }
                if !names.contains(k.name) { names.append(k.name) }
                c.removeAll { $0.id == k.id }
            }
        } else {
            let quals = Chords.movQuals(v.fam)
            var alts: [(Int, String)] = [(1, v.qual), (-1, v.qual), (2, v.qual), (-2, v.qual), (5, v.qual), (7, v.qual)]
            alts += quals.filter { $0 != v.qual }.map { (0, $0) }
            for (dp, q) in alts.shuffled() {
                if names.count >= 4 { break }
                let n = Music.CR[(v.root + dp + 12) % 12] + q
                if !names.contains(n) { names.append(n) }
            }
        }
        return names.shuffled().map { ChordOpt(name: $0, correct: $0 == v.name) }
    }

    private func pickChordQ(_ S: Session, prev: Question?, pw: Double) -> Question {
        let grps = ChordGroup.allCases.filter { S.kind == .weak || S.fam($0) }
        let g = grps.randomElement() ?? .open
        let pool = Chords.voicings.filter { $0.grp == g && (prev?.v == nil || $0.id != prev!.v!.id) }
        let v = wpick(pool) { pow(weight(self.data.ch[$0.id]), pw) }
        let typeStr = (S.kind == .weak || S.chordType == "both") ? (Double.random(in: 0..<1) < 0.55 ? "build" : "cname") : S.chordType
        var q = Question(type: typeStr == "build" ? .build : .cname, strName: Music.SN[v.rs])
        q.v = v; q.nm = v.name
        if q.type == .build {
            var win = Win(from: 0, to: 4)
            if v.fam != "open" {
                let from = max(0, v.b - 1 - Int.random(in: 0..<3))
                win = Win(from: from, to: from + 5)
            }
            q.win = win; q.big = v.name; q.kicker = "Build the chord"; q.sub = v.subText
        } else {
            q.win = v.fam == "open" ? Win(from: 0, to: 4) : Win(from: max(0, v.b - 1), to: v.b + 3)
            q.opts = chordOpts(v)
            q.big = "Which chord?"; q.kicker = "Name the chord"
            q.sub = v.fam == "open" ? "Open position" : "\(v.famLabel) at fret \(v.b)"
        }
        return q
    }

    private func genQ(_ S: Session, prev: Question?) -> Question {
        let pw: Double = S.kind == .weak ? 2 : 1
        var kind = S.kind
        if kind == .weak {
            let r = Double.random(in: 0..<1)
            kind = r < 0.4 ? .notes : r < 0.65 ? .staff : .chords
        }
        switch kind {
        case .notes: return pickNoteQ(S, prev: prev, pw: pw)
        case .staff: return pickStaffQ(S, prev: prev, pw: pw)
        default: return pickChordQ(S, prev: prev, pw: pw)
        }
    }

    func dueCount() -> Int {
        let c = data.cfg
        var n = 0
        if c.kind == .chords {
            for v in Chords.voicings where c.fam(v.grp) && isDue(data.ch[v.id]) { n += 1 }
            return n
        }
        let z = Zone.byId(c.zone)
        if c.kind == .staff {
            var seen = Set<Int>()
            for x in cells(Zone.staffZone(z), string: c.string, naturals: c.naturals, maxF: 12) {
                let m = Music.OPEN[x.s] + x.f
                if seen.contains(m) { continue }
                seen.insert(m)
                if isDue(data.staff[String(m)]) { n += 1 }
            }
            return n
        }
        let tbs = c.noteType == "both" ? ["find", "name"] : [c.noteType]
        for x in cells(z, string: c.string, naturals: c.naturals, maxF: 17) {
            for tb in tbs where isDue(data[table: tb]["\(x.s):\(x.f)"]) { n += 1 }
        }
        return n
    }

    // MARK: Session flow

    func start(_ kindOverride: Kind? = nil) {
        advTask?.cancel()
        GuitarSynth.shared.warmUp()
        let c = data.cfg
        var S = Session(kind: kindOverride ?? c.kind, zone: Zone.byId(c.zone), noteType: c.noteType, staffType: c.staffType,
                        chordType: c.chordType, string: c.string, naturals: c.naturals, fams: c.fams, length: c.length,
                        count: c.count, secs: c.secs)
        S.runStart = data.bestRun
        S.endsAt = nowMs() + Double(S.secs) * 1000
        S.q = genQ(S, prev: nil)
        sum = nil
        toast = nil
        sess = S
        screen = .quiz
        startClock()
    }

    private func startClock() {
        clockTask?.cancel()
        guard sess?.length == .timed else { return }
        clockTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(200))
                guard let self, self.screen == .quiz, let S = self.sess else { return }
                if nowMs() >= S.endsAt { self.finish(); return }
            }
        }
    }

    private func scheduleNext(after seconds: Double) {
        advTask?.cancel()
        advTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(seconds))
            guard !Task.isCancelled else { return }
            self?.next()
        }
    }

    func next() {
        advTask?.cancel()
        guard var S = sess, S.ans != nil else { return }
        if S.length == .count && S.answered >= S.count { return finish() }
        if S.length == .timed && nowMs() >= S.endsAt { return finish() }
        let q: Question
        if let idx = S.retry.firstIndex(where: { $0.due <= S.i + 1 }) {
            var rq = S.retry[idx].q
            rq.again = true
            q = rq
            S.retry.remove(at: idx)
        } else {
            q = genQ(S, prev: S.q)
        }
        S.i += 1
        S.q = q
        S.ans = nil
        S.bstage = "barre"
        S.placed = []
        S.qStart = nowMs()
        sess = S
    }

    private func missLabel(_ q: Question) -> Miss {
        switch q.type {
        case .find, .name: return Miss(name: Music.NS[q.p], whereText: "\(Music.SN[q.s]) string, fret \(q.f)")
        case .sname, .sfind: return Miss(name: q.nm, whereText: "On the staff, \(Music.posDesc(Music.staffPos(q.midi, flat: q.flat)))")
        default: return Miss(name: q.v!.name, whereText: q.v!.whereText)
        }
    }

    /// Voice answers only apply to questions that ask for a note name.
    func answerByVoice(_ p: Int) {
        guard screen == .quiz, let S = sess, S.ans == nil, S.q.type == .name || S.q.type == .sname else { return }
        answer(p == S.q.p, Answer(correct: false, choice: p))
    }

    private static let goodWords = ["Nailed it", "Clean", "Locked in", "Sharp", "Yes", "Spot on"]

    func answer(_ correct: Bool, _ extra: Answer) {
        guard var S = sess, S.ans == nil else { return }
        let q = S.q
        let ms = nowMs() - S.qStart
        let combo = correct ? S.combo + 1 : 0

        let (tb, key): (String, String) = q.isChord ? ("ch", q.v!.id) : q.isStaff ? ("staff", String(q.midi)) : (q.type == .find ? "find" : "name", "\(q.s):\(q.f)")
        var st = data[table: tb][key] ?? Stat()
        st.t += 1
        if correct { st.c += 1 }
        st.ms += min(ms, 15000)
        st.box = correct ? min(5, st.box + 1) : 0
        st.last = nowMs()
        data[table: tb][key] = st
        data.bestRun = max(data.bestRun, combo)

        var a = extra
        a.correct = correct
        a.ms = ms
        if correct {
            a.title = Self.goodWords.randomElement()!
            a.detail = String(format: "%.1fs", ms / 1000) + (combo >= 2 ? " · \(combo) in a row" : "")
        } else {
            a.title = extra.skip ? "Here it is" : "Not quite"
            switch q.type {
            case .find:
                let fr = q.answers.map(String.init).joined(separator: " and ")
                if extra.skip { a.detail = "\(q.big) is at fret \(fr)." }
                else if let t = extra.tap { a.detail = "That’s \(Music.NS[Music.pc(t.s, t.f)]). \(q.big) is at fret \(fr)." }
                a.tip = Music.noteTip(q.s, q.f)
            case .name:
                let ch = extra.choice ?? 0
                a.detail = "That’s \(Music.NS[q.p])\(Music.isAcc(q.p) ? " / " + Music.NF[q.p] : ""), not \(Music.NS[ch])."
                a.tip = Music.noteTip(q.s, q.f)
            case .sname:
                let pos = Music.staffPos(q.midi, flat: q.flat)
                a.detail = "That’s \(q.nm), on the \(Music.posDesc(pos))."
                a.tip = Music.staffTip(pos)
            case .sfind:
                let w = "\(q.nm) here is the \(Music.SN[q.s]) string, fret \(q.f)."
                if extra.skip { a.detail = w }
                else if let t = extra.tap {
                    let tp = (Music.OPEN[t.s] + t.f) % 12
                    a.detail = (tp == q.p ? "Right note, wrong octave. " : "That’s \(Music.NS[tp]). ") + w
                }
                a.tip = Music.staffTip(Music.staffPos(q.midi, flat: q.flat))
            case .build:
                let v = q.v!
                if extra.skip { a.detail = "Here’s \(v.name)." }
                else if extra.stage == "barre" { a.detail = "\(v.name) barres at fret \(v.barre ?? 0)." }
                else { a.detail = "That spot isn’t in \(v.name)." }
                a.tip = "× means skip that string, ○ means play it open."
            case .cname:
                let v = q.v!
                a.detail = "That’s \(v.name), \(v.whereText.lowercased())."
                a.tip = v.fam == "open" ? "" : "The root is on the \(Music.ORD[v.rs]) string: \(Music.CR[v.root]) at fret \(v.b)."
            }
        }

        if !correct { S.misses.append(missLabel(q)) }
        if !correct && !q.again && retryMissed { S.retry.append((due: S.i + 3, q: q)) }
        if correct {
            if combo % 10 == 0 {
                showToast("\(combo) in a row"); GuitarSynth.shared.chime()
            } else if !S.bestToasted && S.runStart >= 3 && combo > S.runStart {
                S.bestToasted = true
                showToast("New best run"); GuitarSynth.shared.chime()
            }
            Haptics.success()
        } else {
            Haptics.error()
        }
        S.ans = a
        S.combo = combo
        S.best = max(S.best, combo)
        if correct { S.correct += 1 }
        S.answered += 1
        S.times.append(ms)
        sess = S
        save()

        let timed = S.length == .timed
        let delay: Double? = correct ? (timed ? 0.65 : (q.isChord ? 1.3 : 0.9)) : (timed ? 2.0 : nil)
        if let delay { scheduleNext(after: delay) }
    }

    func finish() {
        voice.stop()
        advTask?.cancel()
        clockTask?.cancel()
        guard let S = sess else { return }
        if S.answered == 0 {
            screen = .tabs
            sess = nil
            return
        }
        let today = dayStr(Date())
        var streakUp = false
        if data.lastDay != today {
            data.streak = data.lastDay == daysAgo(1) ? data.streak + 1 : 1
            data.lastDay = today
            streakUp = true
        }
        var days = data.days.filter { $0 != today }
        days.append(today)
        data.days = Array(days.suffix(40))

        let total = S.answered
        var seen = Set<Miss>(), misses: [Miss] = []
        for m in S.misses where !seen.contains(m) {
            seen.insert(m); misses.append(m)
            if misses.count >= 5 { break }
        }
        let acc = Int((Double(S.correct) / Double(max(1, total)) * 100).rounded())
        let secLabel = S.secs >= 120 ? "\(S.secs / 60) min" : "\(S.secs)s"
        let kindLabel = ["notes": "Notes", "staff": "Staff", "chords": "Chords", "weak": "Weak spots"][S.kind.rawValue]!
        var hero: String, heroSub: String, kicker: String
        var banners: [String] = []
        if S.length == .timed {
            let bk = "\(S.kind.rawValue)|\(S.secs)"
            let prev = data.best[bk]
            if S.correct > (prev ?? 0) {
                data.best[bk] = S.correct
                if let prev { banners.append("New personal best (was \(prev))") }
            } else if let prev {
                banners.append("Your best: \(prev)")
            }
            hero = String(S.correct)
            heroSub = "correct in \(secLabel) · \(acc)% accuracy"
            kicker = "\(kindLabel) · \(secLabel) sprint"
        } else {
            hero = "\(acc)%"
            heroSub = "\(S.correct) of \(total) correct"
            kicker = "\(kindLabel) · " + (S.length == .count ? "\(total) questions" : "endless")
        }
        if S.best > S.runStart && S.runStart >= 3 { banners.append("New best run: \(S.best) in a row") }
        if streakUp { banners.append(data.streak > 1 ? "Day streak: \(data.streak) days" : "Day streak started") }
        let avg = S.times.reduce(0, +) / Double(max(1, total)) / 1000
        sum = Summary(kicker: kicker, hero: hero, heroSub: heroSub, banners: banners, best: S.best,
                      avg: String(format: "%.1f", avg), streak: data.streak, misses: misses, kind: S.kind)
        screen = .summary
        sess = nil
        toast = nil
        save()
        if streakUp || banners.contains(where: { $0.hasPrefix("New") }) { GuitarSynth.shared.chime() }
    }

    func done() {
        screen = .tabs
        tab = .play
        sum = nil
    }

    func tapCell(_ s: Int, _ f: Int) {
        if screen == .quiz {
            guard var S = sess, S.ans == nil else { return }
            let q = S.q
            switch q.type {
            case .find:
                guard s == q.s else { return }
                answer(q.answers.contains(f), Answer(correct: false, tap: Cell(s: s, f: f)))
            case .sfind:
                answer(Music.OPEN[s] + f == q.midi, Answer(correct: false, tap: Cell(s: s, f: f)))
            case .build:
                let v = q.v!
                if let barre = v.barre, S.bstage != "fingers" {
                    if f != barre { return answer(false, Answer(correct: false, tap: Cell(s: s, f: f), stage: "barre")) }
                    if q.need.isEmpty { return answer(true, Answer(correct: true)) }
                    S.bstage = "fingers"; S.placed = []
                    sess = S
                    Haptics.tap()
                    return
                }
                if let barre = v.barre, f == barre { return }
                if f == 0 && v.frets[s] == 0 { return }
                if !q.need.contains(where: { $0.s == s && $0.f == f }) {
                    return answer(false, Answer(correct: false, tap: Cell(s: s, f: f), stage: "fingers"))
                }
                if S.placed.contains(Cell(s: s, f: f)) { return }
                S.placed.append(Cell(s: s, f: f))
                sess = S
                if S.placed.count >= q.need.count { answer(true, Answer(correct: true)) } else { Haptics.tap() }
            default:
                break
            }
            return
        }
        if learnMode == .chords, learnVoicing.frets[s] == nil { return }
        learnTap = Cell(s: s, f: f)
        GuitarSynth.shared.pluck(Music.OPEN[s] + f)
    }

    // MARK: Board cells

    func vCell(_ v: Voicing, _ s: Int, _ f: Int, labels: Bool) -> CellView {
        guard let fr = v.frets[s] else { return CellView(muted: true) }
        if f != fr { return CellView() }
        let n = Music.pc(s, f), root = n == v.root
        if fr == 0 { return CellView(mark: .openStr, label: labels ? Music.CR[n] : "") }
        if let b = v.barre, fr == b, !root { return CellView() }
        return root ? CellView(mark: .root, label: labels ? Music.CR[n] : "R") : CellView(mark: .chord, label: labels ? Music.CR[n] : "")
    }

    private func quizCell(_ S: Session, _ s: Int, _ f: Int) -> CellView {
        let q = S.q, a = S.ans
        var c = CellView()
        switch q.type {
        case .find:
            if a == nil { c.hl = s == q.s }
            else if s == q.s && q.answers.contains(f) { c = CellView(mark: .good, label: q.big) }
            else if a?.tap == Cell(s: s, f: f) { c = CellView(mark: .bad, label: Music.NS[Music.pc(s, f)]) }
        case .name:
            if s == q.s && f == q.f { c = a != nil ? CellView(mark: .good, label: Music.NS[q.p]) : CellView(mark: .target, label: "?") }
        case .sname, .sfind:
            if a != nil {
                if Music.OPEN[s] + f == q.midi { c = CellView(mark: .good, label: q.nm) }
                else if a?.tap == Cell(s: s, f: f) { c = CellView(mark: .bad, label: Music.NS[Music.pc(s, f)]) }
            }
        case .cname:
            c = vCell(q.v!, s, f, labels: a != nil)
        case .build:
            let v = q.v!
            if a != nil { c = vCell(v, s, f, labels: true) }
            else {
                if let b = v.barre, S.bstage == "fingers", f == b, Music.pc(s, f) == v.root, v.frets[s] == b {
                    c = CellView(mark: .root, label: Music.CR[v.root])
                }
                if S.placed.contains(Cell(s: s, f: f)) { c = CellView(mark: .chord, label: Music.CR[Music.pc(s, f)]) }
            }
            if let a, !a.correct, a.tap == Cell(s: s, f: f) { c = CellView(mark: .bad, label: Music.NS[Music.pc(s, f)]) }
        }
        return c
    }

    private func rows(_ from: Int, _ to: Int, _ cf: (Int, Int) -> CellView, barre: ((Int) -> (Bool, Bool))? = nil) -> [RowInfo] {
        (from...to).map { f in
            let e = barre?(f) ?? (false, false)
            let marked = Music.INLAYS.contains(f) || f == 12 || f == 0
            return RowInfo(f: f, marked: marked, isOpen: f == 0, topWire: f == from && f > 0,
                           inlay: Music.INLAYS.contains(f), dbl: f == 12, barreE: e.0, barreA: e.1,
                           cells: (0..<6).map { cf($0, f) })
        }
    }

    private func barRow(_ v: Voicing, show: Bool) -> (Int) -> (Bool, Bool) {
        { f in
            guard show, let b = v.barre, f == b else { return (false, false) }
            return (v.barreFrom == 0, v.barreFrom == 1)
        }
    }

    var learnVoicing: Voicing {
        let vs = Chords.voices(root: learnRoot, qual: learnQual)
        return vs[min(learnVoice, vs.count - 1)]
    }

    var quizBoard: Board? {
        guard let S = sess else { return nil }
        let q = S.q, a = S.ans
        let showV = q.type == .cname || a != nil || (q.type == .build && S.bstage == "fingers")
        var b = Board()
        b.rows = rows(q.win.from, q.win.to, { self.quizCell(S, $0, $1) }, barre: q.isChord ? barRow(q.v!, show: showV) : nil)
        b.from = q.win.from; b.to = q.win.to
        b.activeStr = (!q.isChord && !q.isStaff) ? q.s : -1
        b.voicing = q.isChord && (q.type == .cname || a != nil) ? q.v : nil
        if q.isStaff { b.staff = StaffInfo(midi: q.midi, flat: q.flat, name: a != nil ? q.nm : nil) }
        return b
    }

    var learnBoard: Board {
        var b = Board()
        let tap = learnTap
        switch learnMode {
        case .notes:
            let ln = learnNote
            b.rows = rows(0, 12) { s, f in
                if Music.pc(s, f) == ln { return CellView(mark: .root, label: Music.NS[ln]) }
                if tap == Cell(s: s, f: f) { return CellView(mark: .chord, label: Music.NS[Music.pc(s, f)]) }
                return CellView()
            }
            b.from = 0; b.to = 12
        case .staff:
            let t = (tap != nil && tap!.f <= 12) ? tap! : Cell(s: 2, f: 2)
            let m = Music.OPEN[t.s] + t.f, p = m % 12
            b.rows = rows(0, 12) { s, f in
                if s == t.s && f == t.f { return CellView(mark: .root, label: Music.NS[p]) }
                if Music.OPEN[s] + f == m { return CellView(mark: .chord, label: Music.NS[p]) }
                return CellView()
            }
            b.from = 0; b.to = 12; b.activeStr = t.s
            b.staff = StaffInfo(midi: m, flat: false, name: Music.NS[p] + (Music.isAcc(p) ? " / " + Music.NF[p] : ""))
        case .chords:
            let vv = learnVoicing
            let win = vv.fam == "open" ? Win(from: 0, to: 4) : Win(from: vv.b - 1, to: vv.b + 3)
            b.rows = rows(win.from, win.to, { self.vCell(vv, $0, $1, labels: true) }, barre: barRow(vv, show: true))
            b.from = win.from; b.to = win.to
            b.activeStr = vv.fam == "open" ? -1 : vv.rs
            b.voicing = vv
        }
        return b
    }

    var learnInfo: String {
        switch learnMode {
        case .notes:
            let ln = learnNote
            var cnt = 0
            for s in 0..<6 { for f in 0...12 where Music.pc(s, f) == ln { cnt += 1 } }
            return "\(Music.NS[ln])\(Music.isAcc(ln) ? " / " + Music.NF[ln] : "") shows up \(cnt) times from the nut to fret 12. Tap any spot to hear it."
        case .staff:
            let t = (learnTap != nil && learnTap!.f <= 12) ? learnTap! : Cell(s: 2, f: 2)
            let m = Music.OPEN[t.s] + t.f
            var others: [String] = []
            for s in 0..<6 { for f in 0...12 where Music.OPEN[s] + f == m && !(s == t.s && f == t.f) { others.append("\(Music.SHORT[s]) string fret \(f)") } }
            return "Tap any fret to see it on the staff. Showing the \(Music.SN[t.s]) string, fret \(t.f)" + (others.isEmpty ? "." : ". Same pitch: \(others.joined(separator: ", ")).")
        case .chords:
            let vv = learnVoicing
            if vv.fam == "open" { return "\(vv.name), open position. × = skip that string, ○ = play it open." }
            if vv.barre != nil { return "\(vv.name): barre fret \(vv.b) with your index finger. Root on the \(Music.ORD[vv.rs]) string." }
            return "\(vv.name): root on the \(Music.ORD[vv.rs]) string at fret \(vv.b). Mute the rest."
        }
    }

    // MARK: Mastery

    func zoneMastery(from: Int, to: Int) -> Double {
        var sum = 0.0, n = 0
        for s in 0..<6 { for f in from...to { for tb in ["find", "name"] { sum += score(data[table: tb]["\(s):\(f)"]); n += 1 } } }
        return n > 0 ? sum / Double(n) : 0
    }

    func staffMastery() -> Double {
        var sum = 0.0
        for m in 40...76 { sum += score(data.staff[String(m)]) }
        return sum / 37
    }

    func grpMastery(_ g: ChordGroup) -> Double {
        let vs = Chords.voicings.filter { $0.grp == g }
        return vs.reduce(0) { $0 + score(data.ch[$1.id]) } / Double(vs.count)
    }
}
