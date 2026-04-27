# AV Radio iOS

SwiftUI iOS app for AV Radio.

## Local Config

1. From the repo root, run `bun install`.
2. Create `.infisical/bootstrap.env` from `.infisical/bootstrap.env.example`.
3. Generate `Config/Local.xcconfig` from the repo root with `bun run ios:config`.
4. Open `Avradio.xcodeproj` in Xcode.

The public repository ships with neutral defaults. Internal builds can override `AVRADIO_BUNDLE_IDENTIFIER` and the other client-facing values in the local, non-versioned `Config/Local.xcconfig`.

Optional local subscription config:

- set `AVRADIO_PREMIUM_PRODUCT_IDS` in `Config/Local.xcconfig`
- use a comma-separated list of App Store subscription product IDs, with the first ID treated as the default purchase option in the current UI
- the repo ships with `Config/StoreKit/LocalSubscriptions.storekit` for local StoreKit testing in Xcode
- keep `AVRADIO_PREMIUM_PRODUCT_IDS` aligned with the product IDs defined in that `.storekit` file
- the shared `Avradio` scheme is configured to use the local StoreKit file on Run

Optional shared-platform access config:

- set `AVRADIO_AVAPPS_API_BASE_URL` in `Config/Local.xcconfig` to enable backend-owned access resolution through `private/av-apps`
- when both `CLERK_PUBLISHABLE_KEY` and `AVRADIO_AVAPPS_API_BASE_URL` are configured, signed-in access refreshes from `GET /v1/me/access`
- StoreKit remains the client fallback while purchase-to-entitlement reconciliation is still being finalized outside this repo

## Current app shape

- shared internal access model with `guest`, `signedInFree`, and `signedInPro`
- current product-facing states are `local mode`, `connected account`, and `pro`
- `AV Apps Account` as the product-facing account layer name
- onboarding with `Skip for now`
- local-first shell that works without sign-in
- signing in does not change storage behavior yet; it only connects an account and can refresh backend-owned access when configured
- premium access remains the only state allowed to grow into backend-backed features

## Localization

- Development language is English and base strings live in `Avradio/Resources/en.lproj/Localizable.strings`
- Spanish strings live in `Avradio/Resources/es.lproj/Localizable.strings`
- No extra `InfoPlist.strings` are needed right now because the visible app name stays `AV Radio` across locales and the current build has no localized permission prompts
- Dynamic catalog content such as station names, countries, languages, tags, and external metadata is shown as returned by the provider and is not translated by the app
