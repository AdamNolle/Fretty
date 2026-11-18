import SwiftUI

@main
struct FrettyApp: App {
    @State private var model = AppModel()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(model)
                .preferredColorScheme(.light)
        }
    }
}

struct RootView: View {
    @Environment(AppModel.self) private var m

    var body: some View {
        ZStack {
            FW.bg.ignoresSafeArea()

            Group {
                switch m.screen {
                case .tabs:
                    switch m.tab {
                    case .play: HomeView()
                    case .progress: ProgressScreen()
                    case .learn: LearnView()
                    }
                case .quiz: QuizView()
                case .summary: SummaryView()
                }
            }
            .transition(.opacity)

            if m.screen == .tabs {
                VStack {
                    Spacer()
                    TabBar()
                }
                .ignoresSafeArea(.keyboard)
                .transition(.opacity)
            }

            if let t = m.toast {
                VStack {
                    ToastView(text: t.text).id(t.id)
                    Spacer()
                }
                .padding(.top, 50)
                .allowsHitTesting(false)
            }
        }
        .foregroundStyle(FW.ink)
        .animation(.easeOut(duration: 0.2), value: m.screen)
        .animation(.easeOut(duration: 0.15), value: m.tab)
        .onAppear { GuitarSynth.shared.warmUp() }
    }
}

struct TabBar: View {
    @Environment(AppModel.self) private var m
    @Namespace private var ns

    var body: some View {
        HStack(spacing: 4) {
            ForEach([Tab.play, .progress, .learn], id: \.self) { id in
                let label = id.rawValue.capitalized
                let on = m.tab == id
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                        m.tab = id
                        m.learnTap = nil
                    }
                } label: {
                    Text(label)
                        .font(.fig(15, on ? .bold : .semibold))
                        .foregroundStyle(on ? .white : FW.muted)
                        .padding(.horizontal, 22)
                        .frame(height: 48)
                        .background {
                            if on { Capsule().fill(FW.ink).matchedGeometryEffect(id: "tab", in: ns) }
                        }
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(6)
        .background(.ultraThinMaterial, in: Capsule())
        .background(Color(oklch: 0.99, 0.012, 86, opacity: 0.86), in: Capsule())
        .overlay(Capsule().strokeBorder(FW.track, lineWidth: 1))
        .shadow(color: FW.shadow.opacity(0.12), radius: 14, y: 8)
        .padding(.bottom, 2)
    }
}

/// `fwToast`: drops in, holds, fades out over 1.8s.
struct ToastView: View {
    let text: String
    @State private var phase = 0

    var body: some View {
        Text(text)
            .font(.fig(15, .heavy))
            .foregroundStyle(.white)
            .padding(.horizontal, 18)
            .padding(.vertical, 10)
            .background(FW.ink, in: Capsule())
            .shadow(color: FW.ink.opacity(0.3), radius: 13, y: 10)
            .scaleEffect(phase == 0 ? 0.8 : phase == 1 ? 1.05 : 1)
            .offset(y: phase == 0 ? -10 : phase == 3 ? -6 : 0)
            .opacity(phase == 0 || phase == 3 ? 0 : 1)
            .task {
                withAnimation(.easeOut(duration: 0.27)) { phase = 1 }
                try? await Task.sleep(for: .milliseconds(270))
                withAnimation(.easeOut(duration: 0.18)) { phase = 2 }
                try? await Task.sleep(for: .milliseconds(1100))
                withAnimation(.easeIn(duration: 0.27)) { phase = 3 }
            }
    }
}
