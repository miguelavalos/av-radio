#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
profile="${1:-local}"
output_mode="${2:-write}"

case "$profile" in
  local)
    bundle_identifier="com.avalsys.avradio.dev"
    ;;
  production)
    bundle_identifier="com.avalsys.avradio"
    ;;
  *)
    echo "Unsupported profile: $profile" >&2
    exit 1
    ;;
esac

eval "$("$repo_root/scripts/resolve-infisical-bootstrap-env.sh" "$profile")"

varlock_bin="$repo_root/node_modules/.bin/varlock"

if [ ! -x "$varlock_bin" ]; then
  echo "varlock CLI is required. Run 'bun install' in $repo_root." >&2
  exit 1
fi

printenv_value() {
  local key="$1"
  "$varlock_bin" printenv --path "$repo_root/" "$key"
}

xcodebuild_url_value() {
  local value="$1"
  printf '%s' "$value" | sed 's#//#/$()/#g'
}

clerk_publishable_key="$(printenv_value CLERK_PUBLISHABLE_KEY)"
premium_product_ids="$(printenv_value AVRADIO_PREMIUM_PRODUCT_IDS)"
support_email="$(printenv_value AVRADIO_SUPPORT_EMAIL)"
avapps_api_base_url="$(printenv_value AVRADIO_AVAPPS_API_BASE_URL)"
account_management_url="$(printenv_value AVRADIO_ACCOUNT_MANAGEMENT_URL)"
terms_url="$(printenv_value AVRADIO_TERMS_URL)"
privacy_url="$(printenv_value AVRADIO_PRIVACY_URL)"
open_source_url="$(printenv_value AVRADIO_OPEN_SOURCE_URL)"

required_values=(
  clerk_publishable_key
  premium_product_ids
  support_email
  account_management_url
  terms_url
  privacy_url
)

for value_name in "${required_values[@]}"; do
  if [ -z "${!value_name:-}" ]; then
    echo "Missing required value: $value_name" >&2
    exit 1
  fi
done

rendered_config="$(cat <<EOF
AVRADIO_BUNDLE_IDENTIFIER = $bundle_identifier
CLERK_PUBLISHABLE_KEY = $clerk_publishable_key
AVRADIO_PREMIUM_PRODUCT_IDS = $premium_product_ids
AVRADIO_SUPPORT_EMAIL = $support_email
AVRADIO_AVAPPS_API_BASE_URL = $(xcodebuild_url_value "$avapps_api_base_url")
AVRADIO_ACCOUNT_MANAGEMENT_URL = $(xcodebuild_url_value "$account_management_url")
AVRADIO_TERMS_URL = $(xcodebuild_url_value "$terms_url")
AVRADIO_PRIVACY_URL = $(xcodebuild_url_value "$privacy_url")
AVRADIO_OPEN_SOURCE_URL = $(xcodebuild_url_value "$open_source_url")
EOF
)"

target_file="$repo_root/apps/ios/Config/Local.xcconfig"

case "$output_mode" in
  write)
    umask 077
    printf '%s\n' "$rendered_config" > "$target_file"
    echo "Wrote $target_file for profile '$profile'."
    ;;
  stdout)
    printf '%s\n' "$rendered_config"
    ;;
  *)
    echo "Unsupported output mode: $output_mode" >&2
    exit 1
    ;;
esac
