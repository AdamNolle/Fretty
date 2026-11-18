import Foundation

// MARK: - Note names & tuning

enum Music {
    static let NS = ["C", "C♯", "D", "D♯", "E", "F", "F♯", "G", "G♯", "A", "A♯", "B"]
    static let NF = ["C", "D♭", "D", "E♭", "E", "F", "G♭", "G", "A♭", "A", "B♭", "B"]
    static let CR = ["C", "C♯", "D", "E♭", "E", "F", "F♯", "G", "A♭", "A", "B♭", "B"]
    /// MIDI pitch of each open string, low E (index 0) to high e (index 5).
    static let OPEN = [40, 45, 50, 55, 59, 64]
    static let SN = ["low E", "A", "D", "G", "B", "high e"]
    static let SHORT = ["E", "A", "D", "G", "B", "e"]
    static let ORD = ["6th", "5th", "4th", "3rd", "2nd", "1st"]
    static let INLAYS = [3, 5, 7, 9, 15, 17]
    static let MAPN = 18
    static let SBASE: Double = 112
    static let SSTEP: Double = 7

    static func pc(_ s: Int, _ f: Int) -> Int { (OPEN[s] + f) % 12 }
    static func isAcc(_ p: Int) -> Bool { [1, 3, 6, 8, 10].contains(p) }

    /// Diatonic staff position relative to E4 on the bottom line of the treble staff (0 = bottom line).
    /// Guitar is written an octave above sounding pitch, hence the +12.
    static func staffPos(_ midi: Int, flat: Bool) -> Int {
        let w = midi + 12, p = w % 12, oct = w / 12 - 1
        let L = flat ? [0, 1, 1, 2, 2, 3, 4, 4, 5, 5, 6, 6] : [0, 0, 1, 1, 2, 3, 3, 4, 4, 5, 5, 6]
        return oct * 7 + L[p] - 30
    }

    static func posDesc(_ pos: Int) -> String {
        if pos < 0 { return pos == -1 ? "just below the staff" : "below the staff, on ledger lines" }
        if pos > 8 { return pos == 9 ? "just above the staff" : "above the staff, on ledger lines" }
        if pos % 2 == 0 { return ["bottom", "2nd", "middle", "4th", "top"][pos / 2] + " line" }
        return ["1st", "2nd", "3rd", "4th"][(pos - 1) / 2] + " space"
    }

    static func staffTip(_ pos: Int) -> String {
        if pos < 0 { return "Below the staff, count down from E on the bottom line: D, C, B, A…" }
        if pos > 8 { return "Above the staff, count up from F on the top line: G, A, B, C…" }
        return pos % 2 == 0 ? "Lines, bottom to top: E G B D F." : "Spaces, bottom to top: F A C E."
    }

    static func noteTip(_ s: Int, _ f: Int) -> String {
        let p = pc(s, f)
        if f == 0 { return "That’s the open \(SN[s]) string." }
        if f == 12 { return "Fret 12 is the open string again, one octave up." }
        if f > 12 { return "Fret 12 restarts the string, so fret \(f) matches fret \(f - 12)." }
        if s < 5 && f == (s == 3 ? 4 : 5) { return "Same pitch as the open \(SN[s + 1]) string." }
        if s > 0 && f == (s == 4 ? 8 : 7) { return "One octave above the open \(SN[s - 1]) string." }
        if isAcc(p) { return "It sits between \(NS[p - 1]) (fret \(f - 1)) and \(NS[(p + 1) % 12]) (fret \(f + 1))." }
        var L: [String] = []
        for k in 0...f where !isAcc(pc(s, k)) { L.append("\(NS[pc(s, k)]) \(k)") }
        return "Naturals on this string by fret: \(L.joined(separator: " · "))."
    }
}

// MARK: - Zones

struct Zone: Equatable {
    let id: String, from: Int, to: Int, label: String, sub: String
    var local = false

