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

1. Resolve the local iOS config from Infisical:
   `./scripts/generate-local-xcconfig.sh local`
2. This writes `apps/ios/Config/Local.xcconfig` with the client-side values needed for your build.
3. Open `apps/ios/Avradio.xcodeproj` in Xcode and run the `Avradio` scheme.

For internal builds, keep the real values out of git and regenerate `Local.xcconfig` from Infisical when needed.

## Local Secrets

This project may use local Infisical bootstrap files during development, but nothing inside `.infisical/` is versioned in git.

See [docs/install-ios.md](docs/install-ios.md) for simulator and device setup details.

## Contributing And Security

- Contribution guide: [CONTRIBUTING.md](CONTRIBUTING.md)
- Security policy: [SECURITY.md](SECURITY.md)
