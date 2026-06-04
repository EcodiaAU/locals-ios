import SwiftUI

// Locals chrome palette + typography. The merchant-detail screens swap into
// per-merchant themes (see MerchantTheme.swift); everything else (Discover,
// Profile, Onboarding, Merchant admin) renders in this chrome.
//
// The base register is "marketing-bold": saturated mustard + cream + ink,
// generous spacing, Inter as the body family. Merchant detail breaks the
// rules and renders in the merchant's chosen theme_color + theme_font.

enum LocalsTheme {
    // Chrome backgrounds + foreground
    static let bg = DesignTokens.BG.`default`
    static let bgElevated = DesignTokens.BG.elevated
    static let bgSubtle = DesignTokens.BG.subtle
    static let fg = DesignTokens.FG.`default`
    static let fgMuted = DesignTokens.FG.muted
    static let fgTrace = DesignTokens.FG.trace
    static let accent = DesignTokens.Brand.mustard
    static let accentDeep = DesignTokens.Brand.mustard_deep
    static let onAccent = DesignTokens.FG.onAccent
    static let border = DesignTokens.Border.`default`
    static let borderSubtle = DesignTokens.Border.subtle
    static let ink = DesignTokens.Brand.ink
    static let cream = DesignTokens.Brand.cream

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
        configuration.label
            .font(LocalsTheme.body(DesignTokens.Size.base, weight: .semibold))
            .frame(maxWidth: .infinity, minHeight: 52)
            .padding(.horizontal, DesignTokens.Space.lg)
            .background(fill)
            .foregroundStyle(foreground)
            .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.xl, style: .continuous))
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
