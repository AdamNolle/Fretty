import SwiftUI

// MARK: - Fretboard

struct FretboardView: View {
    let board: Board
    let onTap: (Int, Int) -> Void

    private static let stringWidths: [CGFloat] = [3.2, 2.7, 2.2, 1.8, 1.4, 1.1]

    var body: some View {
        VStack(spacing: 0) {
            // Position map
            HStack(spacing: 8) {
                Text("NUT").font(.fig(10, .bold)).tracking(0.8).foregroundStyle(FW.muted)
                FretMap(from: board.from, to: board.to)
                Text("BODY").font(.fig(10, .bold)).tracking(0.8).foregroundStyle(FW.muted)
            }
            .padding(.leading, 32)
            .padding(.bottom, 6)

            // String names + ×/○ marks
            HStack(alignment: .bottom, spacing: 0) {
                Text("fret")
                    .font(.fig(10, .bold))
                    .foregroundStyle(FW.muted)
                    .frame(width: 32)
                    .padding(.bottom, 16)
                ForEach(0..<6, id: \.self) { s in
                    let on = s == board.activeStr
                    VStack(spacing: 0) {
                        Text(Music.SHORT[s])
                            .font(.fig(14, on ? .heavy : .bold))
                            .foregroundStyle(on ? FW.accent : FW.muted)
                        Text(mark(s))
                            .font(.fig(14, .heavy))
                            .foregroundStyle(FW.ink)
                            .frame(height: 16)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .padding(.bottom, 2)

            if board.from > 0 {
                Text("↑ fret \(max(0, board.from - 1)) and the nut are this way")
                    .font(.fig(11))
                    .foregroundStyle(FW.muted)
                    .frame(maxWidth: .infinity)
                    .padding(.leading, 32)
                    .padding(.bottom, 3)
            }

            VStack(spacing: 0) {
                ForEach(board.rows) { r in
                    row(r, first: r.f == board.rows.first?.f, last: r.f == board.rows.last?.f)
                        // Markers may overflow a short row; keep them above neighbouring rows.
                        .zIndex(r.cells.contains { $0.mark != .none } || r.barreE || r.barreA ? 1 : 0)
                }
            }

            Text("↓ toward the body")
                .font(.fig(11))
                .foregroundStyle(FW.muted)
                .frame(maxWidth: .infinity)
                .padding(.leading, 32)
                .padding(.top, 3)
        }
        .frame(width: 316)
    }

    private func mark(_ s: Int) -> String {
        guard let v = board.voicing else { return "" }
        guard let f = v.frets[s] else { return "×" }
        return f == 0 ? "○" : ""
    }

    @ViewBuilder
    private func row(_ r: RowInfo, first: Bool, last: Bool) -> some View {
        HStack(spacing: 0) {
            ZStack {
                if r.marked {
                    Text("\(r.f)")
                        .font(.mono(12, .medium))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .frame(minWidth: 24, minHeight: 24)
                        .background(FW.ink, in: Capsule())
                } else {
                    Text("\(r.f)").font(.mono(12)).foregroundStyle(FW.muted)
                }
            }
            .frame(width: 32)

            GeometryReader { geo in
                let w = geo.size.width, h = geo.size.height
                ZStack(alignment: .topLeading) {
                  ZStack(alignment: .topLeading) {
                    // Wood / open area
                    if r.isOpen {
                        FW.bg
                        FW.nut.frame(height: 8).clipShape(RoundedRectangle(cornerRadius: 2)).offset(y: h - 8)
                    } else {
                        FW.wood
                        fretWire.offset(y: h - 3)
                    }
                    if r.topWire { fretWire }

                    // Inlays
                    if r.inlay { inlay.position(x: w / 2, y: h / 2) }
                    if r.dbl {
                        inlay.position(x: w / 3, y: h / 2)
                        inlay.position(x: w * 2 / 3, y: h / 2)
                    }

                    // Strings
                    ForEach(0..<6, id: \.self) { s in
                        Rectangle()
                            .fill(s < 4 ? FW.woundString : FW.plainString)
                            .frame(width: Self.stringWidths[s], height: h)
                            .position(x: w * (CGFloat(s) + 0.5) / 6, y: h / 2)
                    }
                  }
                  .frame(width: w, height: h)
                  .clipShape(UnevenRoundedRectangle(topLeadingRadius: first ? 6 : 0, bottomLeadingRadius: last ? 6 : 0,
                                                    bottomTrailingRadius: last ? 6 : 0, topTrailingRadius: first ? 6 : 0,
                                                    style: .continuous))

                    // Barre
                    if r.barreE || r.barreA {
                        let left = w * (r.barreE ? 0.03 : 0.195), right = w * 0.97
                        Capsule()
                            .fill(FW.ink)
                            .frame(width: right - left, height: min(24, h - 6))
                            .position(x: (left + right) / 2, y: h / 2)
                            .popIn()
                    }

                    // Cells
                    HStack(spacing: 0) {
                        ForEach(0..<6, id: \.self) { s in
                            CellButton(cell: r.cells[s], scale: min(1, (h + 6) / 34)) { onTap(s, r.f) }
                        }
                    }
                }
            }
        }
        .frame(maxHeight: .infinity)
    }

    private var fretWire: some View {
        LinearGradient(colors: [FW.wireTop, FW.wireBottom], startPoint: .top, endPoint: .bottom).frame(height: 3)
    }

    private var inlay: some View {
        Circle().fill(FW.inlay).frame(width: 14, height: 14)
    }
}

private struct CellButton: View {
    let cell: CellView
    var scale: CGFloat = 1
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                if cell.hl { FW.accent.opacity(0.2) }
                if cell.muted { FW.bg.opacity(0.65) }
                MarkerView(mark: cell.mark, label: cell.label)
                    .scaleEffect(scale)
                    .id("\(cell.mark)-\(cell.label)")
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .animation(.easeOut(duration: 0.15), value: cell.hl)
    }
}

struct MarkerView: View {
    let mark: Mark
    let label: String

    var body: some View {
        switch mark {
        case .none:
            EmptyView()
        case .target:
            ZStack {
                PulseRing()
                dot(34, FW.ink, size: 16).popIn()
            }
            .frame(width: 34, height: 34)
        case .good:
            dot(34, FW.good, size: 13)
                .background(Circle().fill(FW.good.opacity(0.25)).padding(-4))
                .popIn(0.35)
        case .bad:
            dot(34, FW.bad, size: 13).shake()
        case .chord:
            dot(30, FW.ink, size: 12)
                .shadow(color: Color(oklch: 0.3, 0.02, 60, opacity: 0.3), radius: 3, y: 2)
                .popIn()
        case .root:
            dot(32, FW.ink, size: 12)
                .background(Circle().fill(.white).padding(-2.5))
                .background(Circle().fill(FW.ink.opacity(0.35)).padding(-4))
                .shadow(color: Color(oklch: 0.3, 0.02, 60, opacity: 0.3), radius: 3, y: 2)
                .popIn()
        case .openStr:
            noteText(label, 10, .heavy)
                .foregroundStyle(FW.ink)
                .frame(width: 22, height: 22)
                .background(Circle().fill(FW.card))
                .overlay(Circle().strokeBorder(FW.ink, lineWidth: 2.5))
        }
    }

    private func dot(_ d: CGFloat, _ color: Color, size: CGFloat) -> some View {
        noteText(label, size, .heavy)
            .foregroundStyle(.white)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .frame(width: d, height: d)
            .background(Circle().fill(color))
    }
}

/// `fwPulse`: expanding, fading ring behind the target.
private struct PulseRing: View {
    @State private var go = false
    var body: some View {
        Circle()
            .fill(FW.ink)
            .scaleEffect(go ? 1.9 : 1)
            .opacity(go ? 0 : 0.5)
            .onAppear {
                withAnimation(.easeOut(duration: 1.2).repeatForever(autoreverses: false)) { go = true }
            }
    }
}

// MARK: - Staff

struct StaffView: View {
    let info: StaffInfo
    /// Uniform scale; geometry is redrawn at this size (not bitmap-scaled) so lines and glyphs stay crisp.
    var scale: CGFloat = 1

    var body: some View {
        let k = scale
        let H = 176 * k
        GeometryReader { geo in
            let w = geo.size.width
            let pos = Music.staffPos(info.midi, flat: info.flat)
            let y = (Music.SBASE - Double(pos) * Music.SSTEP) * k
            let x = w * 0.56
            let top = 55.25 * k, gap = 14 * k, line = max(1.5, 1.5 * k)
            ZStack(alignment: .topLeading) {
                // Staff lines
                ForEach(0..<5, id: \.self) { i in
                    FW.ink.frame(width: w - 28 * k, height: line).offset(x: 14 * k, y: top + CGFloat(i) * gap)
                }
                FW.ink.frame(width: line, height: gap * 4 + line).offset(x: 14 * k, y: top)
                FW.ink.frame(width: line, height: gap * 4 + line).offset(x: w - 14 * k - line, y: top)

                // Treble clef, baseline at y = 98
                Text("𝄞")
                    .font(.music(56 * k))
                    .foregroundStyle(FW.ink)
                    .fixedSize()
                    .alignmentGuide(.top) { d in d[.firstTextBaseline] - 98 * k }
                    .alignmentGuide(.leading) { _ in -22 * k }

                // Ledger lines
                ForEach(ledgers(pos), id: \.self) { p in
                    FW.ink.frame(width: 34 * k, height: line)
                        .offset(x: x - 17 * k, y: (Music.SBASE - Double(p) * Music.SSTEP) * k - line / 2)
                }

                Group {
                    if Music.isAcc(info.midi % 12) {
                        Text(info.flat ? "♭" : "♯")
                            .font(.system(size: 24 * k, weight: .semibold))
                            .foregroundStyle(FW.ink)
                            .position(x: x - 25 * k, y: y - (info.flat ? 4 * k : 0))
                    }
                    // Stem
                    FW.ink
                        .frame(width: 1.7 * k, height: 46 * k)
                        .offset(x: pos < 4 ? x + 7.4 * k : x - 9 * k, y: pos < 4 ? y - 45 * k : y + 1 * k)
                    // Note head
                    Ellipse()
                        .fill(FW.ink)
                        .frame(width: 18.5 * k, height: 13 * k)
                        .rotationEffect(.degrees(-20))
                        .position(x: x, y: y)
                }
                .animation(.easeOut(duration: 0.2), value: info.midi)

                if let name = info.name {
                    noteText(name, 20 * min(k, 1.2), .heavy)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(FW.ink, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .popIn()
                        .id(name)
                        .frame(width: w - 16, alignment: .trailing)
                        .offset(y: 14)
                }
            }
            .frame(width: w, height: H, alignment: .topLeading)
        }
        .frame(height: H)
        .background(FW.card, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .cardShadow(strong: true)
    }

    private func ledgers(_ pos: Int) -> [Int] {
        var L: [Int] = []
        var p = -2
        while p >= pos { L.append(p); p -= 2 }
        p = 10
        while p <= pos { L.append(p); p += 2 }
        return L
    }
}
