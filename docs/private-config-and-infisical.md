# Private Config And Infisical

This repository is public and open source. Anything committed here can become public, so production login, Pro, hosted backend, signing, and account-management config must never be hardcoded in tracked files.

## Rules

1. Do not commit `apps/ios/Config/Local.xcconfig` or Android `local.properties` files.
2. Do not commit `.env`, `.env.*`, `.infisical/bootstrap.env`, signing files, provisioning profiles, keystores, or generated build output.
3. Do not commit real Clerk keys, StoreKit or Play billing secrets, backend tokens, subscription sync tokens, or private service credentials.
4. Do not add production backend URLs as fallback constants in source or scripts. Production values must come from Infisical.
5. Keep public examples generic, for example `https://api.example.com` and `pk_test_your_publishable_key_here`.

## Generate Config

Local development:

```bash
bun install
cp .infisical/bootstrap.env.example .infisical/bootstrap.env
bun run ios:config
```

Production/App Store preparation:

```bash
bun run ios:config:production
```

The production command must fail if Infisical does not provide required values.

## Before Pushing

Run this from the repository root:

```bash
PROD_API_HOST="${PROD_API_HOST:?set production API host}"
escaped_host="$(printf '%s' "$PROD_API_HOST" | sed 's/[.[\*^$()+?{}|]/\\&/g')"
git ls-files -z -- ':!:docs/private-config-and-infisical.md' | xargs -0 rg -n "pk_live|sk_live|CLERK_SECRET_KEY=|AVAPPS_SUBSCRIPTION_SYNC_TOKEN=|$escaped_host" || true
```

If this finds a real production value in a tracked file, remove it before pushing. If a real secret was already pushed, rotate it in the provider and clean the Git history.
