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

fetch_source() {
    local source_dir="$1"
    local ref="$2"

    if [[ -d "$source_dir/.git" ]]; then
        log_step "updating aseprite source"
        run git -C "$source_dir" fetch --tags --prune origin
    else
        log_step "cloning aseprite"
        mkdir -p "$(dirname "$source_dir")"
        run git clone "$ASEPRITE_REPO_URL" "$source_dir"
    fi

    if [[ -z "$ref" ]]; then
        ref=$(resolve_latest_tag "$source_dir")
        [[ -n "$ref" ]] || die "could not resolve a latest release tag, pass --ref <tag|branch> explicitly"
    fi
    log_info "ref: ${ref}"

    run git -C "$source_dir" checkout --force "$ref"

    echo "$ref"
}