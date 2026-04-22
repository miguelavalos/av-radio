# AV Radio iOS Installation

This guide is for local simulator runs and for installing `AV Radio` on a connected iOS device.

## Current signing setup

- Xcode project: `apps/ios/Avradio.xcodeproj`
- scheme: `Avradio`
- development team: use your own Apple Developer team when signing for device installs
- device bundle identifier: use a development bundle identifier that belongs to your team

Current note:

- `apps/ios/Avradio/App/Avradio.entitlements` is intentionally empty in the current repo state. This keeps local device signing simple and avoids blocking installs on missing capabilities during development.

## Prerequisites

1. Xcode 26.4.1 or later installed
2. An Apple account available in `Xcode > Settings > Accounts`
3. Command line tools selected from that Xcode
4. `apps/ios/Config/Local.xcconfig` created from `apps/ios/Config/Local.xcconfig.example`

## Run on simulator

```bash
xcodebuild -project apps/ios/Avradio.xcodeproj \
  -scheme Avradio \
  -configuration Debug \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  build
```

You can also open `apps/ios/Avradio.xcodeproj` in Xcode and run `Avradio`.

## Install on a connected iOS device

Build for the device:

```bash
xcodebuild -project apps/ios/Avradio.xcodeproj \
  -scheme Avradio \
  -configuration Debug \
  -destination 'id=<DEVICE_UDID>' \
  -allowProvisioningUpdates \
  DEVELOPMENT_TEAM=<YOUR_TEAM_ID> \
  PRODUCT_BUNDLE_IDENTIFIER=<YOUR_DEV_BUNDLE_ID> \
  CODE_SIGN_STYLE=Automatic \
  build
```

Install the generated app:

```bash
xcrun devicectl device install app \
  --device <DEVICE_UDID> \
  ~/Library/Developer/Xcode/DerivedData/Avradio-*/Build/Products/Debug-iphoneos/Avradio.app
```

Launch it:

```bash
xcrun devicectl device process launch \
  --device <DEVICE_UDID> \
  <YOUR_DEV_BUNDLE_ID> \
  --activate
```

## First launch trust step

If iOS refuses to open the app after install, trust the developer profile once on the phone:

1. Open `Settings > General > VPN & Device Management`
2. Open the developer app entry that matches the Apple account used for signing
3. Tap `Trust`
4. Open `AV Radio` again from the device home screen

## Known local-dev constraints

- If `Sign in with Apple` is re-enabled in entitlements, device provisioning must also support that capability.
- If the build hangs in `Resolve Package Graph`, restart Xcode and retry from a clean terminal.
