#!/usr/bin/env bash

if [[ -n "${_ASEPRITE_INSTALLER_SKIA_SH:-}" ]]; then
    return 0
fi

_ASEPRITE_INSTALLER_SKIA_SH=1

SKIA_CACHE_DIR="${SKIA_CACHE_DIR:-$HOME/.cache/aseprite-installer/skia}"

skia_platform_label() {
    case "$OS_KIND" in 
        linux) echo "Linux" ;;
        macos) echo "macOS" ;;
        *) die "unsupported OS for skia prebuilt: $OS_KIND" ;;
    esac
}

skia_read_tag() {
    local source_dir="$1"
    local tag_file="$source_dir/laf/misc/skia-tag.txt"
    [[ -f "$tag_file" ]] || die "cannot find $tag_file"
    tr -d '[:space:]' < "$tag_file"
}

skia_url() {
    local tag="$1"
    local build="${2:-Release}"
    local platform 
    platform=$(skia_platform_label)
}

skia_dir_for_tag() {
    local tag="$1"
    echo "${SKIA_CACHE_DIR}/${tag}-${OS_KIND}-${ARCH}"
}