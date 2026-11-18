import SwiftUI

struct HomeView: View {
    @Environment(AppModel.self) private var m

    var body: some View {
        GeometryReader { geo in
            ScrollView(showsIndicators: false) {
                VStack(spacing: 12) {
                    header
                    kindCards
                    optionsCard
                    Spacer(minLength: 0)
                    lengthCard
                    Text(dueText)
                        .font(.fig(13))
                        .foregroundStyle(FW.muted)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .frame(height: 16)
                    PrimaryButton(title: startLabel) { m.start() }
                }
                .padding(.horizontal, 18)
                .padding(.top, 4)
                .padding(.bottom, 100)
                .frame(minHeight: geo.size.height)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
    }

    // MARK: Header

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            Text("Fretty")
                .font(.fig(30, .heavy))
                .tracking(-0.75)
            Spacer(minLength: 0)
            VStack(alignment: .trailing, spacing: 4) {
                HStack(spacing: 4) {
                    ForEach(week, id: \.n) { w in
                        WeekDot(label: w.label, state: w.state)
                    }
                }
                Text(streakText)
                    .font(.fig(12, .bold))
                    .lineLimit(1)
            }
        }
        .frame(height: 44)
    }

    private struct DayInfo { let n: Int; let label: String; let state: WeekDot.State }

    private var week: [DayInfo] {
        let days = Set(m.data.days)
        let letters = Array("SMTWTFS")
        return [6, 5, 4, 3, 2, 1, 0].map { n in
            let dt = Calendar.current.date(byAdding: .day, value: -n, to: Date())!
            let on = days.contains(daysAgo(n))
            let wd = Calendar.current.component(.weekday, from: dt) - 1
            return DayInfo(n: n, label: String(letters[wd]), state: on ? .on : (n > 0 ? .past : .todo))
        }
    }

    private var streakText: String {
        let s = m.streakNow
        return s > 0 ? "\(s)-day streak · best run \(m.data.bestRun)" : "Start a streak today"
    }

    // MARK: Kind cards

