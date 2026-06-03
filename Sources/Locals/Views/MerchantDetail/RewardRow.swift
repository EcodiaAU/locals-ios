import SwiftUI

/// Informational reward row. Customers see what each business offers to
/// Locals users, then mention it at the counter. No code, no friction,
/// no extra POS step - businesses just honour what they have publicly
/// committed to and track conversions through their own register.
struct RewardRow: View {
    let reward: Reward
    let theme: MerchantTheme.Resolved

    var body: some View {
        HStack(spacing: DesignTokens.Space.md) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(reward.format)
                        .font(LocalsTheme.body(DesignTokens.Size.xs, weight: .semibold))
                        .tracking(1.2)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(theme.accent)
                        .foregroundStyle(LocalsTheme.onAccent)
                        .clipShape(Capsule())
                    if reward.is_first_visit == true {
                        Text("First visit")
                            .font(LocalsTheme.body(DesignTokens.Size.xs))
                            .foregroundStyle(theme.muted)
                    }
                }
                Text(reward.title)
                    .font(theme.bodyFont(DesignTokens.Size.lg))
                    .foregroundStyle(theme.foreground)
                if let d = reward.description, !d.isEmpty {
                    Text(d)
                        .font(theme.bodyFont(DesignTokens.Size.sm))
                        .foregroundStyle(theme.muted)
                        .lineLimit(3)
                }
            }
            Spacer()
        }
        .padding(DesignTokens.Space.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.foreground.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.lg, style: .continuous))
    }
}
