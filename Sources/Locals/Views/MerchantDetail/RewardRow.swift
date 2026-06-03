import SwiftUI

struct RewardRow: View {
    let reward: Reward
    let theme: MerchantTheme.Resolved
    let onRedeem: () -> Void

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
                        .lineLimit(2)
                }
            }
            Spacer()
            Button(action: onRedeem) {
                Text("Get code")
                    .font(LocalsTheme.body(DesignTokens.Size.sm, weight: .semibold))
                    .padding(.horizontal, DesignTokens.Space.lg)
                    .padding(.vertical, DesignTokens.Space.sm)
                    .background(theme.foreground)
                    .foregroundStyle(theme.background)
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(DesignTokens.Space.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.foreground.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.lg, style: .continuous))
    }
}
