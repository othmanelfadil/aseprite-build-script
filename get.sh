#!/usr/bin/env bash

set -euo pipefail

main() {
    local repo_url="${ASEPRITE_INSTALLER_REPO:-https://github.com/othmanelfadil/aseprite-build-script.git}"
    local ref="${ASEPRITE_INSTALLER_REF:-main}"

    if ! command -v git >/dev/null 2>&1; then
        echo "error: git is required to fetch aseprite-installer" >&2
        exit 1
    fi

    tmp_dir="$(mktemp -d -t aseprite-installer.XXXXXX)"
    trap 'rm -rf "$tmp_dir"' EXIT

    echo "fetching aseprite-installer (${ref})..." >&2
    git clone --quiet --depth 1 --branch "$ref" "$repo_url" "$tmp_dir/repo" >&2

    "$tmp_dir/repo/install.sh" "$@"
}

main "$@"
