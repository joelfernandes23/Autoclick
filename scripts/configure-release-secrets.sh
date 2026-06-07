#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  scripts/configure-release-secrets.sh \
    --certificate /path/to/DeveloperIDApplication.p12 \
    --developer-id "Developer ID Application: Example Name (TEAMID)" \
    --app-store-key-id ABC123DEFG \
    --app-store-issuer-id 00000000-0000-0000-0000-000000000000 \
    --app-store-key /path/to/AuthKey_ABC123DEFG.p8

Options:
  --repo OWNER/REPO                 GitHub repository. Defaults to joelfernandes23/Autoclick.
  --certificate PATH                Developer ID Application certificate exported as .p12.
  --certificate-password VALUE      Password for the .p12. Prompts securely when omitted.
  --keychain-password VALUE         Temporary CI keychain password. Generated when omitted.
  --developer-id VALUE              Codesigning identity name.
  --app-store-key-id VALUE          App Store Connect API key id.
  --app-store-issuer-id VALUE       App Store Connect issuer id.
  --app-store-key PATH              App Store Connect API private key .p8 file.
  -h, --help                        Show this help text.

The script sets:
  MACOS_CERTIFICATE_P12
  MACOS_CERTIFICATE_PASSWORD
  MACOS_KEYCHAIN_PASSWORD
  DEVELOPER_ID_APPLICATION
  APP_STORE_CONNECT_API_KEY_ID
  APP_STORE_CONNECT_ISSUER_ID
  APP_STORE_CONNECT_API_KEY_P8
EOF
}

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Missing required command: $1" >&2
    exit 1
  fi
}

require_file() {
  local path="$1"
  local label="$2"

  if [[ -z "$path" || ! -f "$path" ]]; then
    echo "$label file does not exist: $path" >&2
    exit 1
  fi
}

prompt_secret() {
  local prompt="$1"
  local value=""

  read -r -s -p "$prompt: " value
  echo >&2
  printf "%s" "$value"
}

generate_password() {
  if command -v openssl >/dev/null 2>&1; then
    openssl rand -base64 32
  else
    uuidgen
  fi
}

REPO="joelfernandes23/Autoclick"
CERTIFICATE_PATH=""
CERTIFICATE_PASSWORD="${MACOS_CERTIFICATE_PASSWORD:-}"
KEYCHAIN_PASSWORD="${MACOS_KEYCHAIN_PASSWORD:-}"
DEVELOPER_ID="${DEVELOPER_ID_APPLICATION:-}"
APP_STORE_KEY_ID="${APP_STORE_CONNECT_API_KEY_ID:-}"
APP_STORE_ISSUER_ID="${APP_STORE_CONNECT_ISSUER_ID:-}"
APP_STORE_KEY_PATH=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --repo)
      REPO="$2"
      shift 2
      ;;
    --certificate)
      CERTIFICATE_PATH="$2"
      shift 2
      ;;
    --certificate-password)
      CERTIFICATE_PASSWORD="$2"
      shift 2
      ;;
    --keychain-password)
      KEYCHAIN_PASSWORD="$2"
      shift 2
      ;;
    --developer-id)
      DEVELOPER_ID="$2"
      shift 2
      ;;
    --app-store-key-id)
      APP_STORE_KEY_ID="$2"
      shift 2
      ;;
    --app-store-issuer-id)
      APP_STORE_ISSUER_ID="$2"
      shift 2
      ;;
    --app-store-key)
      APP_STORE_KEY_PATH="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

require_command gh
require_command base64
require_file "$CERTIFICATE_PATH" "Certificate"
require_file "$APP_STORE_KEY_PATH" "App Store Connect API key"

if [[ -z "$DEVELOPER_ID" ]]; then
  echo "--developer-id is required." >&2
  exit 1
fi

if [[ -z "$APP_STORE_KEY_ID" ]]; then
  echo "--app-store-key-id is required." >&2
  exit 1
fi

if [[ -z "$APP_STORE_ISSUER_ID" ]]; then
  echo "--app-store-issuer-id is required." >&2
  exit 1
fi

if [[ -z "$CERTIFICATE_PASSWORD" ]]; then
  CERTIFICATE_PASSWORD="$(prompt_secret "Certificate password")"
fi

if [[ -z "$KEYCHAIN_PASSWORD" ]]; then
  KEYCHAIN_PASSWORD="$(generate_password)"
fi

echo "Setting release secrets for $REPO..."

base64 < "$CERTIFICATE_PATH" | tr -d '\n' | gh secret set MACOS_CERTIFICATE_P12 --repo "$REPO"
gh secret set MACOS_CERTIFICATE_PASSWORD --repo "$REPO" --body "$CERTIFICATE_PASSWORD"
gh secret set MACOS_KEYCHAIN_PASSWORD --repo "$REPO" --body "$KEYCHAIN_PASSWORD"
gh secret set DEVELOPER_ID_APPLICATION --repo "$REPO" --body "$DEVELOPER_ID"
gh secret set APP_STORE_CONNECT_API_KEY_ID --repo "$REPO" --body "$APP_STORE_KEY_ID"
gh secret set APP_STORE_CONNECT_ISSUER_ID --repo "$REPO" --body "$APP_STORE_ISSUER_ID"
gh secret set APP_STORE_CONNECT_API_KEY_P8 --repo "$REPO" < "$APP_STORE_KEY_PATH"

echo "Release secrets configured."
gh secret list --repo "$REPO"
