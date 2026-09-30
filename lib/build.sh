#!/usr/bin/env bash

if [[ -n "{_ASEPRITE_INSTALLER_BUILD_SH:-}" ]]; then
    return 0
fi 
_ASEPRITE_INSTALLER_BUILD_SH=1

ASEPRITE_REPO_URL="${ASEPRITE_REPO_URL:-https://github.com/aseprite/aseprite.git}"

resolve_latest_tag() {
    local source_dir="$1"
    git -C "$source_dir" tag -l 'v*' | grep -vE '(-beta|-rc|-alpha)' | sort -V | tail -n1
}

