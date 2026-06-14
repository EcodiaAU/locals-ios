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
    //
    // 2026-06-14: dark mode wired. Every chrome paint now resolves through
    // DesignTokens.dual() so light <-> dark flips with userInterfaceStyle.
    // Light is warm off-white + ink (unchanged). Dark inverts: ink ground +
    // cream foreground, accent flips to cream (the action paint that reads
    // on ink the way ink reads on off-white). Mustard is never the chrome.
    static let bg = DesignTokens.dual(
        light: Color(red: 0.980, green: 0.976, blue: 0.961),   // #FAF9F5 warm off-white
        dark:  Color(red: 0.122, green: 0.094, blue: 0.063)    // #1F1810 ink ground
    )
    static let bgElevated = DesignTokens.dual(
        light: Color(red: 1.000, green: 1.000, blue: 1.000),   // #FFFFFF
        dark:  Color(red: 0.165, green: 0.133, blue: 0.094)    // #2A2218 ink + lift
    )
    static let bgSubtle = DesignTokens.dual(
        light: Color(red: 0.949, green: 0.945, blue: 0.929),   // #F2F1ED
        dark:  Color(red: 0.200, green: 0.165, blue: 0.122)    // #332A1F ink + more lift
    )
    static let fg = DesignTokens.FG.`default`
    static let fgMuted = DesignTokens.FG.muted
    static let fgTrace = DesignTokens.FG.trace
    static let accent = DesignTokens.dual(
        light: DesignTokens.Brand.ink,                          // ink on off-white
        dark:  DesignTokens.Brand.cream                         // cream on ink (the action paint inverts)
    )
    static let accentDeep = DesignTokens.dual(
        light: DesignTokens.Brand.ink,
        dark:  DesignTokens.Brand.cream
    )
    static let onAccent = DesignTokens.dual(
        light: Color(red: 0.980, green: 0.976, blue: 0.961),   // off-white text on ink button
        dark:  Color(red: 0.122, green: 0.094, blue: 0.063)    // ink text on cream button
    )
    static let border = DesignTokens.Border.`default`
    static let borderSubtle = DesignTokens.Border.subtle
    static let ink = DesignTokens.Brand.ink
    static let cream = DesignTokens.Brand.cream
    static let mustard = DesignTokens.Brand.mustard                       // kept for icon + merchant-theme usage

    // User-location pin: a desaturated denim that reads as "you are here"
    // against the mustard merchant chrome without fighting it. iOS-blue-ish
    // but warmer; sits the user dot in the same family as Apple's default
    // while staying inside the locals palette. Brightened on dark so it
    // doesn't sink into the ink ground.
    static let userPin = DesignTokens.dual(
        light: Color(red: 0.235, green: 0.420, blue: 0.620),
        dark:  Color(red: 0.420, green: 0.620, blue: 0.820)
    )

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
