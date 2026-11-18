import SwiftUI

struct LearnView: View {
    @Environment(AppModel.self) private var m

    var body: some View {
        let board = m.learnBoard
        VStack(spacing: 0) {
            controls
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 2)
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
            Color.clear.frame(height: 90)
        }
    }

    private var controls: some View {
        VStack(spacing: 10) {
            HStack {
                Text("Learn").font(.fig(34, .heavy)).tracking(-0.85)
                Spacer()
                SegControl(items: [(LearnMode.notes, "Notes"), (.staff, "Staff"), (.chords, "Chords")],
                           selected: m.learnMode, height: 36, capsule: true, fill: false) { id in
                    m.learnMode = id
                    m.learnTap = nil
                }
            }

            if m.learnMode != .staff {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 6), spacing: 6) {
                    ForEach(0..<12, id: \.self) { p in
                        let on = m.learnMode == .chords ? p == m.learnRoot : p == m.learnNote
                        Button {
                            if m.learnMode == .chords { m.learnRoot = p; m.learnVoice = 0 } else { m.learnNote = p }
                            m.learnTap = nil
                        } label: {
                            noteText(m.learnMode == .chords ? Music.CR[p] : Music.NS[p], 15, on ? .heavy : .bold)
                                .foregroundStyle(on ? .white : FW.ink)
                                .frame(maxWidth: .infinity)
                                .frame(height: 38)
                                .background(on ? FW.accent : FW.card, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                                .shadow(color: FW.shadow.opacity(on ? 0 : 0.06), radius: 1, y: 1)
                        }
                        .buttonStyle(PressScale(scale: 0.94))
                    }
                }
            }

            if m.learnMode == .chords {
                HStack(spacing: 4) {
                    ForEach(Chords.QUALS, id: \.self) { q in
                        let on = q == m.learnQual
                        Button { m.learnQual = q; m.learnVoice = 0; m.learnTap = nil } label: {
                            Text(Chords.QLAB[q]!)
                                .font(.fig(13, on ? .bold : .semibold))
                                .foregroundStyle(on ? .white : FW.muted)
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                                .frame(maxWidth: .infinity)
                                .frame(height: 34)
                                .background(on ? FW.ink : FW.card, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                        }
                        .buttonStyle(PressScale(scale: 0.94))
                    }
                }
                let vs = Chords.voices(root: m.learnRoot, qual: m.learnQual)
                let cur = m.learnVoicing
                HStack(spacing: 6) {
                    ForEach(Array(vs.enumerated()), id: \.element.id) { i, x in
                        let on = x == cur
                        Button { m.learnVoice = i; m.learnTap = nil } label: {
                            Text(voiceLabel(x))
                                .font(.fig(13, on ? .bold : .semibold))
                                .foregroundStyle(on ? FW.accentDeep : FW.muted)
                                .lineLimit(1)
                                .minimumScaleFactor(0.75)
                                .padding(.horizontal, 6)
                                .frame(maxWidth: .infinity)
                                .frame(height: 36)
                                .background(on ? FW.accent.opacity(0.07) : FW.card, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                                .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(on ? FW.accent : .clear, lineWidth: 2))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            HStack(spacing: 12) {
                noteText(m.learnInfo, 14)
                    .lineSpacing(2)
                    .foregroundStyle(FW.muted)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
                if m.learnMode == .chords {
                    Button { GuitarSynth.shared.strum(m.learnVoicing) } label: {
                        Text("Strum")
                            .font(.fig(15, .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 18)
                            .frame(height: 40)
                            .background(FW.accent, in: Capsule())
                    }
                    .buttonStyle(PressScale(scale: 0.95))
                }
            }
            .frame(minHeight: 36)
        }
    }

    private func voiceLabel(_ x: Voicing) -> String {
        switch x.fam {
        case "open": return "Open"
        case "E": return "E-shape · fr \(x.b)"
        case "A": return "A-shape · fr \(x.b)"
        default: return "\(x.fam == "P6" ? "6th" : "5th")-string · fr \(x.b)"
        }
    }
}
