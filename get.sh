#!/usr/bin/env bash

set -euo pipefail

REPO_URL="${ASEPRITE_INSTALLER_REPO:-https://github.com/othmanelfadil/aseprite-build-script.git}"
REF="${ASEPRITE_INSTALLER_REF:-main}"

if ! command -v git >/dev/null 2>&1; then
    echo "error: git is required to fetch aseprite-installer" >&2
    exit 1
fi

tmp_dir="$(mktemp -d -t aseprite-installer.XXXXXX)"
cleanup() { rm -rf "$tmp_dir"; }
trap cleanup EXIT

echo "fetching aseprite-installer (${REF})..." >&2
git clone --quiet --depth 1 --branch "$REF" "$REPO_URL" "$tmp_dir/repo" >&2

exec "$tmp_dir/repo/install.sh" "$@"