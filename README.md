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
shared/
  apple/     Swift Modules shared by iOS and macOS
  contracts/ Platform-neutral contracts reserved for backend/client parity
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
  - backend-backed app-data sync when access enables cloud sync
- `apps/macos` exists as a native companion target
- `shared/apple` is the single shared Swift implementation root for iOS/macOS behavior
- `shared/contracts` is reserved for platform-neutral backend/client contracts when a non-Apple consumer exists
- the repo remains local-first overall, and platform/backend adoption is still narrower than in `public/av-series`
- current product focus is `av-radio iOS`; Android and macOS should be treated as lower-priority follow-up work unless explicitly promoted

## Local Setup

### iOS

1. Install repo tooling:
   `bun install`
2. Resolve the local iOS config through the private `av-apps` Varlock + Infisical bootstrap:
   `bun run ios:config`
3. This writes `apps/ios/Config/Local.xcconfig` with the client-side values needed for your build.
4. Open `apps/ios/Avradio.xcodeproj` in Xcode and run the `Avradio` scheme.

### Android

1. Generate `apps/android/local.properties` locally through Varlock:
   `bun run android:config`
2. Build from `apps/android`:
   `./gradlew --no-daemon assembleDebug`

### macOS

- The repo contains `apps/macos/AvradioMac` as a native SwiftUI target for local Xcode work.

For internal builds, keep the real values out of git and regenerate local config through Varlock + Infisical when needed.

## Local Secrets

This public repo does not carry Infisical bootstrap examples or generated local config.

- private bootstrap material belongs in Avalsys private infrastructure
- generated native local files stay local-only
- native local files are generated through `varlock printenv`, not manual `infisical export` parsing
- do not add `.env.example`, bootstrap examples, or placeholder secrets to this public repo

Run `bun run config:hygiene` before pushing config-related changes.

See [docs/install-ios.md](docs/install-ios.md) and [docs/install-android.md](docs/install-android.md) for setup details.

## Platform integration

- iOS can use `AVAPPS_API_BASE_URL` to refresh signed-in access through `GET /v1/me/access`
- Android can do the same through generated local runtime config
- backend-backed app-data sync is available when account access enables cloud sync
- subscription/provider reconciliation is owned by the private AV Apps backend; this public client consumes the resulting access state

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

1. Keep App Store and Google Play production reconciliation owned in private AV Apps infrastructure.
2. Continue expanding product-specific cloud sync UX and conflict/merge handling across devices.
3. Keep active AV Radio work focused on `iOS`, using Android/macOS mainly as secondary references until priorities change.
4. Keep iOS and Android access behavior aligned on backend-owned capabilities.
5. Decide later whether macOS becomes a maintained first-class target or stays a companion/experimental app.
6. Keep store disclosures aligned with the shipped account/deletion flow as production distribution expands.

## Contributing And Security

- Contribution guide: [CONTRIBUTING.md](CONTRIBUTING.md)
- Security policy: [SECURITY.md](SECURITY.md)
