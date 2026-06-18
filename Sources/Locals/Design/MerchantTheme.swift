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

    // Six fonts allowed per migration 0006, all now bundled as real families
    // (parity with locals-web, which loads the same six from Google Fonts).
    // Before this, only Spectral was bundled and eb-garamond/cardo/cormorant
    // all collapsed to one system serif italic while work-sans/inter both
    // collapsed to system sans, so the theme picker advertised distinct fonts
    // it could not render. The headline renders in the italic cut of each
    // serif to hold the editorial register; the two sans render upright
    // semibold. Referenced by PostScript name so the variable fonts
    // (EB Garamond, Cormorant, Work Sans, Inter) resolve to their default
    // instance; the .weight() axis nudge styles the sans titles.
    static func titleFont(for key: String?) -> (CGFloat) -> Font {
        switch (key ?? "spectral").lowercased() {
        case "spectral":
            return { Font.custom("Spectral-Italic", size: $0, relativeTo: .largeTitle) }
        case "eb-garamond":
            return { Font.custom("EBGaramond-Italic", size: $0, relativeTo: .largeTitle) }
        case "cardo":
            return { Font.custom("Cardo-Italic", size: $0, relativeTo: .largeTitle) }
        case "cormorant-garamond":
            return { Font.custom("CormorantGaramond-LightItalic", size: $0, relativeTo: .largeTitle) }
        case "work-sans":
            return { Font.custom("WorkSans-Regular", size: $0, relativeTo: .largeTitle).weight(.semibold) }
        case "inter":
            fallthrough
        default:
            return { Font.custom("Inter-Regular", size: $0, relativeTo: .largeTitle).weight(.semibold) }
        }
    }

    static func bodyFont(for key: String?) -> (CGFloat) -> Font {
        switch (key ?? "spectral").lowercased() {
        case "spectral":
            return { Font.custom("Spectral-Regular", size: $0, relativeTo: .body) }
        case "eb-garamond":
            return { Font.custom("EBGaramond-Regular", size: $0, relativeTo: .body) }
        case "cardo":
            return { Font.custom("Cardo-Regular", size: $0, relativeTo: .body) }
        case "cormorant-garamond":
            return { Font.custom("CormorantGaramond-Light", size: $0, relativeTo: .body) }
        case "work-sans":
            return { Font.custom("WorkSans-Regular", size: $0, relativeTo: .body) }
        case "inter":
            fallthrough
        default:
            return { Font.custom("Inter-Regular", size: $0, relativeTo: .body) }
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
