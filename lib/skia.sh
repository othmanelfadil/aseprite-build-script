#!/usr/bin/env bash

if [[ -n "${_ASEPRITE_INSTALLER_SKIA_SH:-}" ]]; then
    return 0
fi

_ASEPRITE_INSTALLER_SKIA_SH=1

SKIA_CACHE_DIR="${SKIA_CACHE_DIR:-$HOME/.cache/aseprite-installer/skia}"
SKIA_DIR=""

# upstream only publishes these prebuilts, see github.com/aseprite/skia/releases
check_skia_platform() {
    case "${OS_KIND}-${ARCH}" in
        linux-x64|linux-x86|macos-x64|macos-arm64) ;;
        *) die "no prebuilt skia for ${OS_KIND}/${ARCH}, you'd have to build skia yourself (see aseprite's INSTALL.md)" ;;
    esac
}

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
    [[ -f "$tag_file" ]] || die "cannot find $tag_file, did the laf submodule get checked out?"
    tr -d '[:space:]' < "$tag_file"
}

skia_url() {
    local tag="$1"
    local build="${2:-Release}"
    local platform
    platform=$(skia_platform_label)
    echo "https://github.com/aseprite/skia/releases/download/${tag}/Skia-${platform}-${build}-${ARCH}.zip"
}

skia_dir_for_tag() {
    local tag="$1"
    echo "${SKIA_CACHE_DIR}/${tag}-${OS_KIND}-${ARCH}"
}

# sets SKIA_DIR instead of echoing it, same reason as fetch_source
ensure_skia() {
    local source_dir="$1"
    local tag url zip_path dest_dir tmp_dir
    tag=$(skia_read_tag "$source_dir")
    dest_dir=$(skia_dir_for_tag "$tag")
    # shellcheck disable=SC2034  # read by install.sh
    SKIA_DIR="$dest_dir"

    if [[ -d "$dest_dir" && -n "$(ls -A "$dest_dir" 2>/dev/null)" ]]; then
        return 0
    fi

    url=$(skia_url "$tag")
    mkdir -p "$SKIA_CACHE_DIR"
    zip_path="${SKIA_CACHE_DIR}/${tag}-${OS_KIND}-${ARCH}.zip"

    log_step "downloading skia ${tag}"
    if ! curl -fL --retry 2 --retry-delay 2 --progress-bar -o "$zip_path" "$url"; then
        rm -f "$zip_path"
        die "failed to download skia from $url"
    fi

    # dest_dir only appears once it's complete, an interrupted run can't leave a partial cache
    tmp_dir="${dest_dir}.tmp"
    rm -rf "$tmp_dir" "$dest_dir"
    mkdir -p "$tmp_dir"
    unzip -q "$zip_path" -d "$tmp_dir"
    rm -f "$zip_path"
    mv "$tmp_dir" "$dest_dir"
}
