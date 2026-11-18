import SwiftUI

struct ProgressScreen: View {
    @Environment(AppModel.self) private var m

    private struct Row: Identifiable {
        let id = UUID()
        let acc: Double, t: Int
        let badge: String, title: String, sub: String?, score: String
    }

    var body: some View {
        let d = m.data
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 22) {
                Text("Progress").font(.fig(34, .heavy)).tracking(-0.85)

                HStack(spacing: 8) {
                    StatTile(value: "\(m.streakNow)", label: "Day streak")
                    StatTile(value: "\(d.bestRun)", label: "Best run")
                    StatTile(value: "\(overallAcc)%", label: "Accuracy")
                }

                section("Toughest notes") { listCard(weakSpots, pill: false, empty: "Answer a few note questions to see your trickiest spots.") }
                section("Toughest on the staff") { listCard(toughStaff, pill: false, empty: "Read a few notes on the staff to see these.") }
                section("Toughest chords") {
                    listCard(toughChords, pill: true, empty: "Build or name a few chords to see these.")
                    PrimaryButton(title: "Practice my weak spots", size: 17, weight: .bold, glow: false) { m.start(.weak) }
                }
                section("Notes, weakest first") { barsCard(noteBars, labelWidth: 36, labelSize: 15, labelWeight: .bold) }
                section("Chords by type") { barsCard(chordBars, labelWidth: 110, labelSize: 14, labelWeight: .semibold) }
            }
            .padding(.horizontal, 20)
            .padding(.top, 10)
            .padding(.bottom, 120)
        }
    }

    private func section<C: View>(_ title: String, @ViewBuilder _ content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).font(.fig(19, .bold))
            content()
        }
    }

    // MARK: Data

    private var overallAcc: Int {
        var c = 0, t = 0
        for tb in ["find", "name", "staff", "ch"] { for (_, x) in m.data[table: tb] { c += x.c; t += x.t } }
        return Int((Double(c) / Double(max(1, t)) * 100).rounded())
    }

    private func byAcc(_ a: Row, _ b: Row) -> Bool { a.acc != b.acc ? a.acc < b.acc : a.t > b.t }

    private var weakSpots: [Row] {
        var out: [Row] = []
        for tb in ["find", "name"] {
            for (k, x) in m.data[table: tb] where x.t >= 2 {
                let parts = k.split(separator: ":").compactMap { Int($0) }
                guard parts.count == 2 else { continue }
                let (s, f) = (parts[0], parts[1])
                out.append(Row(acc: Double(x.c) / Double(x.t), t: x.t, badge: Music.NS[Music.pc(s, f)],
                               title: "\(Music.SN[s]) string, fret \(f)", sub: tb == "find" ? "Finding it" : "Naming it", score: "\(x.c)/\(x.t)"))
            }
        }
        return Array(out.sorted(by: byAcc).prefix(5))
    }

    private var toughStaff: [Row] {
        var out: [Row] = []
        for (k, x) in m.data.staff where x.t >= 2 {
            guard let midi = Int(k) else { continue }
            let desc = Music.posDesc(Music.staffPos(midi, flat: false))
            out.append(Row(acc: Double(x.c) / Double(x.t), t: x.t, badge: Music.NS[midi % 12],
                           title: desc.prefix(1).uppercased() + desc.dropFirst(), sub: nil, score: "\(x.c)/\(x.t)"))
        }
        return Array(out.sorted(by: byAcc).prefix(5))
    }

    private var toughChords: [Row] {
        var out: [Row] = []
        for (k, x) in m.data.ch where x.t >= 2 {
            guard let v = Chords.byId[k] else { continue }
            out.append(Row(acc: Double(x.c) / Double(x.t), t: x.t, badge: v.name, title: v.whereText, sub: nil, score: "\(x.c)/\(x.t)"))
        }
        return Array(out.sorted(by: byAcc).prefix(5))
    }

    private var noteBars: [(String, Double)] {
        var per = Array(repeating: (c: 0, t: 0), count: 12)
        for tb in ["find", "name"] {
            for (k, x) in m.data[table: tb] {
                let parts = k.split(separator: ":").compactMap { Int($0) }
                guard parts.count == 2 else { continue }
                let p = Music.pc(parts[0], parts[1])
                per[p].c += x.c; per[p].t += x.t
            }
        }
        return per.enumerated()
            .map { (Music.NS[$0.offset], $0.element.t > 0 ? Double($0.element.c) / Double($0.element.t) : 0) }
            .sorted { $0.1 < $1.1 }
    }

    private var chordBars: [(String, Double)] {
        [("open", "Open chords"), ("E", "E-shape barre"), ("A", "A-shape barre"), ("P", "Power chords")].map { f, label in
            var a = 0, b = 0
            for (k, x) in m.data.ch {
                guard let v = Chords.byId[k] else { continue }
                if f == "P" ? v.grp == .power : v.fam == f { a += x.c; b += x.t }
            }
            return (label, b > 0 ? Double(a) / Double(b) : 0)
        }
    }

    // MARK: Cards

    private func listCard(_ rows: [Row], pill: Bool, empty: String) -> some View {
        VStack(spacing: 0) {
            if rows.isEmpty {
                Text(empty)
                    .font(.fig(14))
                    .foregroundStyle(FW.muted)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 16)
            }
            ForEach(Array(rows.enumerated()), id: \.element.id) { i, r in
                HStack(spacing: 14) {
                    noteText(r.badge, pill ? 15 : 16, .heavy)
                        .foregroundStyle(FW.weakFg)
                        .padding(.horizontal, pill ? 8 : 0)
                        .frame(minWidth: pill ? 52 : 40, minHeight: 40)
                        .frame(width: pill ? nil : 40)
                        .background(FW.weakBg, in: Capsule())
                    VStack(alignment: .leading, spacing: 2) {
                        Text(r.title).font(.fig(15, .semibold))
                        if let sub = r.sub { Text(sub).font(.fig(13)).foregroundStyle(FW.muted) }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    Text(r.score).font(.mono(14, .medium))
                }
                .padding(.vertical, 13)
                .overlay(alignment: .top) { if i > 0 { FW.hairline.frame(height: 1) } }
            }
        }
        .padding(.horizontal, 16)
        .background(FW.card, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .cardShadow()
    }

    private func barsCard(_ bars: [(String, Double)], labelWidth: CGFloat, labelSize: CGFloat, labelWeight: Font.Weight) -> some View {
        VStack(spacing: 9) {
            ForEach(bars.indices, id: \.self) { i in
                let (name, acc) = bars[i]
                let pct = Int((acc * 100).rounded())
                HStack(spacing: 10) {
                    noteText(name, labelSize, labelWeight).frame(width: labelWidth, alignment: .leading).lineLimit(1)
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(FW.hairline)
                            Capsule().fill(FW.heat(acc)).frame(width: geo.size.width * CGFloat(pct) / 100)
                        }
                    }
                    .frame(height: 8)
                    Text("\(pct)%").font(.mono(12)).foregroundStyle(FW.muted).frame(width: 40, alignment: .trailing)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(FW.card, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .cardShadow()
    }
}

struct StatTile: View {
    let value: String
    let label: String
    var centered = false
    var body: some View {
        VStack(alignment: centered ? .center : .leading, spacing: 4) {
            Text(value).font(.fig(24, .heavy)).tracking(-0.48).contentTransition(.numericText())
            Text(label).font(.fig(13)).foregroundStyle(FW.muted).lineLimit(1).minimumScaleFactor(0.8)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: centered ? .center : .leading)
        .background(FW.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .cardShadow()
    }
}
