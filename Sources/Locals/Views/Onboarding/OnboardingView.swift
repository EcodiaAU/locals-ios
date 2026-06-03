import SwiftUI

/// First-run onboarding. Three slides + a "Get started" call-to-action.
/// Closely mirrors the locals-web landing voice: editorial sentence,
/// no marketing-bingo, sub-line that explains the customers-free /
/// merchants-pay-what-you-want shape in plain words.
struct OnboardingView: View {
    @EnvironmentObject var session: AppSession
    @EnvironmentObject var location: LocationManager
    @State private var page: Int = 0

    private let slides: [Slide] = [
        Slide(
            eyebrow: "A national network",
            title: "Choose the local option,\nmade easy.",
            body: "Locals shows the independent businesses near you, the ones that signed up themselves. You get a small reward at each one for choosing them over the chain."
        ),
        Slide(
            eyebrow: "Customers free, always",
            title: "Nothing to pay,\nno data sold.",
            body: "Browse, save, redeem. We never sell your data and never up-charge you. Merchants pay what they want each month to be listed."
        ),
        Slide(
            eyebrow: "List your business",
            title: "Pay what you can.\nKeep what works.",
            body: "If you run an independent business, add yours in a minute, pick what you pay each month, and cancel any time. We send customers your way, you decide what they get."
        )
    ]

    var body: some View {
        ZStack {
            LocalsTheme.bg.ignoresSafeArea()

            VStack(spacing: 0) {
                TabView(selection: $page) {
                    ForEach(slides.indices, id: \.self) { i in
                        slideView(slides[i]).tag(i)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .frame(maxWidth: .infinity)

                indicator
                    .padding(.bottom, DesignTokens.Space.xl)

                VStack(spacing: DesignTokens.Space.md) {
                    Button {
                        location.requestPermissionIfNeeded()
                        session.hasOnboarded = true
                    } label: {
                        Text(page == slides.count - 1 ? "Get started" : "Skip")
                    }
                    .buttonStyle(.localsPrimary)

                    if page < slides.count - 1 {
                        Button {
                            withAnimation { page += 1 }
                        } label: {
                            Text("Next")
                        }
                        .buttonStyle(.localsSecondary)
                    }
                }
                .padding(.horizontal, DesignTokens.Space.lg)
                .padding(.bottom, DesignTokens.Space.xl)
            }
        }
    }

    private func slideView(_ slide: Slide) -> some View {
        VStack(alignment: .leading, spacing: DesignTokens.Space.lg) {
            Spacer()
            Eyebrow(text: slide.eyebrow)
            Text(slide.title)
                .font(LocalsTheme.display(DesignTokens.Size.h1, italic: true))
                .foregroundStyle(LocalsTheme.fg)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
            Text(slide.body)
                .font(LocalsTheme.body(DesignTokens.Size.lg))
                .foregroundStyle(LocalsTheme.fgMuted)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
            Spacer()
        }
        .padding(.horizontal, DesignTokens.Space.xl)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var indicator: some View {
        HStack(spacing: 6) {
            ForEach(slides.indices, id: \.self) { i in
                Capsule()
                    .fill(i == page ? LocalsTheme.accent : LocalsTheme.borderSubtle)
                    .frame(width: i == page ? 24 : 6, height: 6)
                    .animation(.easeInOut(duration: DesignTokens.Motion.base), value: page)
            }
        }
    }

    private struct Slide: Identifiable {
        let id = UUID()
        let eyebrow: String
        let title: String
        let body: String
    }
}
