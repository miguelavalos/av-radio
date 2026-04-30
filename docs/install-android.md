# AV Radio Android Installation

This guide is for local Android builds while keeping the same local config pattern used by iOS.

## Current Android setup

- Gradle project: `apps/android`
- app module: `apps/android/app`
- generated local config file: `apps/android/local.properties`

## Prerequisites

1. Android Studio Koala or later, or a working local Android SDK + JDK 17
2. `bun` 1.3.13 or later
3. Private Avalsys Varlock/Infisical bootstrap available locally
4. `apps/android/local.properties` generated locally through Varlock

Generate the local config:

```bash
bun install
bun run android:config
```

For release preparation:

```bash
bun run android:config:production
```

`local.properties` is gitignored and should be kept local to your machine.

## Generated values

The generated file provides the same product-facing values already used on iOS.
Do not document or hand-maintain those values in this public repository; update the private Varlock/Infisical source instead.

## Build locally

From `apps/android`:

```bash
./gradlew --no-daemon assembleDebug
```

Run unit tests:

```bash
./gradlew --no-daemon testDebugUnitTest
```

Build instrumented tests:

```bash
./gradlew --no-daemon assembleAndroidTest
```

If you have an emulator or device connected:

```bash
./gradlew --no-daemon connectedDebugAndroidTest
```

## Notes

- Gradle still accepts environment-variable overrides, but the normal local workflow should use `local.properties`.
- The auth callback intent filter now follows the generated callback scheme and host instead of hardcoded values.
- Use `local` for debug builds and `production` for release preparation.
- If `local.properties` already contains `sdk.dir`, `ndk.dir`, or `cmake.dir`, the generator preserves those entries.
