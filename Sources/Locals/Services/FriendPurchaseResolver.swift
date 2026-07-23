import Foundation

/// Pure, SDK-free entitlement resolution for the Friend "A little" subscription.
///
/// Friend-IAP wave 3 (2026-07-08). Native Locals sells the Friend "A little"
/// plan (A$29.99/mo auto-renewable) via Apple IAP / Play Billing through
/// RevenueCat. This file is the Swift port of the glovebox `resolveUnlock` /
/// `rcFriendAppUserId` spec (glovebox `src/lib/paywall/tripGate.ts`) - it holds
/// NO RevenueCat import so it is unit-testable against fixtures the same way the
/// glovebox resolver is (10/10 fixture pass). `FriendPurchases` maps RevenueCat's
/// `CustomerInfo` into an `EntitlementSnapshot` and calls `resolveUnlock`.
///
/// Entitlement `friend` is primary. There is no grandfathered legacy entitlement
/// on Locals (unlike glovebox's `roam_unlimited` lifetime buyers), so the id list
/// is just `friend`. Product-identifier fallbacks guard against a RevenueCat
/// dashboard entitlement-mapping drift so a paying customer is never locked out.
enum FriendPlan {
    /// Primary RevenueCat entitlement id (the Friend subscription).
    static let entitlementID = "friend"
    static let entitlementIDs = [entitlementID]

    /// RevenueCat offering + package the paywall buys.
    static let offeringID = "default"
    static let packageID = "$rc_monthly"

    /// Store product identifiers that prove the Friend perk. iOS uses the
    /// Locals-specific ASC product id (`friend_a_little_monthly` is account-unique
    /// on Apple and already owned by glovebox's au.ecodia.roam, so Locals gets its
    /// own). Android reuses the store-scoped `friend_a_little_monthly`. Both are
    /// accepted so one resolver serves either platform's CustomerInfo.
    static let iosProductID = "friend_a_little_monthly_locals"
    static let androidProductID = "friend_a_little_monthly"
    static let productIDs = [iosProductID, androidProductID, "friend_a_little_monthly:monthly-autorenew"]

    /// Sub copy - App Store / Play require an auto-renewal disclosure and forbid
    /// "lifetime/forever" language on an auto-renewable subscription.
    static let priceLine = "A$29.99 per month. cancel anytime."
    static let renewalDisclosure =
        "Your subscription renews automatically each month until cancelled. Manage or cancel any time in your App Store or Google Play account settings."
}

/// A minimal, SDK-independent view of a RevenueCat `CustomerInfo`, mirroring the
/// glovebox `CustomerInfoLike` shape so the resolver can be exercised by tests
/// without StoreKit / RevenueCat.
struct EntitlementSnapshot {
    /// Entitlement ids currently active (RevenueCat `entitlements.active`).
    var activeEntitlements: Set<String> = []
    /// Product ids with an active subscription (`activeSubscriptions`).
    var activeSubscriptions: [String] = []
    /// All purchased product ids (`allPurchasedProductIdentifiers`).
    var allPurchasedProductIDs: [String] = []
    /// Non-subscription transaction product ids.
    var nonSubscriptionProductIDs: [String] = []
}

/// How the unlock was proven - `entitlement` is the healthy path; the fallbacks
/// fire only on a dashboard mapping drift and are logged by the caller.
enum UnlockSource: String {
    case entitlement
    case subscriptionFallback = "subscription-fallback"
    case productFallback = "product-fallback"
    case transactionFallback = "transaction-fallback"
    case none
}

struct UnlockResult: Equatable {
    let unlocked: Bool
    let source: UnlockSource

    static func == (lhs: UnlockResult, rhs: UnlockResult) -> Bool {
        lhs.unlocked == rhs.unlocked && lhs.source == rhs.source
    }
}

enum FriendPurchaseResolver {
    /// Resolve unlock state from an entitlement snapshot. Primary check: the
    /// `friend` entitlement is active. Fallbacks: an active subscription, a
    /// purchased product, or a non-subscription transaction for a qualifying
    /// Friend product id - each is sufficient proof so a paying user is never
    /// locked out by a mis-named dashboard entitlement.
    static func resolveUnlock(_ snapshot: EntitlementSnapshot?) -> UnlockResult {
        guard let s = snapshot else { return UnlockResult(unlocked: false, source: .none) }

        if FriendPlan.entitlementIDs.contains(where: { s.activeEntitlements.contains($0) }) {
            return UnlockResult(unlocked: true, source: .entitlement)
        }
        if s.activeSubscriptions.contains(where: { FriendPlan.productIDs.contains($0) }) {
            return UnlockResult(unlocked: true, source: .subscriptionFallback)
        }
        if s.allPurchasedProductIDs.contains(where: { FriendPlan.productIDs.contains($0) }) {
            return UnlockResult(unlocked: true, source: .productFallback)
        }
        if s.nonSubscriptionProductIDs.contains(where: { FriendPlan.productIDs.contains($0) }) {
            return UnlockResult(unlocked: true, source: .transactionFallback)
        }
        return UnlockResult(unlocked: false, source: .none)
    }

    /// The RevenueCat `app_user_id` to identify with. Prefers the canonical Friend
    /// account id (`app_metadata.friend_id`, written by the Locals friend_id
    /// trigger pair after a Connect-your-Friend login) so RC's app_user_id matches
    /// what the friend-iap reconciler keys the central `ecodia_subscriptions` row
    /// on. Falls back to the local Locals user id before a Friend is connected.
    /// Returns nil when there is no user.
    ///
    /// - Parameters:
    ///   - friendID: `app_metadata.friend_id` if present.
    ///   - localUserID: the Locals Supabase `auth.users.id`.
    static func appUserID(friendID: String?, localUserID: String?) -> String? {
        if let f = friendID, !f.isEmpty { return f }
        if let u = localUserID, !u.isEmpty { return u }
        return nil
    }
}
