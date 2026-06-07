#!/usr/bin/env bash
set -euo pipefail

: "${CASK_TOKEN:?CASK_TOKEN is required}"
: "${VERSION:?VERSION is required}"
: "${SHA256:?SHA256 is required}"
: "${RELEASE_URL:?RELEASE_URL is required}"

HOMEPAGE="${HOMEPAGE:-https://github.com/joelfernandes23/Autoclick}"

cat <<EOF
cask "$CASK_TOKEN" do
  version "$VERSION"
  sha256 "$SHA256"

  url "$RELEASE_URL"
  name "Autoclick"
  desc "Configurable autoclicker"
  homepage "$HOMEPAGE"

  depends_on macos: :mojave

  app "Autoclick.app"
end
EOF
