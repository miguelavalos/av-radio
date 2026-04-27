# AV Radio

Open-source native product repo for AV Radio.

This repository contains the AV Radio clients for iOS, Android, and macOS, together with local playback and persistence flows, account-facing UI, and development-time premium/access configuration. Premium value, shared entitlement authority, and account platform logic still converge in private infrastructure outside this repository.

The current main product target is `iOS`. `Android` and `macOS` exist in the repo, but they are secondary for now.

When configured, the iOS and Android clients can now resolve signed-in access from the shared AV Apps backend while remaining local-first by default.

## License

This repository is released under the MIT license. See [LICENSE](LICENSE).

## Repository Shape

```text
apps/
  ios/      SwiftUI iOS app
  android/  Kotlin + Jetpack Compose Android app
  macos/    SwiftUI macOS app
docs/
  install-android.md
  install-ios.md
```

## What Is Included

- local-first listening experience
- favorites, recents, and on-device settings
- account and premium UI surfaces
- local StoreKit configuration for development
- iOS project and Xcode configuration
- Android project with Media3 playback, onboarding, account states, and tests
- macOS target with native SwiftUI shell

## Current state

- `apps/ios` is still the most complete product client
- `apps/ios` is the current primary execution target
- `apps/android` is implemented beyond bootstrap and includes:
  - Home, Search, Library, and Profile
  - Media3 playback with background service
  - favorites, recents, queue, and sleep timer
  - onboarding and multiple auth modes
  - backend-backed access refresh when configured
  - shared `library` sync when backend access enables cloud sync
- `apps/macos` exists as a native companion target
- the repo remains local-first overall, and platform/backend adoption is still narrower than in `public/av-series`
- current product focus is `av-radio iOS`; Android and macOS should be treated as lower-priority follow-up work unless explicitly promoted

## Local Setup

### iOS

1. Install repo tooling:
   `bun install`
2. Create the shared Infisical bootstrap:
   `cp .infisical/bootstrap.env.example .infisical/bootstrap.env`
3. Resolve the local iOS config through Varlock + Infisical:
   `bun run ios:config`
4. This writes `apps/ios/Config/Local.xcconfig` with the client-side values needed for your build.
5. Open `apps/ios/Avradio.xcodeproj` in Xcode and run the `Avradio` scheme.

### Android

1. Generate `apps/android/local.properties` locally through Varlock:
   `bun run android:config`
2. Build from `apps/android`:
   `./gradlew --no-daemon assembleDebug`

### macOS

- The repo contains `apps/macos/AvradioMac` as a native SwiftUI target for local Xcode work.

For internal builds, keep the real values out of git and regenerate local config through Varlock + Infisical when needed.

## Local Secrets

This project follows the same shared bootstrap pattern used in the internal repos:

- `.infisical/bootstrap.env.example` is committed
- `.infisical/bootstrap.env` stays local-only
- `.env.schema` is the canonical repo contract
- native local files are generated through `varlock printenv`, not manual `infisical export` parsing

See [docs/install-ios.md](docs/install-ios.md) and [docs/install-android.md](docs/install-android.md) for setup details.

## Platform integration

- iOS can use `AVRADIO_AVAPPS_API_BASE_URL` to refresh signed-in access through `GET /v1/me/access`
- Android can do the same through generated local runtime config
- shared backend sync is currently limited to `library`
- billing-provider reconciliation into shared entitlements is still pending

## Third-Party Services And Data Sources

- Station discovery currently relies on `Radio Browser`.
- Playback relies on direct third-party station stream hosts that AV Radio does not control.
- Artwork resolution may use Apple `iTunes Search`.
- Favicon fallback resolution may use Google's favicon endpoint when station metadata does not provide a usable icon.
- Optional signed-in account and entitlement flows depend on the private AV Apps backend and related identity infrastructure.
- Profile surfaces now expose an in-product data-source reference for `Radio Browser`.

## Account Deletion Support

- Public deletion support URL: `https://av-radio.avalsys.com/delete-account`
- Local-only users can remove on-device data from inside the app or by deleting the app.
- If an AV Apps account was used, the public deletion page documents the out-of-app request path and the provider-subscription caveats.

## Pending work

1. Reconcile App Store and Google Play purchases into shared backend entitlements.
2. Extend sync beyond `library` and define conflict/merge behavior across devices.
3. Keep active AV Radio work focused on `iOS`, using Android/macOS mainly as secondary references until priorities change.
4. Keep iOS and Android access behavior aligned on backend-owned capabilities.
5. Decide later whether macOS becomes a maintained first-class target or stays a companion/experimental app.
6. Keep store disclosures aligned with the shipped account/deletion flow as production distribution expands.

## Contributing And Security

- Contribution guide: [CONTRIBUTING.md](CONTRIBUTING.md)
- Security policy: [SECURITY.md](SECURITY.md)
