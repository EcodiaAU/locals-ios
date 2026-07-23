import Foundation
import RevenueCat

/// RevenueCat wrapper for the Friend "A little" subscription on native Locals.
///
/// Friend-IAP wave 3 (2026-07-08). Ports the glovebox `tripGate.ts` purchase
/// flow to the native RevenueCat Swift SDK. Owns SDK configuration, Friend-keyed
/// `logIn`, offering/price load, purchase + restore, and maps the SDK's
/// `CustomerInfo` into the SDK-free `EntitlementSnapshot` that
/// `FriendPurchaseResolver` evaluates.
///
/// The paywall buys the `default` offering's `$rc_monthly` package (product
/// `friend_a_little_monthly_locals` on iOS), NOT a web checkout - upgrades to
/// higher tiers happen on Friend WEB only, and this never touches Stripe.
@MainActor
final class FriendPurchases: ObservableObject {
    /// True when the on-device RevenueCat `friend` entitlement is active. This is
    /// the authoritative StoreKit-bound signal the Local Guide gate reads.
    @Published private(set) var isEntitled = false
    /// Localized store price (e.g. "A$29.99"), loaded from the offering. Nil until
    /// the offering resolves (needs the store product synced to RevenueCat).
    @Published private(set) var localizedPrice: String?
    /// True once RevenueCat is configured and the offering fetch has completed
    /// (successfully or not), so the paywall can stop showing a spinner.
    @Published private(set) var offeringResolved = false
    /// Set when a purchase/restore reports an error worth surfacing.
    @Published var lastError: String?

    private var configured = false
    private var currentAppUserID: String?

    /// The value the paywall shows: the resolved store price if available, else
    /// the fixed A$29.99 copy so the sheet is never blank while the offering loads.
    var displayPrice: String {
        localizedPrice ?? "A$29.99"
    }

    // MARK: - Configuration

    /// Configure RevenueCat with the platform public SDK key. No-op if the key is
    /// empty (a fresh clone without `LOCALS_REVENUECAT_IOS_KEY` baked) so the app
    /// still builds and runs - the guide simply stays gated until a key is present.
    func configure(apiKey: String) {
        guard !configured, !apiKey.isEmpty else { return }
        Purchases.logLevel = .error
        Purchases.configure(withAPIKey: apiKey)
        configured = true
    }

    var isConfigured: Bool { configured }

    /// Identify RevenueCat with the canonical Friend account id (falling back to
    /// the local user id) so the reconciler keys the central subscription row on
    /// the same identity. Safe to call repeatedly / on every auth change - RC
    /// aliases when the id upgrades from local -> friend.
    func logIn(friendID: String?, localUserID: String?) async {
        guard configured else { return }
        guard let appUserID = FriendPurchaseResolver.appUserID(friendID: friendID, localUserID: localUserID) else { return }
        if appUserID == currentAppUserID { return }
        currentAppUserID = appUserID
        do {
            let (info, _) = try await Purchases.shared.logIn(appUserID)
            applyCustomerInfo(info)
        } catch {
            // Non-fatal: entitlement stays as last known; refresh() retries.
        }
    }

    // MARK: - Entitlement refresh

    /// Pull the latest CustomerInfo and recompute `isEntitled`. Call on foreground
    /// and after a purchase/restore.
    func refresh() async {
        guard configured else { return }
        do {
            let info = try await Purchases.shared.customerInfo()
            applyCustomerInfo(info)
        } catch {
            // leave last-known entitlement in place
        }
    }

    private func applyCustomerInfo(_ info: CustomerInfo) {
        let result = FriendPurchaseResolver.resolveUnlock(Self.snapshot(from: info))
        isEntitled = result.unlocked
    }

    /// Map RevenueCat's `CustomerInfo` into the SDK-free snapshot the resolver reads.
    static func snapshot(from info: CustomerInfo) -> EntitlementSnapshot {
        EntitlementSnapshot(
            activeEntitlements: Set(info.entitlements.active.keys),
            activeSubscriptions: Array(info.activeSubscriptions),
            allPurchasedProductIDs: Array(info.allPurchasedProductIdentifiers),
            nonSubscriptionProductIDs: info.nonSubscriptions.map { $0.productIdentifier }
        )
    }

    // MARK: - Offering / price

    /// Load the `default` offering and cache the localized price of the Friend
    /// package. Marks `offeringResolved` regardless of outcome so the paywall UI
    /// settles.
    func loadOffering() async {
        guard configured else { offeringResolved = true; return }
        defer { offeringResolved = true }
        do {
            let offerings = try await Purchases.shared.offerings()
            if let pkg = friendPackage(in: offerings) {
                localizedPrice = pkg.storeProduct.localizedPriceString
            }
        } catch {
            // price falls back to displayPrice's A$29.99 copy
        }
    }

    private func friendPackage(in offerings: Offerings) -> Package? {
        let offering = offerings.all[FriendPlan.offeringID] ?? offerings.current
        return offering?.availablePackages.first(where: {
            $0.storeProduct.productIdentifier == FriendPlan.iosProductID
        }) ?? offering?.availablePackages.first
    }

    // MARK: - Purchase / restore

    /// Present the native purchase sheet for the Friend package. Returns true on a
    /// completed, entitlement-confirmed purchase. Prefers the offering package
    /// (server-side pricing/eligibility); falls back to a direct store-product
    /// purchase if the offering is unavailable.
    @discardableResult
    func purchase() async -> Bool {
        guard configured else { lastError = "Payment service is still loading. Please try again."; return false }
        do {
            let offerings = try await Purchases.shared.offerings()
            if let pkg = friendPackage(in: offerings) {
                let result = try await Purchases.shared.purchase(package: pkg)
                if result.userCancelled { return false }
                applyCustomerInfo(result.customerInfo)
                return isEntitled
            }
            // Fallback: direct store product.
            let products = await Purchases.shared.products([FriendPlan.iosProductID])
            guard let product = products.first else {
                lastError = "Product not available. Check your connection and try again."
                return false
            }
            let result = try await Purchases.shared.purchase(product: product)
            if result.userCancelled { return false }
            applyCustomerInfo(result.customerInfo)
            return isEntitled
        } catch {
            if let rcError = error as? RevenueCat.ErrorCode, rcError == .purchaseCancelledError { return false }
            lastError = (error as NSError).localizedDescription
            return false
        }
    }

    /// Restore prior purchases (App Store account level).
    @discardableResult
    func restore() async -> Bool {
        guard configured else { return false }
        do {
            let info = try await Purchases.shared.restorePurchases()
            applyCustomerInfo(info)
            if !isEntitled { lastError = "No previous purchase found." }
            return isEntitled
        } catch {
            lastError = (error as NSError).localizedDescription
            return false
        }
    }
}
