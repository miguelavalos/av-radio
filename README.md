# AV Radio

Open-source iOS client for AV Radio.

This repository contains the native app client, local playback and persistence flows, account-facing UI, and local StoreKit configuration used for development. Premium value, backend processing, subscriptions authority, and account platform logic live outside this repository.

## License

This repository is released under the MIT license. See [LICENSE](LICENSE).

## Repository Shape

```text
apps/
  ios/      SwiftUI iOS app
docs/
  install-ios.md
```

## What Is Included

- local-first listening experience
- favorites, recents, and on-device settings
- account and premium UI surfaces
- local StoreKit configuration for development
- iOS project and Xcode configuration

## Local Setup

1. Copy `apps/ios/Config/Local.xcconfig.example` to `apps/ios/Config/Local.xcconfig`.
2. Fill in the client-side values needed for your build.
3. Open `apps/ios/Avradio.xcodeproj` in Xcode and run the `Avradio` scheme.

For internal builds, keep the real bundle identifier and production-facing client values in your local, non-versioned `Local.xcconfig`.

## Local Secrets

This project may use local Infisical bootstrap files during development, but nothing inside `.infisical/` is versioned in git.

See [docs/install-ios.md](docs/install-ios.md) for simulator and device setup details.

## Contributing And Security

- Contribution guide: [CONTRIBUTING.md](CONTRIBUTING.md)
- Security policy: [SECURITY.md](SECURITY.md)