    static let all: [Zone] = [
        Zone(id: "z0", from: 0, to: 4, label: "Open", sub: "0–4"),
        Zone(id: "z1", from: 3, to: 7, label: "Low", sub: "3–7"),
        Zone(id: "z2", from: 5, to: 9, label: "Middle", sub: "5–9"),
        Zone(id: "z3", from: 8, to: 12, label: "Upper", sub: "8–12"),
        Zone(id: "z4", from: 12, to: 17, label: "High", sub: "12–17"),
        Zone(id: "all", from: 0, to: 12, label: "All", sub: "0–12"),
    ]
    static let weak = Zone(id: "weak", from: 0, to: 17, label: "Weak spots", sub: "0–17", local: true)

    static func byId(_ id: String) -> Zone { all.first { $0.id == id } ?? all[0] }
    /// The staff only covers frets 0–12, so "High" maps to "All".
    static func staffZone(_ z: Zone) -> Zone { z.id == "z4" ? all[5] : z }
}

// MARK: - Chords

enum ChordGroup: String, CaseIterable, Codable {
    case open, barre, power
    var label: String { ["open": "Open chords", "barre": "Barre chords", "power": "Power chords"][rawValue]! }
    var desc: String {
        switch self {
        case .open: return "C, G, D, Am, E7, Cmaj7, sus and more"
        case .barre: return "E and A shapes in every key"
        case .power: return "Root–fifth on the 6th and 5th strings"
        }
    }
}

struct Voicing: Identifiable, Equatable {
    let id: String
    let name: String
    let fam: String          // open, E, A, P6, P5
    let grp: ChordGroup
    let root: Int
    let qual: String
    let frets: [Int?]
    let barre: Int?
    let barreFrom: Int
    let rs: Int              // root string
    let b: Int               // base fret

    static func == (a: Voicing, b: Voicing) -> Bool { a.id == b.id }

    var need: [(s: Int, f: Int)] {
        frets.enumerated().compactMap { s, f in
            guard let f, f > 0, !(barre != nil && f == barre) else { return nil }
            return (s, f)
        }
    }
    var famLabel: String { Chords.FAM_LABEL[fam]! }
    var whereText: String { fam == "open" ? "Open position" : "\(famLabel), fret \(b)" }
    var subText: String { fam == "open" ? "Open position" : "\(famLabel) · root on the \(Music.ORD[rs]) string" }
}

enum Chords {
    static let QUALS = ["", "m", "7", "m7", "maj7", "sus2", "sus4", "5"]
    static let QLAB = ["": "maj", "m": "m", "7": "7", "m7": "m7", "maj7": "maj7", "sus2": "sus2", "sus4": "sus4", "5": "5"]
    static let FAM_LABEL = ["open": "Open chord", "E": "E-shape barre", "A": "A-shape barre", "P6": "Power chord", "P5": "Power chord"]
    static let GRP: [String: ChordGroup] = ["open": .open, "E": .barre, "A": .barre, "P6": .power, "P5": .power]

    private static let X: Int? = nil
    static let OPEN_CH: [(String, [Int?])] = [
        ("C", [X, 3, 2, 0, 1, 0]), ("A", [X, 0, 2, 2, 2, 0]), ("G", [3, 2, 0, 0, 0, 3]), ("E", [0, 2, 2, 1, 0, 0]), ("D", [X, X, 0, 2, 3, 2]),
        ("Am", [X, 0, 2, 2, 1, 0]), ("Em", [0, 2, 2, 0, 0, 0]), ("Dm", [X, X, 0, 2, 3, 1]),
        ("A7", [X, 0, 2, 0, 2, 0]), ("B7", [X, 2, 1, 2, 0, 2]), ("C7", [X, 3, 2, 3, 1, 0]), ("D7", [X, X, 0, 2, 1, 2]), ("E7", [0, 2, 0, 1, 0, 0]), ("G7", [3, 2, 0, 0, 0, 1]),
        ("Am7", [X, 0, 2, 0, 1, 0]), ("Dm7", [X, X, 0, 2, 1, 1]), ("Em7", [0, 2, 0, 0, 0, 0]),
        ("Cmaj7", [X, 3, 2, 0, 0, 0]), ("Fmaj7", [X, X, 3, 2, 1, 0]), ("Amaj7", [X, 0, 2, 1, 2, 0]), ("Dmaj7", [X, X, 0, 2, 2, 2]),
        ("Asus2", [X, 0, 2, 2, 0, 0]), ("Dsus2", [X, X, 0, 2, 3, 0]), ("Asus4", [X, 0, 2, 2, 3, 0]), ("Dsus4", [X, X, 0, 2, 3, 3]), ("Esus4", [0, 2, 2, 2, 0, 0]),
    ]

