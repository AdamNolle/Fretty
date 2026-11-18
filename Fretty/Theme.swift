import SwiftUI

// MARK: - OKLCH → sRGB

extension Color {
    /// Builds a color from OKLCH components (L 0…1, C chroma, H degrees), matching CSS `oklch()`.
    init(oklch l: Double, _ c: Double, _ h: Double, opacity: Double = 1) {
        let hr = h * .pi / 180
        let a = c * cos(hr), b = c * sin(hr)
        let l_ = l + 0.3963377774 * a + 0.2158037573 * b
        let m_ = l - 0.1055613458 * a - 0.0638541728 * b
        let s_ = l - 0.0894841775 * a - 1.2914855480 * b
        let L = l_ * l_ * l_, M = m_ * m_ * m_, S = s_ * s_ * s_
        let r = 4.0767416621 * L - 3.3077115913 * M + 0.2309699292 * S
        let g = -1.2684380046 * L + 2.6097574011 * M - 0.3413193965 * S
        let bl = -0.0041960863 * L - 0.7034186147 * M + 1.7076147010 * S
        func gamma(_ x: Double) -> Double {
            let v = max(0, min(1, x))
            return v <= 0.0031308 ? 12.92 * v : 1.055 * pow(v, 1 / 2.4) - 0.055
        }
        self.init(.sRGB, red: gamma(r), green: gamma(g), blue: gamma(bl), opacity: opacity)
    }
}

// MARK: - Palette

enum FW {
    static let bg = Color(oklch: 0.962, 0.02, 84)
    static let card = Color(oklch: 0.992, 0.009, 86)
    static let segTrack = Color(oklch: 0.925, 0.022, 82)
    static let segOn = Color(oklch: 0.997, 0.006, 86)
    static let ink = Color(oklch: 0.26, 0.025, 55)
    static let muted = Color(oklch: 0.49, 0.032, 62)
    static let hairline = Color(oklch: 0.905, 0.022, 80)
    static let track = Color(oklch: 0.895, 0.022, 80)
    static let accent = Color(oklch: 0.5, 0.16, 265)
    static let accentDeep = Color(oklch: 0.42, 0.16, 265)
    static let good = Color(oklch: 0.55, 0.13, 155)
    static let bad = Color(oklch: 0.55, 0.18, 25)
    static let badText = Color(oklch: 0.5, 0.18, 25)
    static let badSoftBg = Color(oklch: 0.96, 0.03, 25)
    static let weakBg = Color(oklch: 0.95, 0.035, 25)
    static let weakFg = Color(oklch: 0.5, 0.17, 25)
    static let dimBg = Color(oklch: 0.915, 0.02, 80)
    static let dimFg = Color(oklch: 0.63, 0.028, 68)
    static let stepTodo = Color(oklch: 0.86, 0.024, 78)
    static let checkOff = Color(oklch: 0.8, 0.024, 76)
    static let border = Color(oklch: 0.85, 0.024, 78)
    static let wood = Color(oklch: 0.83, 0.042, 72)
    static let woodLine = Color(oklch: 0.7, 0.01, 80)
    static let nut = Color(oklch: 0.28, 0.03, 50)
    static let inlay = Color(oklch: 0.3, 0.035, 50, opacity: 0.45)
    static let inlayMap = Color(oklch: 0.3, 0.035, 50, opacity: 0.5)
    static let woundString = Color(oklch: 0.5, 0.035, 65)
    static let plainString = Color(oklch: 0.58, 0.01, 80)
    static let wireTop = Color(oklch: 0.8, 0.01, 80)
    static let wireBottom = Color(oklch: 0.55, 0.01, 80)
    static let shadow = Color(oklch: 0.38, 0.05, 58)

    /// Accuracy heat colour from red (0) to green (1).
    static func heat(_ acc: Double) -> Color {
        Color(oklch: 0.66 + acc * 0.08, 0.14, 25 + acc * 125)
    }
}

// MARK: - Type

extension Font {
    static func fig(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        .custom("Figtree", size: size).weight(weight)
    }
    static func mono(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        .custom(weight == .regular ? "DMMono-Regular" : "DMMono-Medium", size: size)
    }
    static func music(_ size: CGFloat) -> Font {
        .custom("NotoMusic-Regular", size: size)
    }
}

// MARK: - Shared modifiers

extension View {
    func cardShadow(strong: Bool = false) -> some View {
        self
            .shadow(color: FW.shadow.opacity(0.06), radius: 1, y: 1)
            .shadow(color: FW.shadow.opacity(strong ? 0.05 : 0), radius: 12, y: 8)
    }
}

/// Matches the CSS `style-active="transform:scale(…)"` press effect.
struct PressScale: ButtonStyle {
    var scale: CGFloat = 0.98
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

/// `fwPop`: scale .3 → 1.15 → 1 with fade-in.
struct PopIn: ViewModifier {
    var duration: Double = 0.3
    @State private var scale: CGFloat = 0.3
    @State private var opacity: Double = 0
    func body(content: Content) -> some View {
        content
            .scaleEffect(scale)
            .opacity(opacity)
            .onAppear {
                withAnimation(.easeOut(duration: duration * 0.7)) {
                    scale = 1.15; opacity = 1
                } completion: {
                    withAnimation(.easeInOut(duration: duration * 0.3)) { scale = 1 }
                }
            }
    }
}

/// `fwShake`: horizontal wobble.
struct Shake: ViewModifier {
    @State private var go = false
    func body(content: Content) -> some View {
        content
            .keyframeAnimator(initialValue: CGFloat(0), trigger: go) { view, x in
                view.offset(x: x)
            } keyframes: { _ in
                KeyframeTrack {
                    LinearKeyframe(-5, duration: 0.08)
                    LinearKeyframe(5, duration: 0.08)
                    LinearKeyframe(-3, duration: 0.08)
                    LinearKeyframe(3, duration: 0.08)
                    LinearKeyframe(0, duration: 0.08)
                }
            }
            .onAppear { go = true }
    }
}

/// `fwRise`: slide up 18pt and fade in.
struct RiseIn: ViewModifier {
    var duration: Double = 0.25
    @State private var shown = false
    func body(content: Content) -> some View {
        content
            .offset(y: shown ? 0 : 18)
            .opacity(shown ? 1 : 0)
            .onAppear { withAnimation(.easeOut(duration: duration)) { shown = true } }
    }
}

extension View {
    func popIn(_ d: Double = 0.3) -> some View { modifier(PopIn(duration: d)) }
    func shake() -> some View { modifier(Shake()) }
    func riseIn(_ d: Double = 0.25) -> some View { modifier(RiseIn(duration: d)) }
}

// MARK: - Note typography

/// Figtree has no ♯/♭ glyphs, so set accidentals in SF at a tuned size/baseline to avoid the
/// wide, uneven fallback spacing.
func noteText(_ s: String, _ size: CGFloat, _ weight: Font.Weight = .regular) -> Text {
    var out = Text(verbatim: "")
    var buf = ""
    func flush() {
        if !buf.isEmpty { out = Text("\(out)\(Text(verbatim: buf).font(.fig(size, weight)))"); buf = "" }
    }
    for ch in s {
        if ch == "♯" || ch == "♭" {
            flush()
            let acc = Text(verbatim: String(ch))
                .font(.system(size: size * (ch == "♯" ? 1.0 : 0.95), weight: weight))
                .baselineOffset(ch == "♯" ? size * 0.02 : 0)
            out = Text("\(out)\(acc)")
        } else {
            buf.append(ch)
        }
    }
    flush()
    return out
}
