# locals-ios parity with locals-web

The web (locals-web) is the v1 reference surface. iOS is built to match the user-facing surface 1:1 where it makes sense, and breaks parity where a native iOS pattern serves the user better.

## v1.0 surface parity

| Surface | Web | iOS | Notes |
|---|---|---|---|
| Landing / onboarding | sentence + entry row | 3-slide onboarding | iOS gets a real first-run flow; native fit |
| Sign in (Apple) | n/a | Sign in with Apple primary | Native iOS win |
| Sign in (magic link) | yes | yes (fallback) | OTP email via Supabase |
| Discover map + list | OpenFreeMap + JS pins | **MapKit** + native pins | Native iOS clustering, look-around, user-location |
| Category filter | yes | yes | |
| Merchant detail (per-merchant theme) | yes | yes | 8 colours + 6 fonts |
| Owner note (timestamped) | yes | yes | |
| Live rewards | yes | yes | Mustard "Get code" pill |
| Issue 5-min code | yes | yes | + screen-stays-awake, max brightness, haptic |
| Hours | yes | yes | |
| Photo gallery | yes | yes | Horizontal scroll, Nuke cache |
| Sustainability tags + signal pct | yes | yes | |
| Contact links (phone / email / IG / web) | yes | yes (`Link` -> tel:/mailto:/instagram://) | |
| Favorites | yes | yes | Swipe-to-delete, heart icon |
| My redemptions | yes | yes | Status badge per row |
| Share merchant | n/a (web URL) | `ShareLink` -> https://locals.ecodia.au/<slug> | Native |
| Deep link to merchant | yes (`/<slug>`) | yes (`locals://m/<slug>`) | |
| Settings | yes | yes | Crowd toggle, version, links |
| Feedback | yes | yes | edge function backed |
| Delete account | yes | yes | Apple 5.1.1(v) compliant |

## Merchant admin parity

| Surface | Web | iOS | Notes |
|---|---|---|---|
| Dashboard | yes | yes | One row per owned merchant |
| Create merchant | yes | yes | `create_merchant` RPC |
| Edit basics | yes | yes | name, story, address, category |
| Theme picker | yes | yes | Live preview |
| Owner note | yes | yes | `set_owner_note` RPC |
| Status (draft/active/paused/archived) | yes | yes | |
| Sustainability tags self-declare | yes | yes | |
| Rewards admin | yes | yes | Create, toggle, delete |
| Consume code (counter) | yes | yes | 6-char input, success card |
| Billing (Stripe Checkout) | yes | yes | SFSafariViewController; Apple 2024 reader pattern |
| Cancel subscription | yes | yes | |

## Native iOS wins (no web equivalent)

- Sign in with Apple (primary path; magic link is fallback)
- MapKit native clustering + look-around + user location
- Haptic feedback throughout
- Screen-stays-awake during code display
- ShareLink for merchant URLs
- Pull-to-refresh on every list
- Custom URL scheme `locals://m/<slug>`

## Parked (not in v1.0)

- Live Activity / Dynamic Island for active 5-min code (v1.1)
- Lock screen widget for "Your active code" (v1.1)
- App Intents / Shortcuts ("show my codes") (v1.1)
- Background presence pulse (D4 from migration 0004) - the setting toggle ships in v1.0 but the actual background watcher lands in v1.1 when the regional crowd density warrants it
- Sustainability post-consumption review modal (D5) - the RPC + table are there; the modal lands in v1.1
- Universal Links (apple-app-site-association) - shipping in v1.1 once the bundle id is verified on the domain
- Push notifications (no use case in v1.0)
- CarPlay (no use case)
- iPad layout overrides (works on iPad as-is in v1.0; iPad-specific split view comes later)
