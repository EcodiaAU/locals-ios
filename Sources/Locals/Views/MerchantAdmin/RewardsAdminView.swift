import SwiftUI

struct RewardsAdminView: View {
    let merchantId: UUID
    @EnvironmentObject var rewards: RewardService

    @State private var all: [Reward] = []
    @State private var loading = false
    @State private var showCreate = false
    @State private var error: String?

    var body: some View {
        List {
            ForEach(all) { r in
                RewardAdminRow(reward: r) { newActive in
                    Task { await toggle(r, active: newActive) }
                }
                .listRowBackground(LocalsTheme.bg)
                .listRowSeparatorTint(LocalsTheme.borderSubtle)
                .swipeActions(edge: .trailing) {
                    Button(role: .destructive) {
                        Task { await delete(r) }
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(LocalsTheme.bg)
        .navigationTitle("Rewards")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showCreate = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .task { await reload() }
        .refreshable { await reload() }
        .sheet(isPresented: $showCreate, onDismiss: {
            Task { await reload() }
        }) {
            CreateRewardSheet(merchantId: merchantId)
        }
    }

    @MainActor
    private func reload() async {
        loading = true
        defer { loading = false }
        do { all = try await rewards.all(merchantId: merchantId) } catch {
            self.error = error.localizedDescription
        }
    }

    @MainActor
    private func toggle(_ r: Reward, active: Bool) async {
        do {
            try await rewards.setActive(r.id, active: active)
            await reload()
        } catch { self.error = error.localizedDescription }
    }

    @MainActor
    private func delete(_ r: Reward) async {
        do {
            try await rewards.delete(r.id)
            await reload()
        } catch { self.error = error.localizedDescription }
    }
}

struct RewardAdminRow: View {
    let reward: Reward
    let onToggle: (Bool) -> Void
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(reward.title).font(LocalsTheme.body(DesignTokens.Size.base, weight: .medium))
                Text(reward.format)
                    .font(LocalsTheme.body(DesignTokens.Size.xs))
                    .foregroundStyle(LocalsTheme.fgMuted)
            }
            Spacer()
            Toggle("", isOn: Binding(
                get: { reward.is_active ?? false },
                set: { onToggle($0) }
            ))
            .labelsHidden()
        }
        .padding(.vertical, DesignTokens.Space.xs)
    }
}

struct CreateRewardSheet: View {
    let merchantId: UUID
    @EnvironmentObject var rewards: RewardService
    @Environment(\.dismiss) private var dismiss

    @State private var title: String = ""
    @State private var description: String = ""
    @State private var rewardType: RewardType = .percent_off
    @State private var percent: String = "15"
    @State private var amountDollars: String = "5"
    @State private var maxPerUser: String = ""
    @State private var firstVisitOnly: Bool = false
    @State private var validUntil: Date = Date().addingTimeInterval(60 * 60 * 24 * 90)
    @State private var hasExpiry: Bool = false
    @State private var saving = false
    @State private var error: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("What you're offering") {
                    TextField("e.g. Free pastry with any coffee", text: $title)
                    TextField("Detail (optional)", text: $description, axis: .vertical)
                        .lineLimit(2...4)
                }
                Section("Type") {
                    Picker("Type", selection: $rewardType) {
                        ForEach(RewardType.allCases) { Text($0.label).tag($0) }
                    }
                    if rewardType == .percent_off {
                        TextField("Percent", text: $percent).keyboardType(.numberPad)
                    } else if rewardType == .amount_off {
                        TextField("Dollars", text: $amountDollars).keyboardType(.numberPad)
                    }
                }
                Section("Rules") {
                    TextField("Max per customer (blank = unlimited)", text: $maxPerUser)
                        .keyboardType(.numberPad)
                    Toggle("First visit only", isOn: $firstVisitOnly)
                    Toggle("Has an end date", isOn: $hasExpiry)
                    if hasExpiry {
                        DatePicker("Ends", selection: $validUntil, displayedComponents: [.date])
                    }
                }
                if let error {
                    Section { Text(error).foregroundStyle(.red) }
                }
            }
            .scrollContentBackground(.hidden)
            .background(LocalsTheme.bg)
            .navigationTitle("New reward")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task { await save() }
                    } label: {
                        if saving { ProgressView() } else { Text("Add") }
                    }
                    .disabled(saving || title.isEmpty)
                }
            }
        }
    }

    @MainActor
    private func save() async {
        saving = true
        defer { saving = false }
        let pct: Double? = rewardType == .percent_off ? Double(percent) : nil
        let amountCents: Int? = rewardType == .amount_off ? (Int(amountDollars).map { $0 * 100 }) : nil
        let maxPer: Int? = Int(maxPerUser)
        let draft = RewardService.Draft(
            merchant_id: merchantId,
            title: title,
            description: description.isEmpty ? nil : description,
            reward_type: rewardType.rawValue,
            value_pct: pct,
            value_amount_cents: amountCents,
            max_redemptions_per_user: maxPer,
            is_active: true,
            is_first_visit: firstVisitOnly,
            valid_until: hasExpiry ? validUntil : nil
        )
        do {
            _ = try await rewards.create(draft)
            Haptics.success()
            dismiss()
        } catch {
            Haptics.warn()
            self.error = error.localizedDescription
        }
    }
}
