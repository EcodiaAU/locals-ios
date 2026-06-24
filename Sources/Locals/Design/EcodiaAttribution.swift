import SwiftUI

/// The Ecodia attribution mark: "built by Ecodia" (lowercase, never
/// abbreviated), italic serif, receding, linking to ecodia.au.
///
/// Canonical spec, do NOT redesign: no pill, no border,
/// no icon, and it MUST NOT be underlined. SwiftUI's `Link` renders a tinted,
/// underlined label by default, so this wraps the text in a `Button` (plain
/// style) that opens the URL, which carries neither tint nor underline.
/// Colour recedes via `fgTrace`. EB Garamond is not bundled on iOS; the
/// bundled italic serif renders the same receding register.
struct EcodiaAttribution: View {
    @Environment(\.openURL) private var openURL

    var body: some View {
        Button {
            openURL(URL(string: "https://ecodia.au")!)
        } label: {
            Text("built by Ecodia")
                .font(LocalsTheme.serif(13, italic: true))
                .foregroundStyle(LocalsTheme.fgTrace)
                .underline(false)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("built by Ecodia")
    }
}
