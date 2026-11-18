#if DEBUG
import Foundation

/// Port of the design's `seedData()` — demo progress used only for debug screenshots.
enum DebugSeed {
    static func make() -> AppData {
        var state: UInt32 = 11
        func r() -> Double {
            state = state &+ 0x6D2B79F5
            var t = (state ^ (state >> 15)) &* (1 | state)
            t = (t &+ ((t ^ (t >> 7)) &* (61 | t))) ^ t
            return Double(t ^ (t >> 14)) / 4294967296
        }
        let now = nowMs()
        func mk(_ t: Int, _ acc: Double, _ ms: Double) -> Stat {
            Stat(c: Int((Double(t) * acc).rounded()), t: t, ms: Double(t) * ms,
                 box: clamp(Int((acc * 4).rounded()) - 1, 0, 4), last: now - floor(r() * 7) * DAY - 36e5)
        }
        var d = AppData()
        for s in 0..<6 {
            for f in 0...17 {
                let p = Music.pc(s, f)
                for (tb, bias) in [("find", 0.0), ("name", -0.05)] {
                    var t = Int((r() * Double(f <= 5 ? 9 : f <= 12 ? 6 : 3)).rounded())
                    if f > 12 && r() < 0.45 { t = 0 }
                    if t == 0 { continue }
                    let acc = clamp(0.97 - Double(f) * 0.03 - (Music.isAcc(p) ? 0.13 : 0) - ((s == 3 || s == 4) ? 0.1 : 0) + bias + (r() - 0.5) * 0.22, 0.08, 1)
                    d[table: tb]["\(s):\(f)"] = mk(t, acc, (1500 + Double(f) * 170 + r() * 1500).rounded())
                }
            }
        }
        for m in 40...76 {
            let t = Int((r() * 5).rounded())
            if t == 0 { continue }
            let pos = Music.staffPos(m, flat: false)
            d.staff[String(m)] = mk(t, clamp(0.85 - (pos < 0 || pos > 8 ? 0.3 : 0) - (Music.isAcc(m % 12) ? 0.12 : 0) + (r() - 0.5) * 0.3, 0.05, 1), (2200 + r() * 2500).rounded())
        }
        for v in Chords.voicings {
            let t = Int((r() * (v.fam == "open" ? 6 : 3)).rounded())
            if t == 0 { continue }
            let base = ["open": 0.86, "E": 0.72, "A": 0.58, "P6": 0.88, "P5": 0.82][v.fam]!
            let acc = clamp(base - (["7", "m7", "maj7"].contains(v.qual) ? 0.15 : 0) - (v.qual.hasPrefix("sus") ? 0.1 : 0) + (r() - 0.5) * 0.3, 0.05, 1)
            d.ch[v.id] = mk(t, acc, (2600 + r() * 3000).rounded())
        }
        d.streak = 6
        d.lastDay = daysAgo(1)
        d.days = (1...6).map(daysAgo)
        d.bestRun = 14
        return d
    }
}
#endif
