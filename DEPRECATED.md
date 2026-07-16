# DEPRECATED - Locals iOS native app retired 2026-07-16

This repository (native SwiftUI) is no longer the shipping surface for Locals on iOS.

**Locals mobile is now a Capacitor wrap of the React web app** at
`/Users/ecodia/.code/locals-web`. One codebase feeds web, iOS and Android; every
future feature lands on all three at once instead of being built three times.

Decision: Tate 2026-07-16, Neo4j `locals-collapses-to-one-react-codebase-2026-07-16`.
Basis: a full three-codebase inventory found locals-web was already the reference
surface (merchant claim flow, team RBAC + invites, admin, sustainability review,
account export were all web-only; this native had even silently dropped the
redemption-code flow). The native's only carried value (Sign in with Apple,
RevenueCat IAP, deep links) is all reproduced in the wrap.

## What replaced this, and where the store record lives now

- Store record: **App Store Connect app `6775331079`, bundle `au.ecodia.local`**
  (no trailing "s" - this repo's old README/STATUS said `au.ecodia.locals`, which
  was wrong; the pbxproj was truth). Team `86PUY7393S`.
- The wrap shipped **1.0.5 build 15** to TestFlight on 2026-07-16 (ASC
  processingState VALID), superseding this repo's last build 1.0.4(14).
- iOS project for the wrap: `locals-web/ios/` (Capacitor). SIWA via
  `@capacitor-community/apple-sign-in` + `supabase.auth.signInWithIdToken`;
  the Friend "A little" sub via `@revenuecat/purchases-capacitor` (entitlement
  `friend`, product `friend_a_little_monthly_locals`, RC app `app5e43fcc765`).

## Do not

- Do not ship a new build from this repo. It will fork the `au.ecodia.local`
  store record away from the wrap.
- Do not delete this repo. It is the reference for the native map/paywall/redeem
  behaviour and the source of the migration's SIWA + IAP parity.

History and rationale: `backend/clients/locals.md`, memory
`locals-one-codebase-capacitor-wrap-2026-07-16`.
