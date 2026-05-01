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
bun run android:config
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
bun run android:config
```

For release preparation:

```bash
bun run android:config:production
```

The normal local workflow should use generated `apps/android/local.properties`.
Do not document or hand-maintain generated values in this public repository; update the private Varlock/Infisical source instead.

The public repo currently supports:

- real AV Apps Account initialization and sign-in UI through the active provider SDK
- account session observation and sign-out through the active provider SDK
- backend-backed access resolution through `GET /v1/me/access` when `AVAPPS_API_BASE_URL` is configured
- shared `app-data` sync for `library` when backend access resolves `canUseCloudSync=true`
- opening a configured web sign-in URL from onboarding/profile
- accepting a deep-link callback and materializing a local signed-in state from query params
- an `AuthSessionExchange` seam so the callback-to-session step can be replaced by a real backend exchange

The public repo does not yet implement:

- billing-backed entitlements on Android
- conflict-aware or partial `library` merge beyond snapshot sync
- cross-device account state beyond shared backend access and `library` sync

## Current Delivery Status

Implemented:

- Compose shell with Home, Search, Library, and Profile
- onboarding and local access states
- Radio Browser search and discovery
- visible in-product data-source attribution for Radio Browser in Profile
- Media3 playback with background service
- favorites, recents, queue, and sleep timer
- now playing screen
- unit tests for playback logic
- instrumented test bundle for primary navigation flows
- GitHub Actions workflow for unit tests, APK assembly, and emulator-backed instrumented tests

Still external or pending:

- Google Play Billing
- broader production app-data sync beyond `library`
