# locals-ios status

## Current

- **Phase**: v1.0 initial ship to TestFlight
- **Branch**: main
- **Marketing version**: 1.0.0
- **Last build**: pending first SY094 ship

## Build environment

- Mac: SY094 (macincloud)
- macOS: 15.7.4
- Xcode: 26.3
- xcodegen: 2.45.4 (at `~/bin/xcodegen`)
- ASC API key: `R8P6K38X47`
- Team: `86PUY7393S`
- Bundle ID: `au.ecodia.locals`

## SPM dependencies

| Package | Version | Used for |
|---|---|---|
| supabase-swift | from 2.20.0 | auth + PostgREST + Storage |
| Nuke | from 12.8.0 | merchant photo loading + cache |

## Build history

| Marketing | Build | Date | Outcome | Notes |
|---|---|---|---|---|
| 1.0.0 | pending | - | - | initial TestFlight upload |

## Pre-ship checklist

- [x] ASC app record exists for `au.ecodia.locals` (Tate created, 2026-06-03)
- [x] First ASC version row for 1.0.0 - **assumed present** (Tate created listing); confirm on first ship
- [x] ExportOptions.plist
- [x] `Locals.entitlements` with Sign in with Apple
- [x] Info.plist usage strings (location, camera, photos)
- [x] Bundle ID `au.ecodia.locals` set in project.yml
- [x] DesignTokens.swift generated from locals-shared
- [ ] `Sources/Locals/Resources/Fonts/Spectral-*.ttf` bundled in repo (currently loads via system fallback; tokens reference it; replace placeholder in next polish pass)
- [ ] AppIcon 1024x1024 PNG placed in `Resources/Assets.xcassets/AppIcon.appiconset/`

## Blockers / open

- AppIcon: shipped as the empty appiconset slot in v1.0(1). Apple accepts upload without rejection; the icon needs to land before the first public TestFlight. Sourcing from the same brand grammar as locals-web.
- Spectral font ttf: gracefully degrades to SF Pro serif italic when missing. Bundle in v1.0(2).
- Universal Links AASA: ship to `https://locals.ecodia.au/.well-known/apple-app-site-association` once the team has TestFlight access and we can verify the bundle id.

## v1.1 follow-ups

(See PARITY.md "Parked" section.) Each gets its own status_board row when work starts.
