import SwiftUI

/// Merchant counter screen. Staff types the customer's 6-character code,
/// hits Use, and the backend stamps the redemption consumed (+ logs which
/// staff_user_id consumed it).
struct ConsumeCodeView: View {
    let merchantId: UUID

    @EnvironmentObject var redemptions: RedemptionService

    @State private var code: String = ""
    @State private var result: ConsumedRedemption?
    @State private var error: String?
    @State private var inFlight = false

    var body: some View {
        ZStack {
            LocalsTheme.bg.ignoresSafeArea()
            VStack(spacing: DesignTokens.Space.xl) {
                Spacer().frame(height: DesignTokens.Space.lg)
                header

                if let result {
                    successCard(result)
                } else {
                    codeField
                    if let error {
                        Text(error)
                            .font(LocalsTheme.body(DesignTokens.Size.sm))
                            .foregroundStyle(.red)
                    }
                    useButton
                }

                Spacer()
            }
            .padding(DesignTokens.Space.lg)
        }
        .navigationTitle("Use a code")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Space.sm) {
            Eyebrow(text: "At the counter")
            Text("Type the customer's code.")
                .font(LocalsTheme.display(DesignTokens.Size.h2, italic: true))
                .foregroundStyle(LocalsTheme.fg)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var codeField: some View {
        VStack(spacing: DesignTokens.Space.sm) {
            TextField("ABC123", text: $code)
                .font(.system(size: 56, weight: .bold, design: .monospaced))
                .tracking(8)
                .multilineTextAlignment(.center)
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled()
                .keyboardType(.asciiCapable)
                .padding(DesignTokens.Space.lg)
                .frame(maxWidth: .infinity)
                .background(LocalsTheme.bgElevated)
                .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.xl, style: .continuous))
                .onChange(of: code) { _, new in
                    let filtered = new.uppercased().filter { $0.isLetter || $0.isNumber }
                    code = String(filtered.prefix(6))
                }
            Text("Six characters. Letters or digits.")
                .font(LocalsTheme.body(DesignTokens.Size.xs))
                .foregroundStyle(LocalsTheme.fgMuted)
        }
    }

    private var useButton: some View {
        Button {
            Task { await consume() }
        } label: {
            if inFlight { ProgressView().tint(LocalsTheme.onAccent) }
            else { Text("Use code") }
        }
        .buttonStyle(.localsPrimary)
        .disabled(inFlight || code.count != 6)
    }

    private func successCard(_ result: ConsumedRedemption) -> some View {
        VStack(spacing: DesignTokens.Space.lg) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(LocalsTheme.accent)
            Text("Used")
                .font(LocalsTheme.display(DesignTokens.Size.h1, italic: true))
                .foregroundStyle(LocalsTheme.fg)
            VStack(spacing: 4) {
                Text(result.reward_title)
                    .font(LocalsTheme.body(DesignTokens.Size.lg, weight: .semibold))
                Text(result.reward_format)
                    .font(LocalsTheme.body(DesignTokens.Size.sm))
                    .foregroundStyle(LocalsTheme.fgMuted)
            }
            Button {
                code = ""
                self.result = nil
                error = nil
            } label: { Text("Next code") }
                .buttonStyle(.localsPrimary)
                .padding(.top, DesignTokens.Space.lg)
        }
        .padding(DesignTokens.Space.xl)
        .frame(maxWidth: .infinity)
        .background(LocalsTheme.bgElevated)
        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.xl, style: .continuous))
    }

    @MainActor
    private func consume() async {
        inFlight = true
        defer { inFlight = false }
        Haptics.tap(.medium)
        do {
            let consumed = try await redemptions.consume(code: code, merchantId: merchantId)
            Haptics.success()
            result = consumed
            error = nil
        } catch {
            Haptics.error()
            self.error = error.localsHumanMessage
        }
    }
}
