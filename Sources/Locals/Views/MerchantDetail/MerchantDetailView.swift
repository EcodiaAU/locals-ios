import SwiftUI

/// The merchant detail surface. Renders in the merchant's chosen theme -
/// full-bleed background, headline in their font, rewards inheriting the
/// theme accent. Native iOS bits: ShareLink, scroll-edge title fade,
/// pull-to-refresh, haptics on favourite toggle.
struct MerchantDetailView: View {
    let slug: String

    @EnvironmentObject var merchants: MerchantService
    @EnvironmentObject var rewards: RewardService
    @EnvironmentObject var favorites: FavoriteService

    @State private var merchant: Merchant?
    @State private var photos: [MerchantPhoto] = []
    @State private var liveRewards: [Reward] = []
    @State private var signals: [SustainabilitySignal] = []
    @State private var error: String?

    private var theme: MerchantTheme.Resolved {
        MerchantTheme.resolve(color: merchant?.theme_color, font: merchant?.theme_font)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignTokens.Space.xxl) {
                hero
                aboutBlock
                ownerNote
                rewardsBlock
                hoursBlock
                photosBlock
                sustainabilityBlock
                contactBlock
                footer
            }
            .padding(.top, DesignTokens.Space.lg)
            .padding(.bottom, DesignTokens.Space.huge)
        }
        .background(theme.background.ignoresSafeArea())
        .foregroundStyle(theme.foreground)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text(merchant?.name ?? "")
                    .font(LocalsTheme.body(DesignTokens.Size.sm, weight: .medium))
                    .foregroundStyle(theme.foreground)
            }
            ToolbarItem(placement: .topBarTrailing) {
                if let m = merchant {
                    HStack(spacing: DesignTokens.Space.sm) {
                        Button {
                            Haptics.tap()
                            favorites.toggle(from: m)
                        } label: {
                            Image(systemName: favorites.isFavorite(m.id) ? "heart.fill" : "heart")
                                .foregroundStyle(theme.foreground)
                        }
                        ShareLink(item: URL(string: "https://locals.ecodia.au/\(m.slug)") ?? URL(string: "https://locals.ecodia.au")!) {
                            Image(systemName: "square.and.arrow.up")
                                .foregroundStyle(theme.foreground)
                        }
                    }
                }
            }
        }
        .task { await loadAll() }
        .refreshable { await loadAll() }
    }

    @ViewBuilder
    private var hero: some View {
        if let m = merchant {
            VStack(alignment: .leading, spacing: DesignTokens.Space.lg) {
                Eyebrow(text: m.resolvedCategory.label)
                Text(m.name)
                    .font(theme.titleFont(DesignTokens.Size.hero))
                    .foregroundStyle(theme.foreground)
                    .lineSpacing(-4)
                    .fixedSize(horizontal: false, vertical: true)
                if let addr = m.address {
                    Text(addr)
                        .font(theme.bodyFont(DesignTokens.Size.base))
                        .foregroundStyle(theme.muted)
                }
            }
            .padding(.horizontal, DesignTokens.Space.lg)
        }
    }

    @ViewBuilder
    private var aboutBlock: some View {
        if let m = merchant, let story = m.story, !story.isEmpty {
            VStack(alignment: .leading, spacing: DesignTokens.Space.sm) {
                Eyebrow(text: "About")
                Text(story)
                    .font(theme.bodyFont(DesignTokens.Size.lg))
                    .foregroundStyle(theme.foreground)
                    .fixedSize(horizontal: false, vertical: true)
                    .lineSpacing(4)
            }
            .padding(.horizontal, DesignTokens.Space.lg)
        }
    }

    @ViewBuilder
    private var ownerNote: some View {
        if let m = merchant, let note = m.owner_note, !note.isEmpty {
            VStack(alignment: .leading, spacing: DesignTokens.Space.sm) {
                HStack {
                    Eyebrow(text: "Note from the owner")
                    Spacer()
                    if let when = m.owner_note_at {
                        Text(when, format: .relative(presentation: .named))
                            .font(LocalsTheme.body(DesignTokens.Size.xs))
                            .foregroundStyle(theme.muted)
                    }
                }
                Text(note)
                    .font(theme.bodyFont(DesignTokens.Size.base))
                    .italic()
                    .foregroundStyle(theme.foreground)
                    .padding(DesignTokens.Space.lg)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(theme.foreground.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.lg, style: .continuous))
            }
            .padding(.horizontal, DesignTokens.Space.lg)
        }
    }

    @ViewBuilder
    private var rewardsBlock: some View {
        if !liveRewards.isEmpty {
            VStack(alignment: .leading, spacing: DesignTokens.Space.md) {
                Eyebrow(text: "What they offer")
                VStack(spacing: DesignTokens.Space.sm) {
                    ForEach(liveRewards) { r in
                        RewardRow(reward: r, theme: theme)
                    }
                }
                Text("Mention Locals at the counter.")
                    .font(LocalsTheme.body(DesignTokens.Size.xs))
                    .foregroundStyle(theme.muted)
            }
            .padding(.horizontal, DesignTokens.Space.lg)
        }
    }

    @ViewBuilder
    private var hoursBlock: some View {
        if let m = merchant, let hours = m.hours, !hours.isEmpty {
            VStack(alignment: .leading, spacing: DesignTokens.Space.sm) {
                Eyebrow(text: "Hours")
                VStack(spacing: DesignTokens.Space.xs) {
                    ForEach(orderedDays(hours), id: \.0) { day, value in
                        HStack {
                            Text(day.capitalized)
                                .font(theme.bodyFont(DesignTokens.Size.base))
                            Spacer()
                            Text(value)
                                .font(theme.bodyFont(DesignTokens.Size.base))
                                .foregroundStyle(theme.muted)
                        }
                    }
                }
            }
            .padding(.horizontal, DesignTokens.Space.lg)
        }
    }

    @ViewBuilder
    private var photosBlock: some View {
        if !photos.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: DesignTokens.Space.sm) {
                    ForEach(photos) { p in
                        RemoteImage(url: merchants.photoURL(p.storage_path))
                            .frame(width: 280, height: 180)
                            .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.lg, style: .continuous))
                    }
                }
                .padding(.horizontal, DesignTokens.Space.lg)
            }
        }
    }

    @ViewBuilder
    private var sustainabilityBlock: some View {
        if let m = merchant, !m.tags.isEmpty {
            VStack(alignment: .leading, spacing: DesignTokens.Space.md) {
                Eyebrow(text: "What they say")
                FlowLayout(spacing: 8) {
                    ForEach(m.tags, id: \.rawValue) { tag in
                        let pct = signals.first(where: { $0.tag == tag.rawValue })?.percentLabel
                        HStack(spacing: 4) {
                            Text(tag.label)
                            if let pct {
                                Text("· \(pct) confirm")
                                    .foregroundStyle(theme.muted)
                            }
                        }
                        .font(LocalsTheme.body(DesignTokens.Size.sm))
                        .padding(.horizontal, DesignTokens.Space.md)
                        .padding(.vertical, 6)
                        .background(theme.foreground.opacity(0.06))
                        .clipShape(Capsule())
                    }
                }
            }
            .padding(.horizontal, DesignTokens.Space.lg)
        }
    }

    @ViewBuilder
    private var contactBlock: some View {
        if let m = merchant, let c = m.contact, hasAnyContact(c) {
            VStack(alignment: .leading, spacing: DesignTokens.Space.sm) {
                Eyebrow(text: "Find them")
                if let phone = c.phone, let url = URL(string: "tel:\(phone)") {
                    Link(phone, destination: url)
                }
                if let email = c.email, let url = URL(string: "mailto:\(email)") {
                    Link(email, destination: url)
                }
                if let ig = c.instagram, let url = URL(string: "https://instagram.com/\(ig.replacingOccurrences(of: "@", with: ""))") {
                    Link("@\(ig.replacingOccurrences(of: "@", with: ""))", destination: url)
                }
                if let web = c.website, let url = URL(string: web) {
                    Link(web, destination: url)
                }
            }
            .font(theme.bodyFont(DesignTokens.Size.base))
            .padding(.horizontal, DesignTokens.Space.lg)
        }
    }

    private var footer: some View {
        VStack(spacing: 4) {
            Text("Locals")
                .font(LocalsTheme.serif(DesignTokens.Size.sm, italic: true))
                .foregroundStyle(theme.muted)
            Text("Want to add yours? · locals.ecodia.au")
                .font(LocalsTheme.body(DesignTokens.Size.xs))
                .foregroundStyle(theme.muted)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, DesignTokens.Space.huge)
    }

    private func hasAnyContact(_ c: Merchant.ContactInfo) -> Bool {
        c.phone != nil || c.email != nil || c.instagram != nil || c.website != nil
    }

    private func orderedDays(_ hours: [String: String]) -> [(String, String)] {
        let order = ["mon", "tue", "wed", "thu", "fri", "sat", "sun"]
        return order.compactMap { day in
            guard let v = hours[day] else { return nil }
            return (day, v)
        }
    }

    @MainActor
    private func loadAll() async {
        do {
            let m = try await merchants.detailBySlug(slug)
            self.merchant = m
            async let photos = merchants.photos(merchantId: m.id)
            async let rewardsRows = rewards.live(merchantId: m.id)
            async let signal = merchants.sustainabilitySignal(merchantId: m.id)
            self.photos = try await photos
            self.liveRewards = try await rewardsRows
            self.signals = (try? await signal) ?? []
        } catch {
            self.error = error.localizedDescription
        }
    }

}

// Simple horizontal flowing stack for the sustainability tags. Native iOS 17
// Layout protocol - shapes around the available width.
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var rowWidth: CGFloat = 0
        var rowHeight: CGFloat = 0
        var totalHeight: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if rowWidth + size.width + spacing > maxWidth {
                totalHeight += rowHeight + spacing
                rowWidth = size.width + spacing
                rowHeight = size.height
            } else {
                rowWidth += size.width + spacing
                rowHeight = max(rowHeight, size.height)
            }
        }
        totalHeight += rowHeight
        return CGSize(width: maxWidth.isFinite ? maxWidth : rowWidth, height: totalHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            view.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}
