import SwiftUI

struct QuizView: View {
    @Environment(AppModel.self) private var m

    var body: some View {
        if let S = m.sess, let board = m.quizBoard {
            VStack(spacing: 0) {
                header(S)
                question(S)
                if let st = board.staff {
                    StaffView(info: st)
                        .padding(.horizontal, 20)
                        .padding(.top, 2)
                        .padding(.bottom, 8)
                }
                FretboardView(board: board) { s, f in m.tapCell(s, f) }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.top, 4)
                    .padding(.bottom, 8)
                footer(S)
                    .frame(height: 136)
                    .padding(.horizontal, 16)
                Color.clear.frame(height: 12)
            }
        }
    }

    // MARK: Header

    private func header(_ S: Session) -> some View {
        HStack(spacing: 12) {
            Button { m.finish() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(FW.ink)
                    .frame(width: 40, height: 40)
                    .background(FW.card, in: Circle())
                    .shadow(color: FW.shadow.opacity(0.1), radius: 1, y: 1)
            }
            .buttonStyle(PressScale(scale: 0.92))
            .accessibilityLabel("End session")

            switch S.length {
            case .count:
                progressBar(Double(S.answered) / Double(max(1, S.count)), color: FW.accent)
                    .animation(.easeOut(duration: 0.3), value: S.answered)
            case .timed:
                TimelineView(.periodic(from: .now, by: 0.2)) { _ in
                    let left = S.endsAt - nowMs()
                    HStack(spacing: 10) {
                        progressBar(clamp(left / (Double(S.secs) * 1000), 0, 1), color: left < 10000 ? FW.bad : FW.accent)
                        Text(fmtTime(left))
                            .font(.mono(15, .medium))
                            .monospacedDigit()
                            .frame(minWidth: 38, alignment: .leading)
                    }
                }
            case .endless:
                HStack(spacing: 12) {
                    HStack(spacing: 5) {
                        Circle().fill(FW.good).frame(width: 8, height: 8)
                        Text("\(S.correct) right")
                    }
                    HStack(spacing: 5) {
                        Circle().fill(FW.bad).frame(width: 8, height: 8)
                        Text("\(S.answered - S.correct) missed").foregroundStyle(FW.muted)
                    }
                    Spacer(minLength: 0)
                }
                .font(.fig(14, .semibold))
                .contentTransition(.numericText())
                .animation(.easeOut, value: S.answered)
            }

            if S.combo >= 3 {
                Text("\(S.combo) in a row")
                    .font(.fig(14, .heavy))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(FW.ink, in: Capsule())
                    .fixedSize()
                    .popIn(0.35)
                    .id(S.combo)
            } else {
                let t = S.length == .count ? "\(min(S.answered + 1, S.count))/\(S.count)" : S.length == .timed ? "\(S.correct) right" : ""
                if !t.isEmpty {
                    Text(t).font(.mono(13)).foregroundStyle(FW.muted).fixedSize()
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 4)
        .frame(height: 48)
    }

    private func progressBar(_ frac: Double, color: Color) -> some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(FW.track)
                Capsule().fill(color).frame(width: geo.size.width * frac)
            }
        }
        .frame(height: 10)
    }

    // MARK: Question

    private func question(_ S: Session) -> some View {
        let q = S.q
        return VStack(spacing: 3) {
            Kicker(text: (q.again ? "Again · " : "") + q.kicker)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            if q.isStaff {
                Text(q.big).font(.fig(24, .heavy)).tracking(-0.48)
            } else {
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    noteText(q.big, 44, .heavy).tracking(-1.32)
                    if !q.alt.isEmpty {
                        noteText(q.alt, 18, .semibold).foregroundStyle(FW.muted)
                    }
                }
            }
            if !q.sub.isEmpty {
                Text(q.sub).font(.fig(16)).foregroundStyle(FW.muted)
            }
        }
        .multilineTextAlignment(.center)
        .padding(.horizontal, 20)
        .padding(.top, 10)
        .padding(.bottom, 8)
        .id(S.i)
        .transition(.opacity)
    }

    // MARK: Footer

    @ViewBuilder
    private func footer(_ S: Session) -> some View {
        let q = S.q, a = S.ans
        ZStack(alignment: .top) {
            switch q.type {
            case .find, .build, .sfind:
                findFooter(S)
            case .name, .sname:
                noteButtons(S)
            case .cname:
                chordButtons(S)
            }

            if let a {
                feedback(a, timed: S.length == .timed)
                    .padding(.top, 6)
                    .padding(.bottom, 10)
                    .id(S.i)
            }
        }
    }

    private func findFooter(_ S: Session) -> some View {
        let q = S.q
        var hint: String
        var steps: (done: Int, total: Int)? = nil
        if q.type == .build, let v = q.v {
            let bar = v.barre != nil, fing = !bar || S.bstage == "fingers"
            steps = (done: (bar && fing ? 1 : 0) + S.placed.count, total: q.need.count + (bar ? 1 : 0))
            if !fing { hint = "Step 1: tap any string on the fret you’d barre with your index finger." }
            else if bar { hint = "Barre placed. Tap each remaining note, one at a time (\(S.placed.count) of \(q.need.count))." }
            else { hint = "Tap each fretted note, one at a time (\(S.placed.count) of \(q.need.count)). Open strings don’t need a tap." }
        } else if q.type == .sfind {
            hint = "Tap where you’d play this exact note. Any string that gives the same pitch counts."
        } else {
            hint = "Tap it on the highlighted \(q.strName) string."
        }
        return VStack(spacing: 10) {
            Text(hint)
                .font(.fig(15, .semibold))
                .lineSpacing(2)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 330)
                .fixedSize(horizontal: false, vertical: true)
            if let steps {
                HStack(spacing: 6) {
                    ForEach(0..<steps.total, id: \.self) { i in
                        Capsule().fill(i < steps.done ? FW.accent : FW.stepTodo).frame(width: 26, height: 6)
                    }
                }
                .animation(.easeOut(duration: 0.2), value: steps.done)
            }
            Button { m.answer(false, Answer(correct: false, skip: true)) } label: {
                Text("Show me")
                    .font(.fig(15, .semibold))
                    .foregroundStyle(FW.ink)
                    .padding(.horizontal, 22)
                    .frame(height: 44)
                    .background(FW.card, in: Capsule())
                    .overlay(Capsule().strokeBorder(FW.border, lineWidth: 1.5))
            }
            .buttonStyle(PressScale(scale: 0.96))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .opacity(S.ans == nil ? 1 : 0)
    }

    private func noteButtons(_ S: Session) -> some View {
        let q = S.q, a = S.ans
        return LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 6), spacing: 6) {
            ForEach(0..<12, id: \.self) { p in
                let good = a != nil && p == q.p
                let bad = a != nil && a?.correct == false && a?.choice == p
                Button { m.answer(p == q.p, Answer(correct: false, choice: p)) } label: {
                    VStack(spacing: 1) {
                        noteText(Music.NS[p], 18, .heavy)
                        if a == nil && Music.isAcc(p) {
                            noteText(Music.NF[p], 11).foregroundStyle(FW.muted)
                        }
                    }
                    .foregroundStyle(a == nil ? FW.ink : (good || bad) ? .white : FW.dimFg)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(a == nil ? FW.card : good ? FW.good : bad ? FW.bad : FW.dimBg,
                                in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .shadow(color: FW.shadow.opacity(a == nil ? 0.08 : 0), radius: 1, y: 1)
                }
                .buttonStyle(PressScale(scale: 0.94))
                .disabled(a != nil)
            }
        }
        .padding(.top, 6)
        .animation(.easeOut(duration: 0.15), value: a == nil)
    }

    private func chordButtons(_ S: Session) -> some View {
        let q = S.q, a = S.ans
        return LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 8) {
            ForEach(q.opts, id: \.name) { o in
                let good = a != nil && o.correct
                let bad = a != nil && a?.correct == false && a?.choiceName == o.name
                Button { m.answer(o.correct, Answer(correct: false, choiceName: o.name)) } label: {
                    noteText(o.name, 20, a == nil || good || bad ? .heavy : .bold)
                        .foregroundStyle(a == nil ? FW.ink : (good || bad) ? .white : FW.dimFg)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(a == nil ? FW.card : good ? FW.good : bad ? FW.bad : FW.dimBg,
                                    in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .shadow(color: FW.shadow.opacity(a == nil ? 0.08 : 0), radius: 1, y: 1)
                }
                .buttonStyle(PressScale(scale: 0.96))
                .disabled(a != nil)
            }
        }
        .padding(.top, 6)
    }

    @ViewBuilder
    private func feedback(_ a: Answer, timed: Bool) -> some View {
        if a.correct {
            Button { m.next() } label: {
                VStack(spacing: 4) {
                    Text(a.title).font(.fig(26, .heavy)).tracking(-0.52)
                    Text(a.detail).font(.mono(15, .medium))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(FW.good, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                .shadow(color: FW.good.opacity(0.3), radius: 14, y: 10)
            }
            .buttonStyle(PressScale())
            .riseIn()
        } else {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(a.title).font(.fig(17, .heavy)).foregroundStyle(FW.badText)
                    noteText(a.detail, 14, .semibold).foregroundStyle(FW.ink)
                        .fixedSize(horizontal: false, vertical: true)
                    if !a.tip.isEmpty {
                        noteText(a.tip, 12.5).foregroundStyle(FW.muted)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .lineSpacing(1)
                .frame(maxWidth: .infinity, alignment: .leading)
                .minimumScaleFactor(0.85)
                Button { m.next() } label: {
                    Text(timed ? "Next" : "Got it")
                        .font(.fig(16, .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 20)
                        .frame(height: 52)
                        .background(FW.accent, in: Capsule())
                        .fixedSize()
                }
                .buttonStyle(PressScale(scale: 0.95))
            }
            .padding(.leading, 18)
            .padding(.trailing, 14)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(FW.badSoftBg, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder(FW.bad, lineWidth: 1.5))
            .riseIn()
        }
    }
}
