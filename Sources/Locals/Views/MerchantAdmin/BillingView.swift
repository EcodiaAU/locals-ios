import SwiftUI

/// Merchant billing. Pay-what-you-want monthly subscription. We open
/// Stripe Checkout in SFSafariViewController - Apple's 2024 external-
/// purchase pattern for merchant-side B2B services. The customer side
/// of the app is always free; only merchants ever land here.
struct BillingView: View {
    let merchantId: UUID

    @EnvironmentObject var owners: OwnerMerchantService
    @EnvironmentObject var billing: BillingService

    @State private var subscription: MerchantSubscription?
    @State private var amountDollars: String = "20"
    @State private var checkoutURL: URL?
    @State private var inFlight = false
    @State private var error: String?
    @State private var loading = true
    @State private var showCancelConfirm = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignTokens.Space.xxl) {
                header
                if loading {
                    ProgressView().padding(DesignTokens.Space.xl)
                } else if let sub = subscription, sub.isActive {
                    activeBlock(sub)
                } else {
                    payBlock
                }
                explainerBlock
                if let error {
                    Text(error)
                        .font(LocalsTheme.body(DesignTokens.Size.sm))
                        .foregroundStyle(.red)
                }
            }
            .padding(DesignTokens.Space.lg)
        }
        .background(LocalsTheme.bg)
        .navigationTitle("Billing")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
        .refreshable { await load() }
        .sheet(item: Binding(
            get: { checkoutURL.map(IdentifiedURL.init) },
            set: { if $0 == nil { checkoutURL = nil; Task { await load() } } }
        )) { wrapped in
            SafariView(url: wrapped.url)
        }
        .confirmationDialog(
            "Cancel at end of period?",
            isPresented: $showCancelConfirm
        ) {
            Button("Cancel subscription", role: .destructive) {
                Task { await cancelSub() }
            }
            Button("Keep it", role: .cancel) {}
        } message: {
            Text("Your listing stays active until the end of the current period, then stops.")
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Space.sm) {
            Eyebrow(text: "Listing subscription")
            Text("Pay what you can,\ncancel any time.")
                .font(LocalsTheme.display(DesignTokens.Size.h2, italic: true))
                .foregroundStyle(LocalsTheme.fg)
        }
    }

    private var payBlock: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Space.lg) {
            Eyebrow(text: "Your monthly")
            HStack(alignment: .firstTextBaseline) {
                Text("$")
                    .font(LocalsTheme.serif(DesignTokens.Size.h2, italic: true))
                TextField("20", text: $amountDollars)
                    .font(LocalsTheme.serif(DesignTokens.Size.hero, italic: true))
                    .keyboardType(.numberPad)
                Text("AUD")
                    .font(LocalsTheme.body(DesignTokens.Size.sm))
                    .foregroundStyle(LocalsTheme.fgMuted)
            }
            .padding(DesignTokens.Space.lg)
            .background(LocalsTheme.bgElevated)
            .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.lg, style: .continuous))

            quickPickRow

            Button {
                Task { await startCheckout() }
            } label: {
                if inFlight { ProgressView().tint(LocalsTheme.onAccent) }
                else { Text("Start subscription") }
            }
            .buttonStyle(.localsPrimary)
            .disabled(inFlight || (Int(amountDollars) ?? 0) < 1)

            Text("Opens Stripe Checkout. You'll come back here when you're done.")
                .font(LocalsTheme.body(DesignTokens.Size.xs))
                .foregroundStyle(LocalsTheme.fgMuted)
        }
    }

    private var quickPickRow: some View {
        HStack(spacing: DesignTokens.Space.sm) {
            ForEach([5, 10, 20, 50, 100], id: \.self) { v in
                Button {
                    Haptics.tap()
                    amountDollars = "\(v)"
                } label: {
                    Text("$\(v)")
                        .font(LocalsTheme.body(DesignTokens.Size.sm, weight: .medium))
                        .padding(.horizontal, DesignTokens.Space.md)
                        .padding(.vertical, DesignTokens.Space.sm)
                        .background(amountDollars == "\(v)" ? LocalsTheme.fg : LocalsTheme.bgElevated)
                        .foregroundStyle(amountDollars == "\(v)" ? LocalsTheme.bg : LocalsTheme.fg)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func activeBlock(_ sub: MerchantSubscription) -> some View {
        VStack(alignment: .leading, spacing: DesignTokens.Space.lg) {
            Eyebrow(text: "Current subscription")
            HStack(alignment: .firstTextBaseline) {
                Text("$\(Int(sub.amountDollars))")
                    .font(LocalsTheme.serif(DesignTokens.Size.hero, italic: true))
                Text("/ month")
                    .font(LocalsTheme.body(DesignTokens.Size.sm))
                    .foregroundStyle(LocalsTheme.fgMuted)
            }
            if let when = sub.current_period_end {
                Text("Next charge: \(when, format: .dateTime.month().day().year())")
                    .font(LocalsTheme.body(DesignTokens.Size.sm))
                    .foregroundStyle(LocalsTheme.fgMuted)
            }
            if sub.cancel_at != nil {
                Text("Set to cancel at the end of this period.")
                    .font(LocalsTheme.body(DesignTokens.Size.sm))
                    .foregroundStyle(.orange)
            }
            HStack(spacing: DesignTokens.Space.sm) {
                Button {
                    Task { await startCheckout() }
                } label: { Text("Change amount") }
                .buttonStyle(.localsSecondary)
                Button(role: .destructive) {
                    showCancelConfirm = true
                } label: { Text("Cancel") }
                .buttonStyle(.localsSecondary)
            }
        }
        .padding(DesignTokens.Space.lg)
        .background(LocalsTheme.bgElevated)
        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.lg, style: .continuous))
    }

    private var explainerBlock: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Space.sm) {
            Eyebrow(text: "How this works")
            Text("Locals shows your business to customers free of charge to them. Merchants choose what they pay each month - $5, $50, more if you want. We never up-charge customers or take a cut of what they buy from you.")
                .font(LocalsTheme.body(DesignTokens.Size.sm))
                .foregroundStyle(LocalsTheme.fgMuted)
                .lineSpacing(3)
            Text("Stripe handles payment. You can cancel or change the amount any time.")
                .font(LocalsTheme.body(DesignTokens.Size.sm))
                .foregroundStyle(LocalsTheme.fgMuted)
        }
    }

    @MainActor
    private func load() async {
        loading = true
        defer { loading = false }
        do {
            subscription = try await owners.subscription(merchantId: merchantId)
            if let cents = subscription?.amount_cents_monthly {
                amountDollars = "\(cents / 100)"
            }
        } catch {
            self.error = error.localizedDescription
        }
    }

    @MainActor
    private func startCheckout() async {
        guard let dollars = Int(amountDollars), dollars >= 1 else { return }
        inFlight = true
        defer { inFlight = false }
        do {
            let url = try await billing.checkout(merchantId: merchantId, amountCents: dollars * 100)
            checkoutURL = url
        } catch {
            self.error = error.localizedDescription
        }
    }

    @MainActor
    private func cancelSub() async {
        inFlight = true
        defer { inFlight = false }
        do {
            try await billing.cancel(merchantId: merchantId)
            Haptics.success()
            await load()
        } catch {
            Haptics.warn()
            self.error = error.localizedDescription
        }
    }
}

private struct IdentifiedURL: Identifiable {
    let url: URL
    var id: String { url.absoluteString }
}
