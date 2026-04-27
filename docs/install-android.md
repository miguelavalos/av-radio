# AV Radio Android Installation

This guide is for local Android builds while keeping the same local config pattern used by iOS.

## Current Android setup

- Gradle project: `apps/android`
- app module: `apps/android/app`
- generated local config file: `apps/android/local.properties`

## Prerequisites

1. Android Studio Koala or later, or a working local Android SDK + JDK 17
2. `bun` 1.3.13 or later
3. A local `.infisical/bootstrap.env`
4. `apps/android/local.properties` generated locally through Varlock

Generate the local config:

```bash
bun install
cp .infisical/bootstrap.env.example .infisical/bootstrap.env
bun run android:config
```

For release preparation:

```bash
bun run android:config:production
```

`local.properties` is gitignored and should be kept local to your machine.

## Generated values

The generated file should provide the same product-facing values already used on iOS:

```properties
AVRADIO_APPLICATION_ID=com.example.avradio.dev
AVRADIO_AUTH_PROVIDER=clerk
CLERK_PUBLISHABLE_KEY=pk_test_your_publishable_key
AVRADIO_PREMIUM_PRODUCT_IDS=com.example.avradio.pro.monthly,com.example.avradio.pro.yearly
AVRADIO_SUPPORT_EMAIL=support@avalsys.com
AVRADIO_ACCOUNT_MANAGEMENT_URL=https://accounts.avalsys.com/user
AVRADIO_TERMS_URL=https://av-radio.avalsys.com/terms
AVRADIO_PRIVACY_URL=https://av-radio.avalsys.com/privacy
```

Optional auth handoff overrides can also live there:

```properties
AVRADIO_AUTH_WEB_URL=
AVRADIO_AUTH_CALLBACK_SCHEME=avradio
AVRADIO_AUTH_CALLBACK_HOST=auth
```

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