    struct Movable { let rs: Int; let from: Int; let bar: Bool; let q: [(String, [Int?])] }
    static let MOV: [(String, Movable)] = [
        ("E", Movable(rs: 0, from: 0, bar: true, q: [("", [0, 2, 2, 1, 0, 0]), ("m", [0, 2, 2, 0, 0, 0]), ("7", [0, 2, 0, 1, 0, 0]), ("m7", [0, 2, 0, 0, 0, 0]), ("sus4", [0, 2, 2, 2, 0, 0])])),
        ("A", Movable(rs: 1, from: 1, bar: true, q: [("", [X, 0, 2, 2, 2, 0]), ("m", [X, 0, 2, 2, 1, 0]), ("7", [X, 0, 2, 0, 2, 0]), ("m7", [X, 0, 2, 0, 1, 0]), ("maj7", [X, 0, 2, 1, 2, 0]), ("sus2", [X, 0, 2, 2, 0, 0]), ("sus4", [X, 0, 2, 2, 3, 0])])),
        ("P6", Movable(rs: 0, from: 0, bar: false, q: [("5", [0, 2, 2, X, X, X])])),
        ("P5", Movable(rs: 1, from: 0, bar: false, q: [("5", [X, 0, 2, 2, X, X])])),
    ]
    static func movQuals(_ fam: String) -> [String] { MOV.first { $0.0 == fam }?.1.q.map(\.0) ?? [] }

    static let voicings: [Voicing] = {
        var out: [Voicing] = []
        for (name, frets) in OPEN_CH {
            let letter = String(name.prefix(1)), qual = String(name.dropFirst())
            out.append(Voicing(id: "o:" + name, name: name, fam: "open", grp: .open, root: Music.CR.firstIndex(of: letter)!,
                               qual: qual, frets: frets, barre: nil, barreFrom: 0, rs: frets.firstIndex { $0 != nil }!, b: 0))
        }
        for (fam, m) in MOV {
            for (q, shape) in m.q {
                for b in 1...12 {
                    let root = Music.pc(m.rs, b)
                    out.append(Voicing(id: "\(fam):\(q):\(b)", name: Music.CR[root] + q, fam: fam, grp: GRP[fam]!, root: root, qual: q,
                                       frets: shape.map { $0.map { b + $0 } }, barre: m.bar ? b : nil, barreFrom: m.from, rs: m.rs, b: b))
                }
            }
        }
        return out
    }()
    static let byId: [String: Voicing] = Dictionary(uniqueKeysWithValues: voicings.map { ($0.id, $0) })

    static func voices(root: Int, qual: String) -> [Voicing] {
        let ord = ["open": 0, "E": 1, "A": 2, "P6": 3, "P5": 4]
        return voicings.filter { $0.root == root && $0.qual == qual }.sorted { ord[$0.fam]! < ord[$1.fam]! }
    }
}

// MARK: - Helpers

func clamp<T: Comparable>(_ x: T, _ a: T, _ b: T) -> T { max(a, min(b, x)) }

func wpick<T>(_ arr: [T], _ w: (T) -> Double) -> T {
    let ws = arr.map(w)
    var t = ws.reduce(0, +) * Double.random(in: 0..<1)
    for (i, x) in arr.enumerated() {
        t -= ws[i]
        if t <= 0 { return x }
    }
    return arr[arr.count - 1]
}

func fmtTime(_ ms: Double) -> String {
    let s = max(0, Int(ceil(ms / 1000)))
    return "\(s / 60):" + String(format: "%02d", s % 60)
}
