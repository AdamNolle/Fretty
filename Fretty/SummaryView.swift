import SwiftUI

struct SummaryView: View {
    @Environment(AppModel.self) private var m

    var body: some View {
        if let s = m.sum {
            GeometryReader { geo in
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 16) {
                        VStack(spacing: 4) {
                            Kicker(text: s.kicker, size: 13)
                            Text(s.hero)
                                .font(.fig(88, .black))
                                .tracking(-4.4)
                                .foregroundStyle(FW.accent)
                                .minimumScaleFactor(0.6)
                                .lineLimit(1)
                            Text(s.heroSub).font(.fig(17))
                        }
                        .multilineTextAlignment(.center)
                        .riseIn(0.4)

                        ForEach(Array(s.banners.enumerated()), id: \.offset) { i, b in
                            Text(b)
                                .font(.fig(15, .heavy))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 10)
                                .background(FW.ink, in: Capsule())
                                .popIn(0.45)
                        }

                        HStack(spacing: 8) {
                            StatTile(value: "\(s.best)", label: "Best run", centered: true)
                            StatTile(value: s.avg + "s", label: "Avg time", centered: true)
                            StatTile(value: "\(s.streak)", label: "Day streak", centered: true)
                        }

                        if !s.misses.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Coming back sooner").font(.fig(17, .bold))
                                VStack(spacing: 0) {
                                    ForEach(Array(s.misses.enumerated()), id: \.offset) { i, mi in
                                        HStack(spacing: 12) {
                                            noteText(mi.name, 15, .heavy)
                                                .padding(.horizontal, 8)
                                                .frame(minWidth: 44, minHeight: 32)
                                                .background(FW.hairline, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                                            Text(mi.whereText).font(.fig(15))
                                            Spacer(minLength: 0)
                                        }
                                        .padding(.vertical, 12)
                                        .overlay(alignment: .top) { if i > 0 { FW.hairline.frame(height: 1) } }
                                    }
                                }
                                .padding(.horizontal, 16)
                                .background(FW.card, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                                .cardShadow()
                            }
                        }

                        Spacer(minLength: 0)

                        VStack(spacing: 10) {
                            PrimaryButton(title: "Go again", height: 56, size: 17, weight: .bold, glow: false) { m.start(s.kind) }
                            Button { withAnimation(.easeOut(duration: 0.2)) { m.done() } } label: {
                                Text("Done")
                                    .font(.fig(17, .semibold))
                                    .foregroundStyle(FW.ink)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 56)
                                    .background(FW.card, in: Capsule())
                                    .shadow(color: FW.shadow.opacity(0.08), radius: 1, y: 1)
                            }
                            .buttonStyle(PressScale())
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 22)
                    .padding(.bottom, 20)
                    .frame(minHeight: geo.size.height)
                }
            }
        }
    }
}
