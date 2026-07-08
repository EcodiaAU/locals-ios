import SwiftUI

/// The entitled Local Guide chat. Posts each turn to the deployed `local-guide`
/// edge function (Friend-grounded), rendered in the Locals serif register.
/// Only reached when the user is Friend-connected AND holds the `friend`
/// entitlement (Friend-IAP wave 3).
struct GuideChatView: View {
    @EnvironmentObject var auth: AuthService

    @State private var input = ""
    @State private var messages: [GuideMessage] = []
    @State private var sending = false

    private let examples = [
        "A good local coffee spot?",
        "Somewhere local for dinner tonight",
        "Where can I take the kids this weekend?",
    ]

    var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: DesignTokens.Space.md) {
                        if messages.isEmpty {
                            emptyState
                        }
                        ForEach(messages) { msg in
                            bubble(msg).id(msg.id)
                        }
                        if sending {
                            HStack(spacing: DesignTokens.Space.xs) {
                                ProgressView().controlSize(.small)
                                Text("thinking…")
                                    .font(LocalsTheme.serif(15, italic: true))
                                    .foregroundStyle(LocalsTheme.fgMuted)
                            }
                            .padding(.horizontal, DesignTokens.Space.lg)
                        }
                    }
                    .padding(.vertical, DesignTokens.Space.lg)
                }
                .onChange(of: messages.count) { _, _ in
                    if let last = messages.last {
                        withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                    }
                }
            }

            inputBar
        }
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Space.md) {
            Text("Ask your local guide")
                .font(LocalsTheme.display(24))
                .foregroundStyle(LocalsTheme.fg)
            ForEach(examples, id: \.self) { ex in
                Button {
                    input = ex
                    Task { await send() }
                } label: {
                    Text(ex)
                        .font(LocalsTheme.serif(16))
                        .foregroundStyle(LocalsTheme.accent)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(DesignTokens.Space.md)
                        .background(LocalsTheme.bgSubtle)
                        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.lg, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, DesignTokens.Space.lg)
    }

    private func bubble(_ msg: GuideMessage) -> some View {
        HStack {
            if msg.fromUser { Spacer(minLength: DesignTokens.Space._12) }
            Text(msg.text)
                .font(msg.fromUser ? LocalsTheme.body(DesignTokens.Size.base) : LocalsTheme.serif(17))
                .foregroundStyle(msg.fromUser ? LocalsTheme.onAccent : LocalsTheme.fg)
                .padding(DesignTokens.Space.md)
                .background(msg.fromUser ? LocalsTheme.accent : LocalsTheme.bgElevated)
                .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.lg, style: .continuous))
            if !msg.fromUser { Spacer(minLength: DesignTokens.Space._12) }
        }
        .padding(.horizontal, DesignTokens.Space.lg)
    }

    private var inputBar: some View {
        HStack(spacing: DesignTokens.Space.sm) {
            TextField("Ask about where you are…", text: $input, axis: .vertical)
                .font(LocalsTheme.serif(16))
                .textFieldStyle(.plain)
                .lineLimit(1...4)
                .padding(.horizontal, DesignTokens.Space.md)
                .padding(.vertical, DesignTokens.Space.sm)
                .background(LocalsTheme.bgSubtle)
                .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.xl, style: .continuous))
                .onSubmit { Task { await send() } }

            Button {
                Task { await send() }
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 30))
                    .foregroundStyle(canSend ? LocalsTheme.accent : LocalsTheme.fgTrace)
            }
            .disabled(!canSend)
        }
        .padding(DesignTokens.Space.md)
        .background(LocalsTheme.bg)
    }

    private var canSend: Bool {
        !input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !sending
    }

    private func send() async {
        let text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !sending else { return }
        input = ""
        messages.append(GuideMessage(text: text, fromUser: true))
        sending = true
        defer { sending = false }
        let token = await auth.accessToken()
        let reply = await LocalGuideService.ask(text, accessToken: token)
        let body = reply.reply ?? "I could not reach your guide just then. Give it another go in a moment."
        messages.append(GuideMessage(text: body, fromUser: false))
    }
}

struct GuideMessage: Identifiable {
    let id = UUID()
    let text: String
    let fromUser: Bool
}
