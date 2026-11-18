import Foundation

let DAY: Double = 864e5
/// Leitner box review intervals in days.
let INTV: [Double] = [0, 1, 2, 4, 8, 16]

func nowMs() -> Double { Date().timeIntervalSince1970 * 1000 }

/// Per-item spaced-repetition record.
struct Stat: Codable {
    var c = 0          // correct
    var t = 0          // total attempts
    var ms: Double = 0 // summed answer time
    var box = 0
    var last: Double = 0

    var isDue: Bool { t > 0 && (nowMs() - last) >= INTV[box] * DAY }
}

func isDue(_ st: Stat?) -> Bool { st?.isDue ?? false }

func weight(_ st: Stat?) -> Double {
    guard let st, st.t > 0 else { return 1.5 }
    let t = Double(st.t)
    return (1 + 3 * (1 - Double(st.c) / t) + (st.ms / t > 5000 ? 0.6 : 0)) * (st.isDue ? 2.2 : 0.5)
}

func score(_ st: Stat?) -> Double {
    guard let st, st.t > 0 else { return 0 }
    return Double(st.c) / Double(st.t) * min(1, Double(st.t) / 3)
}

enum Kind: String, Codable { case notes, staff, chords, weak }
enum LengthMode: String, Codable { case endless, count, timed }

struct Config: Codable {
    var kind: Kind = .notes
    var noteType = "both"   // find | name | both
    var staffType = "both"  // sname | sfind | both
    var zone = "z0"
    var string = -1
    var naturals = false
    var fams: [String: Bool] = ["open": true, "barre": true, "power": false]
    var chordType = "both"  // build | cname | both
    var length: LengthMode = .endless
    var count = 20
    var secs = 60

    func fam(_ g: ChordGroup) -> Bool { fams[g.rawValue] ?? false }
}

struct AppData: Codable {
    var find: [String: Stat] = [:]
    var name: [String: Stat] = [:]
    var staff: [String: Stat] = [:]
    var ch: [String: Stat] = [:]
    var streak = 0
    var lastDay: String? = nil
    var days: [String] = []
    var bestRun = 0
    var best: [String: Int] = [:]
    var cfg = Config()

    subscript(table table: String) -> [String: Stat] {
        get {
            switch table {
            case "find": return find
            case "name": return name
            case "staff": return staff
            default: return ch
            }
        }
        set {
            switch table {
            case "find": find = newValue
            case "name": name = newValue
            case "staff": staff = newValue
            default: ch = newValue
            }
        }
    }
}

enum Persistence {
    private static let key = "fretty-v1"

    static func load() -> AppData {
        guard let raw = UserDefaults.standard.data(forKey: key),
              let d = try? JSONDecoder().decode(AppData.self, from: raw) else { return AppData() }
        return d
    }

    static func save(_ d: AppData) {
        if let raw = try? JSONEncoder().encode(d) { UserDefaults.standard.set(raw, forKey: key) }
    }
}

// MARK: - Days

private let dayFmt: DateFormatter = {
    let f = DateFormatter()
    f.calendar = Calendar(identifier: .gregorian)
    f.locale = Locale(identifier: "en_US_POSIX")
    f.dateFormat = "yyyy-MM-dd"
    return f
}()

func dayStr(_ d: Date) -> String { dayFmt.string(from: d) }
func daysAgo(_ n: Int) -> String { dayStr(Calendar.current.date(byAdding: .day, value: -n, to: Date())!) }
