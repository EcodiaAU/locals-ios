import SwiftUI

/// Theme + font picker. 8 colour presets + 6 fonts. Live preview at the
/// top shows the merchant's headline rendered the way the customer will
/// see it on the detail page.
struct MerchantThemeView: View {
    let merchantId: UUID
    let initialColor: String?
    let initialFont: String?

    @EnvironmentObject var owners: OwnerMerchantService

    @State private var color: String = "#FCEAD5"
    @State private var font: String = "spectral"
    @State private var saving = false
    @State private var error: String?

    private let colors: [String] = [
        "#FCE4E4", "#E2F2E8", "#EBE4F3", "#FCEAD5",
        "#E2EDF3", "#FCF1C9", "#1F1810", "#FFFFFF"
    ]
    private let fonts: [(key: String, label: String)] = [
        ("spectral", "Spectral"),
        ("eb-garamond", "EB Garamond"),
        ("cardo", "Cardo"),
        ("cormorant-garamond", "Cormorant"),
        ("inter", "Inter"),
        ("work-sans", "Work Sans")
    ]

    private var theme: MerchantTheme.Resolved {
        MerchantTheme.resolve(color: color, font: font)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignTokens.Space.xxl) {
                preview
                colorGrid
                fontGrid
                if let error {
                    Text(error).foregroundStyle(.red)
                }
            }
            .padding(DesignTokens.Space.lg)
        }
        .background(LocalsTheme.bg)
        .navigationTitle("Theme")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button {
                    Task { await save() }
                } label: {
                    if saving { ProgressView() } else { Text("Save") }
                }
                .disabled(saving)
            }
        }
        .onAppear {
            color = initialColor ?? color
            font = initialFont ?? font
        }
    }

    private var preview: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Space.md) {
            Eyebrow(text: "Preview")
            VStack(alignment: .leading, spacing: DesignTokens.Space.sm) {
                Eyebrow(text: "Cafe")
                Text("Your business name")
                    .font(theme.titleFont(DesignTokens.Size.h2))
                    .foregroundStyle(theme.foreground)
                Text("This is how your detail page will read. Keep your story warm and short.")
                    .font(theme.bodyFont(DesignTokens.Size.base))
                    .foregroundStyle(theme.muted)
            }
            .padding(DesignTokens.Space.lg)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(theme.background)
            .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.lg, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: DesignTokens.Radius.lg, style: .continuous)
                    .strokeBorder(LocalsTheme.borderSubtle)
            )
        }
    }

    private var colorGrid: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Space.sm) {
            Eyebrow(text: "Colour")
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: DesignTokens.Space.sm), count: 4), spacing: DesignTokens.Space.sm) {
                ForEach(colors, id: \.self) { hex in
                    Button {
                        Haptics.tap()
                        color = hex
                    } label: {
                        Circle()
                            .fill(MerchantTheme.background(for: hex))
                            .frame(height: 64)
                            .overlay(
                                Circle().strokeBorder(
                                    color == hex ? LocalsTheme.fg : LocalsTheme.borderSubtle,
                                    lineWidth: color == hex ? 3 : 1
                                )
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var fontGrid: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Space.sm) {
            Eyebrow(text: "Font")
            VStack(spacing: DesignTokens.Space.sm) {
                ForEach(fonts, id: \.key) { f in
                    Button {
                        Haptics.tap()
                        font = f.key
                    } label: {
                        HStack {
                            Text(f.label)
                                .font(MerchantTheme.titleFont(for: f.key)(DesignTokens.Size.lg))
                                .foregroundStyle(LocalsTheme.fg)
                            Spacer()
                            if font == f.key {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(LocalsTheme.accent)
                            }
                        }
                        .padding(DesignTokens.Space.lg)
                        .background(LocalsTheme.bgElevated)
                        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.lg, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    @MainActor
    private func save() async {
        saving = true
        defer { saving = false }
        do {
            try await owners.updateTheme(merchantId: merchantId, color: color, font: font)
            Haptics.success()
        } catch {
            Haptics.warn()
            self.error = error.localizedDescription
        }
    }
}
