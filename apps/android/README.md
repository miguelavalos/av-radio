# AV Radio Android

Android sibling app for AV Radio. This directory is intentionally separate from `apps/ios` so Android can be developed without changing the iOS app.

## Goal

Clone the current iOS product behavior on Android while keeping:

- `apps/ios` untouched
- platform-native UI and runtime on both platforms
- shared product behavior at the contract level, not by forcing a shared runtime

## Recommended Baseline

- Kotlin
- Jetpack Compose
- Navigation Compose
- ViewModel + StateFlow
- Media3 / ExoPlayer
- Room
- DataStore
- Retrofit or Ktor
- Kotlinx Serialization
- Coil
- Hilt
- Google Play Billing

## Initial Package Layout

Start simple. A single app module is enough for the first milestone.

```text
apps/android/
  app/
    src/main/java/com/avradio/
      app/
      core/model/
      core/network/
      core/database/
      core/datastore/
      core/player/
      core/designsystem/
      feature/auth/
      feature/home/
      feature/search/
      feature/library/
      feature/profile/
      feature/player/
```

Once the Android app is stable, this can be split into true Gradle modules if build time or ownership demands it.

## Product Mapping From iOS

Clone behavior from these iOS sources:

- `../ios/Avradio/App/RootView.swift`
- `../ios/Avradio/Features/Shell/AppShellView.swift`
- `../ios/Avradio/App/AccessController.swift`
- `../ios/Avradio/Core/Networking/StationService.swift`
- `../ios/Avradio/Core/Audio/AudioPlayerService.swift`
- `../ios/Avradio/Core/Persistence/LibraryStore.swift`
- `../ios/Avradio/Models/Station.swift`

## Milestone Plan

### Milestone 1

- project bootstrap
- station search
- home feed
- basic playback

### Milestone 2

- favorites
- recents
- mini player
- now playing screen

### Milestone 3

- onboarding
- profile
- account connection

### Milestone 4

- premium state
- Google Play Billing
- release hardening

## Open Questions Before Billing

- Is premium authority local to the app, backend-backed, or both?
- Is Sign in with Apple required on Android, or is Google enough for v1?
- How should existing premium users be recognized across iOS and Android?

## Non-Goals

- no migration of iOS to a shared framework
- no edits under `apps/ios`
- no attempt to auto-convert SwiftUI views into Compose

## Next Build Step

Generate `apps/android/local.properties` locally and keep local secrets out of git:

```bash
./scripts/generate-android-local-properties.sh local
```

## Useful Commands

From `apps/android`:

- `./gradlew --no-daemon assembleDebug`
- `./gradlew --no-daemon testDebugUnitTest`
- `./gradlew --no-daemon assembleAndroidTest`

If you have an emulator or device connected:

- `./gradlew --no-daemon connectedDebugAndroidTest`

## Auth Configuration

Android runtime config follows the same local-generated pattern used by iOS. Generate `apps/android/local.properties` locally:

```bash
./scripts/generate-android-local-properties.sh local
```

For release preparation:

```bash
./scripts/generate-android-local-properties.sh production
```

Gradle still accepts environment overrides, but the normal local workflow should use `apps/android/local.properties`.

The generated config provides:

- `AVRADIO_APPLICATION_ID=com.example.avradio.dev`
- `AVRADIO_AUTH_PROVIDER=clerk`
- `AVRADIO_AUTH_PROVIDER=web`
- `AVRADIO_AUTH_PROVIDER=demo`
- `AVRADIO_AUTH_PROVIDER=none`
- `CLERK_PUBLISHABLE_KEY=pk_test_...`
- `AVRADIO_AUTH_WEB_URL=https://your-auth-entrypoint.example.com`
- `AVRADIO_AUTH_CALLBACK_SCHEME=avradio`
- `AVRADIO_AUTH_CALLBACK_HOST=auth`
- `AVRADIO_PREMIUM_PRODUCT_IDS=com.example.avradio.pro.monthly,com.example.avradio.pro.yearly`
- `AVRADIO_SUPPORT_EMAIL=support@example.com`
- `AVRADIO_ACCOUNT_MANAGEMENT_URL=https://example.com/account`
- `AVRADIO_TERMS_URL=https://example.com/terms`
- `AVRADIO_PRIVACY_URL=https://example.com/privacy`

Examples:

- Clerk like iOS:
  `AVRADIO_AUTH_PROVIDER=clerk`
  `CLERK_PUBLISHABLE_KEY=pk_test_...`
- local demo mode:
  `AVRADIO_AUTH_PROVIDER=demo`
- external web handoff:
  `AVRADIO_AUTH_PROVIDER=web`
  `AVRADIO_AUTH_WEB_URL=https://example.com/sign-in`
  callback target example:
  `avradio://auth/callback?user_id=123&name=AV%20Listener&email=listener%40example.com&plan=pro`

The public repo currently supports:

- real Clerk SDK initialization and sign-in UI via `AuthView`
- Clerk session observation and sign-out through Android native SDK
- opening a configured web sign-in URL from onboarding/profile
- accepting a deep-link callback and materializing a local signed-in state from query params
- an `AuthSessionExchange` seam so the callback-to-session step can be replaced by a real backend exchange

The public repo does not yet implement:

- billing-backed entitlements on Android
- backend-backed entitlement resolution
- cross-device account state beyond Clerk session identity

## Current Delivery Status

Implemented:

- Compose shell with Home, Search, Library, and Profile
- onboarding and local access states
- Radio Browser search and discovery
- Media3 playback with background service
- favorites, recents, queue, and sleep timer
- now playing screen
- unit tests for playback logic
- instrumented test bundle for primary navigation flows
- GitHub Actions workflow for unit tests, APK assembly, and emulator-backed instrumented tests

Still external or pending:

- Google Play Billing
- production backend entitlement sync
