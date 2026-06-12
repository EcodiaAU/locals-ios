import SwiftUI

// Locals chrome palette + typography. The merchant-detail screens swap into
// per-merchant themes (see MerchantTheme.swift); everything else (Discover,
// Profile, Onboarding, Merchant admin) renders in this chrome.
//
// The base register is "marketing-bold": saturated mustard + cream + ink,
// generous spacing, Inter as the body family. Merchant detail breaks the
// rules and renders in the merchant's chosen theme_color + theme_font.

enum LocalsTheme {
    // Chrome backgrounds + foreground.
    // 2026-06-12: de-mustard pass. Tate verbatim: "the mustard is actually
    // everywhere across the app and i hate it... use the nice warm off white
    // that you've made the bottom modals." The brand cream (#E8DFC9) and
    // mustard (#C49A3F) survive as ICON + MERCHANT-THEME paints only; chrome
    // pages render in warm off-white. Accents resolve to ink, not mustard.
    static let bg = Color(red: 0.980, green: 0.976, blue: 0.961)         // #FAF9F5 warm off-white
    static let bgElevated = Color(red: 1.0, green: 1.0, blue: 1.0)        // #FFFFFF
    static let bgSubtle = Color(red: 0.949, green: 0.945, blue: 0.929)    // #F2F1ED
    static let fg = DesignTokens.FG.`default`
    static let fgMuted = DesignTokens.FG.muted
    static let fgTrace = DesignTokens.FG.trace
    static let accent = DesignTokens.Brand.ink                            // was mustard — ink reads as the action paint on white
    static let accentDeep = DesignTokens.Brand.ink
    static let onAccent = Color(red: 0.980, green: 0.976, blue: 0.961)    // off-white on ink
    static let border = DesignTokens.Border.`default`
    static let borderSubtle = DesignTokens.Border.subtle
    static let ink = DesignTokens.Brand.ink
    static let cream = DesignTokens.Brand.cream
    static let mustard = DesignTokens.Brand.mustard                       // kept for icon + merchant-theme usage

    // User-location pin: a desaturated denim that reads as "you are here"
    // against the mustard merchant chrome without fighting it. iOS-blue-ish
    // but warmer; sits the user dot in the same family as Apple's default
    // while staying inside the locals palette.
    static let userPin = Color(red: 0.235, green: 0.420, blue: 0.620)

    // The headline serif. Spectral is bundled (see Info.plist UIAppFonts).
    // If the font hasn't loaded yet, SwiftUI falls back to system serif.
    static func display(_ size: CGFloat, italic: Bool = true) -> Font {
        let name = italic ? "Spectral-Italic" : "Spectral-SemiBold"
        return .custom(name, size: size, relativeTo: .largeTitle)
    }

    static func serif(_ size: CGFloat, italic: Bool = false) -> Font {
        let name = italic ? "Spectral-Italic" : "Spectral-Regular"
        return .custom(name, size: size, relativeTo: .body)
    }

    static func body(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .`default`)
    }

    static func mono(_ size: CGFloat, weight: Font.Weight = .medium) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }
}

// Section "eyebrow" label - small caps, wide letter-spacing, used to anchor
// reading. Matches the locals-web editorial register.
struct Eyebrow: View {
    let text: String
    var body: some View {
        Text(text.uppercased())
            .font(LocalsTheme.body(DesignTokens.Size.xs, weight: .medium))
            .tracking(1.6)
            .foregroundStyle(LocalsTheme.fgMuted)
    }
}

// The marketing-bold filled pill button. The accent (mustard) ground +
// cream foreground reads as the brand signature. Tap shrinks with a soft
// scale + haptic.
struct LocalsPrimaryButtonStyle: ButtonStyle {
    var fill: Color = LocalsTheme.accent
    var foreground: Color = LocalsTheme.onAccent
    func makeBody(configuration: Configuration) -> some View {
        LocalsPrimaryButtonBody(configuration: configuration, fill: fill, foreground: foreground)
    }
}

private struct LocalsPrimaryButtonBody: View {
    let configuration: ButtonStyle.Configuration
    let fill: Color
    let foreground: Color
    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        configuration.label
            .font(LocalsTheme.body(DesignTokens.Size.base, weight: .semibold))
            .frame(maxWidth: .infinity, minHeight: 52)
            .padding(.horizontal, DesignTokens.Space.lg)
            .background(fill)
            .foregroundStyle(foreground)
            .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.xl, style: .continuous))
            .opacity(isEnabled ? 1 : 0.38)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: DesignTokens.Motion.fast), value: configuration.isPressed)
            .sensoryFeedback(.impact(weight: .medium), trigger: configuration.isPressed) { _, n in n }
    }
}

// The quiet outline variant. Used for secondary actions and inline
// dismissals - sits one step back from primary.
struct LocalsSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(LocalsTheme.body(DesignTokens.Size.base, weight: .medium))
            .frame(maxWidth: .infinity, minHeight: 52)
            .padding(.horizontal, DesignTokens.Space.lg)
            .overlay(
                RoundedRectangle(cornerRadius: DesignTokens.Radius.xl, style: .continuous)
                    .strokeBorder(LocalsTheme.border, lineWidth: 1)
            )
            .foregroundStyle(LocalsTheme.fg)
            .opacity(configuration.isPressed ? 0.7 : 1)
            .animation(.easeOut(duration: DesignTokens.Motion.fast), value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == LocalsPrimaryButtonStyle {
    static var localsPrimary: LocalsPrimaryButtonStyle { .init() }
    static func localsPrimary(fill: Color, foreground: Color) -> LocalsPrimaryButtonStyle {
        .init(fill: fill, foreground: foreground)
    }
}

extension ButtonStyle where Self == LocalsSecondaryButtonStyle {
    static var localsSecondary: LocalsSecondaryButtonStyle { .init() }
}
