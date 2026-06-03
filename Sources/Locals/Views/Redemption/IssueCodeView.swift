import SwiftUI

/// The "show this to staff" screen. 5-minute countdown + the big legible
/// code + the reward name. Keeps the screen awake while it's open so the
/// customer can hand the phone to the counter without it locking.
struct IssueCodeView: View {
    let issued: IssuedRedemption
    let theme: MerchantTheme.Resolved

    @Environment(\.dismiss) private var dismiss
    @State private var now: Date = Date()
    private let tick = Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()

    private var remaining: TimeInterval {
        max(0, issued.expires_at.timeIntervalSince(now))
    }

    private var expired: Bool { remaining <= 0 }

    private var countdownLabel: String {
        let total = Int(remaining.rounded())
        let m = total / 60
        let s = total % 60
        return String(format: "%01d:%02d", m, s)
    }

    var body: some View {
        ZStack {
            theme.background.ignoresSafeArea()
            VStack(spacing: DesignTokens.Space.xl) {
                Spacer()
                VStack(spacing: DesignTokens.Space.lg) {
                    Eyebrow(text: "Show this at the counter")
                    Text(issued.reward_title)
                        .font(theme.titleFont(DesignTokens.Size.h2))
                        .foregroundStyle(theme.foreground)
                        .multilineTextAlignment(.center)
                    Text(issued.reward_format)
                        .font(LocalsTheme.body(DesignTokens.Size.sm, weight: .semibold))
                        .tracking(2)
                        .foregroundStyle(theme.muted)
                }

                Text(issued.prettyCode)
                    .font(.system(size: 64, weight: .bold, design: .monospaced))
                    .tracking(8)
                    .foregroundStyle(expired ? theme.muted : theme.foreground)
                    .padding(.horizontal, DesignTokens.Space.xl)
                    .padding(.vertical, DesignTokens.Space.lg)
                    .frame(maxWidth: .infinity)
                    .background(theme.foreground.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.xl, style: .continuous))

                VStack(spacing: 4) {
                    Text(expired ? "Expired" : "Expires in")
                        .font(LocalsTheme.body(DesignTokens.Size.sm))
                        .foregroundStyle(theme.muted)
                    Text(countdownLabel)
                        .font(.system(size: 36, weight: .semibold, design: .monospaced))
                        .foregroundStyle(expired ? .red : theme.foreground)
                }

                Spacer()

                Button {
                    dismiss()
                } label: {
                    Text("Done")
                }
                .buttonStyle(.localsPrimary(fill: theme.foreground, foreground: theme.background))
                .padding(.horizontal, DesignTokens.Space.lg)
            }
            .padding(.vertical, DesignTokens.Space.xl)
        }
        .onAppear {
            UIApplication.shared.isIdleTimerDisabled = true
            UIScreen.main.brightness = max(UIScreen.main.brightness, 0.7)
        }
        .onDisappear {
            UIApplication.shared.isIdleTimerDisabled = false
        }
        .onReceive(tick) { now = $0 }
    }
}