    private var kindCards: some View {
        let c = m.data.cfg
        let enabled = ChordGroup.allCases.filter { c.fam($0) }
        let cards: [(Kind, String, Int)] = [
            (.notes, "Notes", Int((m.zoneMastery(from: 0, to: 12) * 100).rounded())),
            (.staff, "Staff", Int((m.staffMastery() * 100).rounded())),
            (.chords, "Chords", Int((enabled.reduce(0) { $0 + m.grpMastery($1) } / Double(max(1, enabled.count)) * 100).rounded())),
        ]
        return HStack(spacing: 8) {
            ForEach(cards.indices, id: \.self) { i in
                let (kind, title, pct) = cards[i]
                let on = kind == c.kind
                Button { withAnimation(.easeOut(duration: 0.18)) { m.setCfg { $0.kind = kind } } } label: {
                    VStack(alignment: .leading, spacing: 0) {
                        Text(title).font(.fig(19, .heavy)).tracking(-0.19)
                        Spacer(minLength: 0)
                        Text("\(pct)% learned")
                            .font(.mono(11))
                            .foregroundStyle(on ? .white : FW.muted)
                    }
                    .foregroundStyle(on ? .white : FW.ink)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .frame(height: 64)
                    .background(on ? FW.accent : FW.card, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .shadow(color: on ? FW.accent.opacity(0.25) : FW.shadow.opacity(0.06), radius: on ? 10 : 1, y: on ? 8 : 1)
                }
                .buttonStyle(PressScale(scale: 0.97))
            }
        }
    }

    // MARK: Options

    private var optionsCard: some View {
        let c = m.data.cfg
        return Card(strong: true) {
            VStack(spacing: 12) {
                typeSeg
                if c.kind == .chords {
                    famList
                } else {
                    zonePicker
                }
            }
        }
    }

    @ViewBuilder private var typeSeg: some View {
        let c = m.data.cfg
        switch c.kind {
        case .staff:
            SegControl(items: [("sname", "Name it"), ("sfind", "Play it"), ("both", "Both")], selected: c.staffType) { id in m.setCfg { $0.staffType = id } }
        case .chords:
            SegControl(items: [("build", "Build it"), ("cname", "Name it"), ("both", "Both")], selected: c.chordType) { id in m.setCfg { $0.chordType = id } }
        default:
            SegControl(items: [("find", "Find it"), ("name", "Name it"), ("both", "Both")], selected: c.noteType) { id in m.setCfg { $0.noteType = id } }
        }
    }

    private var zonePicker: some View {
        let c = m.data.cfg
        let isStaff = c.kind == .staff
        let zone = isStaff ? Zone.staffZone(Zone.byId(c.zone)) : Zone.byId(c.zone)
        let zones = Zone.all.filter { !(isStaff && $0.id == "z4") }
        return VStack(spacing: 12) {
            VStack(spacing: 3) {
                FretMap(from: zone.from, to: zone.to, height: 28, radius: 6, dot: 6, divider: 2, border: 2.5, nutWidth: 4, showDouble: true)
                HStack(spacing: 0) {
                    ForEach(0..<Music.MAPN, id: \.self) { f in
                        Text([0, 3, 5, 7, 9, 12, 15, 17].contains(f) ? String(f) : "")
                            .font(.mono(9))
                            .foregroundStyle(FW.muted)
                            .frame(maxWidth: .infinity)
                            .frame(height: 11)
                    }
                }
            }
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 3), spacing: 6) {
                ForEach(zones, id: \.id) { z in
                    let on = z.id == zone.id
                    Button { m.setCfg { $0.zone = z.id } } label: {
                        HStack(spacing: 4) {
                            Text(z.label).font(.fig(13, .bold)).lineLimit(1)
                            Spacer(minLength: 0)
                            Text(z.sub).font(.mono(10)).foregroundStyle(FW.muted).lineLimit(1)
                        }
                        .foregroundStyle(FW.ink)
                        .padding(.horizontal, 10)
                        .frame(height: 38)
                        .background(FW.bg, in: RoundedRectangle(cornerRadius: 11, style: .continuous))
                        .overlay {
                            if on {
                                RoundedRectangle(cornerRadius: 11, style: .continuous)
                                    .fill(FW.accent.opacity(0.07))
                                    .overlay(RoundedRectangle(cornerRadius: 11, style: .continuous).strokeBorder(FW.accent, lineWidth: 2))
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
                if isStaff {
                    Text("Staff covers frets 0–12")
                        .font(.fig(11))
                        .foregroundStyle(FW.muted)
                        .multilineTextAlignment(.center)
                        .frame(height: 38)
                }
            }
            HStack(spacing: 8) {
                rowLabel("String")
                HStack(spacing: 4) {
                    ForEach(-1..<6, id: \.self) { id in
                        let label = id < 0 ? "All" : Music.SHORT[id]
                        let on = c.string == id
                        Button { m.setCfg { $0.string = id } } label: {
                            Text(label)
                                .font(.fig(14, on ? .heavy : .semibold))
                                .foregroundStyle(on ? .white : FW.ink)
                                .frame(maxWidth: .infinity)
                                .frame(height: 34)
                                .background(on ? FW.ink : FW.bg, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                        }
                        .buttonStyle(.plain)
                        .layoutPriority(id == -1 ? 1.4 : 1)
                        .frame(minWidth: id == -1 ? 40 : 0)
                    }
                }
            }
            HStack(spacing: 8) {
                rowLabel("Notes")
                SegControl(items: [(true, "Naturals only"), (false, "All 12")], selected: c.naturals, height: 28, fontSize: 13) { id in
                    m.setCfg { $0.naturals = id }
                }
            }
        }
    }

    private func rowLabel(_ t: String) -> some View {
        Text(t.uppercased())
            .font(.fig(11, .bold))
            .tracking(0.66)
            .foregroundStyle(FW.muted)
            .frame(width: 44, alignment: .leading)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
    }

    private var famList: some View {
        let c = m.data.cfg
        return VStack(spacing: 6) {
            ForEach(ChordGroup.allCases, id: \.self) { g in
                let on = c.fam(g)
                Button {
                    var f = c.fams
                    f[g.rawValue] = !on
                    guard f.values.contains(true) else { return }
                    m.setCfg { $0.fams = f }
                } label: {
                    HStack(spacing: 12) {
                        ZStack {
                            if on {
                                RoundedRectangle(cornerRadius: 7, style: .continuous).fill(FW.accent)
                                Text("✓").font(.fig(14, .heavy)).foregroundStyle(.white)
                            } else {
                                RoundedRectangle(cornerRadius: 7, style: .continuous).strokeBorder(FW.checkOff, lineWidth: 2)
                            }
                        }
                        .frame(width: 24, height: 24)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(g.label).font(.fig(15, .bold))
                            Text(g.desc).font(.fig(12)).foregroundStyle(FW.muted).lineLimit(1)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        Text("\(Int((m.grpMastery(g) * 100).rounded()))%")
                            .font(.mono(11))
                            .foregroundStyle(FW.muted)
                    }
                    .foregroundStyle(FW.ink)
                    .padding(.horizontal, 12)
                    .frame(height: 50)
                    .background(FW.bg, in: RoundedRectangle(cornerRadius: 13, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: Length

    private var lengthCard: some View {
        let c = m.data.cfg
        return Card(padding: EdgeInsets(top: 12, leading: 14, bottom: 12, trailing: 14)) {
            VStack(spacing: 8) {
                SegControl(items: [(LengthMode.endless, "Endless"), (.count, "Questions"), (.timed, "Timed")], selected: c.length) { id in
                    m.setCfg { $0.length = id }
                }
                if c.length == .endless {
                    Text("No limit. Tap ✕ whenever you want to stop.")
                        .font(.fig(13))
                        .foregroundStyle(FW.muted)
                        .frame(maxWidth: .infinity)
                        .frame(height: 36)
                } else {
                    HStack(spacing: 6) {
                        let chips: [(Int, String)] = c.length == .count ? [(10, "10"), (20, "20"), (50, "50")] : [(30, "30s"), (60, "60s"), (120, "2 min")]
                        ForEach(chips.indices, id: \.self) { i in
                            let (n, label) = chips[i]
                            let on = c.length == .count ? c.count == n : c.secs == n
                            Button {
                                m.setCfg { if $0.length == .count { $0.count = n } else { $0.secs = n } }
                            } label: {
                                Text(label)
                                    .font(.fig(15, on ? .bold : .semibold))
                                    .foregroundStyle(on ? FW.accentDeep : FW.ink)
                                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                                    .background(on ? FW.accent.opacity(0.07) : FW.bg, in: RoundedRectangle(cornerRadius: 11, style: .continuous))
                                    .overlay(RoundedRectangle(cornerRadius: 11, style: .continuous).strokeBorder(on ? FW.accent : .clear, lineWidth: 2))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .frame(height: 36)
                }
            }
        }
    }

    private var dueText: String {
        let c = m.data.cfg
        let due = m.dueCount()
        let best = m.data.best["\(c.kind.rawValue)|\(c.secs)"]
        return (c.length == .timed && best != nil ? "Best: \(best!) · " : "")
            + (due > 0 ? "\(due) due for review, they come up first" : "Nothing due here. New spots get mixed in.")
    }

    private var startLabel: String {
        switch m.data.cfg.kind {
        case .staff: return "Start staff quiz"
        case .chords: return "Start chord quiz"
        default: return "Start notes quiz"
        }
    }
}

struct WeekDot: View {
    enum State { case on, past, todo }
    let label: String
    let state: State
    var body: some View {
        ZStack {
            switch state {
            case .on: Circle().fill(FW.accent)
            case .past: Circle().fill(FW.hairline)
            case .todo: Circle().strokeBorder(FW.accent, style: StrokeStyle(lineWidth: 2, dash: [3, 2]))
            }
            Text(label)
                .font(.fig(10, state == .past ? .bold : .heavy))
                .foregroundStyle(state == .on ? .white : state == .past ? FW.muted : FW.accentDeep)
        }
        .frame(width: 22, height: 22)
    }
}
