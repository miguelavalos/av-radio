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

if ! command -v infisical >/dev/null 2>&1; then
  echo "infisical CLI is required but was not found in PATH." >&2
  exit 1
fi

eval "$("$repo_root/scripts/resolve-infisical-bootstrap-env.sh" "$profile")"

domain="${INFISICAL_SITE_URL:-https://app.infisical.com}"
api_domain="$domain"
if [[ "$api_domain" != */api ]]; then
  api_domain="${api_domain%/}/api"
fi

token="$(
  infisical login \
    --method universal-auth \
    --client-id "$INFISICAL_CLIENT_ID" \
    --client-secret "$INFISICAL_CLIENT_SECRET" \
    --domain "$api_domain" \
    --plain \
    --silent
)"

secret_payload="$(
  infisical export \
    --token "$token" \
    --domain "$api_domain" \
    --env "$INFISICAL_ENVIRONMENT" \
    --projectId "$INFISICAL_PROJECT_ID" \
    --format dotenv \
    --silent
)"

dotenv_value() {
  local key="$1"
  printf '%s\n' "$secret_payload" | sed -n "s/^${key}='\\(.*\\)'$/\\1/p" | head -n 1
}

xcodebuild_url_value() {
  local value="$1"
  printf '%s' "$value" | sed 's#//#/$()/#g'
}

clerk_publishable_key="$(dotenv_value CLERK_PUBLISHABLE_KEY)"
if [ -z "$clerk_publishable_key" ]; then
  clerk_publishable_key="$(dotenv_value EXPO_PUBLIC_CLERK_PUBLISHABLE_KEY)"
fi

premium_product_ids="$(dotenv_value AVRADIO_PREMIUM_PRODUCT_IDS)"
support_email="$(dotenv_value AVRADIO_SUPPORT_EMAIL)"
account_management_url="$(dotenv_value AVRADIO_ACCOUNT_MANAGEMENT_URL)"
terms_url="$(dotenv_value AVRADIO_TERMS_URL)"
privacy_url="$(dotenv_value AVRADIO_PRIVACY_URL)"

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
AVRADIO_ACCOUNT_MANAGEMENT_URL = $(xcodebuild_url_value "$account_management_url")
AVRADIO_TERMS_URL = $(xcodebuild_url_value "$terms_url")
AVRADIO_PRIVACY_URL = $(xcodebuild_url_value "$privacy_url")
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
