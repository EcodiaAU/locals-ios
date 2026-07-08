import XCTest
@testable import Locals

/// Fixtures for the Friend-IAP wave-3 entitlement resolver, mirroring the
/// glovebox `resolveUnlock` / `rcFriendAppUserId` 10/10 fixture suite. Pure -
/// no RevenueCat / StoreKit needed, the same reason the glovebox resolver is
/// unit-testable.
final class FriendPurchaseResolverTests: XCTestCase {

    // 1. friend entitlement active -> unlocked via entitlement (healthy path)
    func testFriendEntitlementUnlocks() {
        let snap = EntitlementSnapshot(activeEntitlements: ["friend"])
        let r = FriendPurchaseResolver.resolveUnlock(snap)
        XCTAssertTrue(r.unlocked)
        XCTAssertEqual(r.source, .entitlement)
    }

    // 2. nil snapshot -> locked
    func testNilSnapshotLocked() {
        let r = FriendPurchaseResolver.resolveUnlock(nil)
        XCTAssertFalse(r.unlocked)
        XCTAssertEqual(r.source, .none)
    }

    // 3. empty snapshot -> locked
    func testEmptySnapshotLocked() {
        let r = FriendPurchaseResolver.resolveUnlock(EntitlementSnapshot())
        XCTAssertFalse(r.unlocked)
        XCTAssertEqual(r.source, .none)
    }

    // 4. active iOS subscription, no entitlement mapping -> subscription fallback
    func testIOSSubscriptionFallback() {
        let snap = EntitlementSnapshot(activeSubscriptions: ["friend_a_little_monthly_locals"])
        let r = FriendPurchaseResolver.resolveUnlock(snap)
        XCTAssertTrue(r.unlocked)
        XCTAssertEqual(r.source, .subscriptionFallback)
    }

    // 5. active Android subscription id -> subscription fallback (one resolver, both stores)
    func testAndroidSubscriptionFallback() {
        let snap = EntitlementSnapshot(activeSubscriptions: ["friend_a_little_monthly"])
        let r = FriendPurchaseResolver.resolveUnlock(snap)
        XCTAssertTrue(r.unlocked)
        XCTAssertEqual(r.source, .subscriptionFallback)
    }

    // 6. purchased product but no active subscription/entitlement -> product fallback
    func testPurchasedProductFallback() {
        let snap = EntitlementSnapshot(allPurchasedProductIDs: ["friend_a_little_monthly:monthly-autorenew"])
        let r = FriendPurchaseResolver.resolveUnlock(snap)
        XCTAssertTrue(r.unlocked)
        XCTAssertEqual(r.source, .productFallback)
    }

    // 7. non-subscription transaction for a Friend product -> transaction fallback
    func testTransactionFallback() {
        let snap = EntitlementSnapshot(nonSubscriptionProductIDs: ["friend_a_little_monthly_locals"])
        let r = FriendPurchaseResolver.resolveUnlock(snap)
        XCTAssertTrue(r.unlocked)
        XCTAssertEqual(r.source, .transactionFallback)
    }

    // 8. unrelated entitlement + unrelated product -> locked (no false unlock)
    func testUnrelatedStaysLocked() {
        let snap = EntitlementSnapshot(
            activeEntitlements: ["some_other_plan"],
            activeSubscriptions: ["com.example.other"],
            allPurchasedProductIDs: ["com.example.other"],
            nonSubscriptionProductIDs: ["com.example.tip"]
        )
        let r = FriendPurchaseResolver.resolveUnlock(snap)
        XCTAssertFalse(r.unlocked)
        XCTAssertEqual(r.source, .none)
    }

    // 9. appUserID prefers the Friend account id over the local user id
    func testAppUserIDPrefersFriendID() {
        let id = FriendPurchaseResolver.appUserID(friendID: "friend-abc", localUserID: "local-xyz")
        XCTAssertEqual(id, "friend-abc")
    }

    // 10. appUserID falls back to local id, and is nil when both are empty
    func testAppUserIDFallbackAndNil() {
        XCTAssertEqual(FriendPurchaseResolver.appUserID(friendID: nil, localUserID: "local-xyz"), "local-xyz")
        XCTAssertEqual(FriendPurchaseResolver.appUserID(friendID: "", localUserID: "local-xyz"), "local-xyz")
        XCTAssertNil(FriendPurchaseResolver.appUserID(friendID: nil, localUserID: nil))
        XCTAssertNil(FriendPurchaseResolver.appUserID(friendID: "", localUserID: ""))
    }
}
