import SwiftUI

// Per-merchant theming. Each merchant picks one of 8 preset background colours
// (see migration 0006 / 0009) and one of 6 fonts. The detail page renders in
// the merchant's theme - full-bleed background, headline in the chosen serif,
// crowd signal and rewards inheriting the foreground colour.
//
// The choice is constrained at the DB layer (CHECK constraint) so the iOS
// app trusts the value and falls back to sensible defaults if it ever sees a
// string outside the set.

enum MerchantTheme {
    struct Resolved: Equatable {
        let background: Color
        let foreground: Color
        let accent: Color
        let muted: Color
        let titleFont: (CGFloat) -> Font
        let bodyFont: (CGFloat) -> Font

        static func == (lhs: Resolved, rhs: Resolved) -> Bool {
            // We compare the resolved Colors; font closures are stable per theme key
            lhs.background.description == rhs.background.description
            && lhs.foreground.description == rhs.foreground.description
        }
    }

    // The 8 allowed background colours, lightened in migration 0009 so the
    // detail page reads as warm + paper-like rather than saturated.
    static func background(for hex: String?) -> Color {
        switch hex?.uppercased() {
        case "#FCE4E4": return Color(red: 0.988, green: 0.894, blue: 0.894)
        case "#E2F2E8": return Color(red: 0.886, green: 0.949, blue: 0.910)
        case "#EBE4F3": return Color(red: 0.922, green: 0.894, blue: 0.953)
        case "#FCEAD5": return Color(red: 0.988, green: 0.918, blue: 0.835)
        case "#E2EDF3": return Color(red: 0.886, green: 0.929, blue: 0.953)
        case "#FCF1C9": return Color(red: 0.988, green: 0.945, blue: 0.788)
        case "#1F1810": return DesignTokens.Brand.ink
        case "#FFFFFF": return .white
        default:        return DesignTokens.Brand.cream
        }
    }

    // Pick foreground by background luminance - dark themes get cream text, the
    // rest get ink. Approximates WCAG contrast without a runtime calc.
    static func foreground(for hex: String?) -> Color {
        switch hex?.uppercased() {
        case "#1F1810": return DesignTokens.Brand.cream
        default:        return DesignTokens.Brand.ink
        }
    }

    static func muted(for hex: String?) -> Color {
        switch hex?.uppercased() {
        case "#1F1810": return Color(red: 0.910, green: 0.875, blue: 0.788, opacity: 0.62)
        default:        return Color(red: 0.122, green: 0.094, blue: 0.063, opacity: 0.62)
        }
    }

    static func accent(for hex: String?) -> Color {
        // The detail-page accent for rewards / call-to-action. Mustard reads
        // well on every preset (verified against the lightened palette).
        DesignTokens.Brand.mustard
    }

    // Six fonts allowed per migration 0006. Spectral is bundled; the others
    // gracefully degrade to system serif / system sans if the family is not
    // available on the device. iOS 17 ships SF Pro everywhere - the rest are
    // system fallbacks weighted to feel intentional.
    static func titleFont(for key: String?) -> (CGFloat) -> Font {
        switch (key ?? "spectral").lowercased() {
        case "spectral":
            return { Font.custom("Spectral-Italic", size: $0, relativeTo: .largeTitle) }
        case "eb-garamond":
            return { Font.system(size: $0, weight: .regular, design: .serif).italic() }
        case "cardo":
            return { Font.system(size: $0, weight: .regular, design: .serif).italic() }
        case "cormorant-garamond":
            return { Font.system(size: $0, weight: .light, design: .serif).italic() }
        case "work-sans":
            return { Font.system(size: $0, weight: .semibold, design: .default) }
        case "inter":
            fallthrough
        default:
            return { Font.system(size: $0, weight: .semibold, design: .default) }
        }
    }

    static func bodyFont(for key: String?) -> (CGFloat) -> Font {
        switch (key ?? "spectral").lowercased() {
        case "spectral":
            return { Font.custom("Spectral-Regular", size: $0, relativeTo: .body) }
        case "eb-garamond", "cardo", "cormorant-garamond":
            return { Font.system(size: $0, weight: .regular, design: .serif) }
        default:
            return { Font.system(size: $0, weight: .regular, design: .default) }
        }
    }

    static func resolve(color: String?, font: String?) -> Resolved {
        Resolved(
            background: background(for: color),
            foreground: foreground(for: color),
            accent: accent(for: color),
            muted: muted(for: color),
            titleFont: titleFont(for: font),
            bodyFont: bodyFont(for: font)
        )
    }
}
