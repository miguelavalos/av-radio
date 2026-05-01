#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

for forbidden_path in \
  ".infisical/bootstrap.env.example" \
  ".infisical/bootstrap.env" \
  ".env" \
  ".env.local" \
  ".env.example" \
  "apps/ios/Config/Local.xcconfig" \
  "apps/ios/Config/Local.xcconfig.example" \
  "apps/android/local.properties"
do
  if git ls-files --error-unmatch "$forbidden_path" >/dev/null 2>&1 && [ -e "$forbidden_path" ]; then
    printf 'Forbidden tracked config artifact: %s\n' "$forbidden_path" >&2
    exit 1
  fi
done

content_pattern='pk_(live|test)_[A-Za-z0-9_]+|sk_(live|test)_[A-Za-z0-9_]+|real_publishable_key|CLERK_SECRET_KEY=|AVAPPS_SUBSCRIPTION_SYNC_TOKEN=|https://api\.av-apps\.avalsys\.com|avapps_api_base_url=.*127\.0\.0\.1:8788'

if git ls-files -z \
  | grep -z -v '^scripts/check-public-config-hygiene\.sh$' \
  | xargs -0 rg -n --no-messages "$content_pattern"; then
  printf 'Forbidden config/secrets pattern found in tracked files.\n' >&2
  exit 1
fi

if git ls-files -z '*env.schema' '*/.env.schema' \
  | xargs -0 rg -n --no-messages 'AVAPPS_SIGNED_IN_SMOKE_TOKEN'; then
  printf 'Forbidden persistent signed-in smoke token schema entry found. Use the private runtime prompt wrapper instead.\n' >&2
  exit 1
fi

printf 'Public config hygiene check passed.\n'
