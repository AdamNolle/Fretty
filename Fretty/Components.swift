import SwiftUI

/// Pill-track segmented control used throughout the design.
struct SegControl<ID: Hashable>: View {
    let items: [(ID, String)]
    let selected: ID
    var height: CGFloat = 30
    var fontSize: CGFloat = 14
    var capsule = false
    var fill = true
    let onSelect: (ID) -> Void

    var body: some View {
        HStack(spacing: 3) {
            ForEach(items.indices, id: \.self) { i in
                let (id, label) = items[i]
                let on = id == selected
                Button { onSelect(id) } label: {
                    Text(label)
                        .font(.fig(fontSize, on ? .bold : .semibold))
                        .foregroundStyle(on ? FW.ink : FW.muted)
                        .lineLimit(1)
                        .padding(.horizontal, fill ? 4 : 13)
                        .frame(maxWidth: fill ? .infinity : nil)
                        .frame(height: height)
                        .background {
                            if on {
                                RoundedRectangle(cornerRadius: capsule ? height / 2 : 8, style: .continuous)
                                    .fill(FW.segOn)
                                    .shadow(color: FW.shadow.opacity(0.15), radius: 1.5, y: 1)
                            }
                        }
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
        .background(FW.segTrack, in: RoundedRectangle(cornerRadius: capsule ? 999 : 11, style: .continuous))
        .animation(.easeOut(duration: 0.15), value: selected)
    }
}

/// Small uppercase label.
struct Kicker: View {
    let text: String
    var size: CGFloat = 12
    var tracking: CGFloat = 0.08
    var body: some View {
        Text(text.uppercased())
            .font(.fig(size, .bold))
            .tracking(size * tracking)
            .foregroundStyle(FW.muted)
    }
}

/// White rounded card.
struct Card<Content: View>: View {
    var radius: CGFloat = 20
    var padding: EdgeInsets = EdgeInsets(top: 14, leading: 14, bottom: 14, trailing: 14)
    var strong = false
    @ViewBuilder let content: Content
    var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(FW.card, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
            .cardShadow(strong: strong)
    }
}

/// Primary pill button.
struct PrimaryButton: View {
    let title: String
    var height: CGFloat = 54
    var size: CGFloat = 18
    var weight: Font.Weight = .heavy
    var glow = true
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.fig(size, weight))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: height)
                .background(FW.accent, in: Capsule())
                .shadow(color: FW.accent.opacity(glow ? 0.3 : 0), radius: 14, y: 10)
        }
        .buttonStyle(PressScale())
    }
}

/// Mini fretboard map strip used on Home and above the board.
struct FretMap: View {
    let from: Int
    let to: Int
    var height: CGFloat = 16
    var radius: CGFloat = 4
    var dot: CGFloat = 4
    var divider: CGFloat = 1
    var border: CGFloat = 2
    var nutWidth: CGFloat = 3
    var showDouble = false

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width / CGFloat(Music.MAPN)
            ZStack(alignment: .topLeading) {
                FW.wood
                HStack(spacing: 0) {
                    ForEach(0..<Music.MAPN, id: \.self) { f in
                        ZStack {
                            if Music.INLAYS.contains(f) {
                                Circle().fill(FW.inlayMap).frame(width: dot, height: dot)
                            }
                            if showDouble && f == 12 {
                                VStack(spacing: 0) {
                                    Spacer().frame(height: height * 0.28 - dot / 2)
                                    Circle().fill(FW.inlayMap).frame(width: dot, height: dot)
                                    Spacer().frame(height: height * 0.44 - dot)
                                    Circle().fill(FW.inlayMap).frame(width: dot, height: dot)
                                    Spacer()
                                }
                            }
                        }
                        .frame(width: w, height: height)
                        .overlay(alignment: .trailing) { FW.woodLine.frame(width: divider) }
                    }
                }
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(FW.accent.opacity(0.22))
                    .overlay(RoundedRectangle(cornerRadius: radius, style: .continuous).strokeBorder(FW.accent, lineWidth: border))
                    .frame(width: w * CGFloat(min(to, Music.MAPN - 1) - from + 1), height: height)
                    .offset(x: w * CGFloat(from))
                    .animation(.easeOut(duration: 0.3), value: from)
                    .animation(.easeOut(duration: 0.3), value: to)
                FW.nut.frame(width: nutWidth, height: height)
            }
        }
        .frame(height: height)
        .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
    }
}
