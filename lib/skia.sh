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

ensure_skia() {
    local source_dir="$1"
    local tag url zip_path dest_dir
    tag=$(skia_read_tag "$source_dir")
    dest_dir=$(skia_dir_for_tag "$tag")

    if [[ -d "$dest_dir" && -n "$(ls -A "$dest_dir" 2>/dev/null)" ]]; then
        echo "$dest_dir"
        return 0
    fi

    url=$(skia_url "$tag")
    mkdir -p "$SKIA_CACHE_DIR"
    zip_path="${SKIA_CACHE_DIR}/${tag}-${OS_KIND}-${ARCH}.zip"

    log_step "downloading skia ${tag}" >&2
    local attempt
    for attempt in 1 2; do
        if curl -fL --progress-bar -o "$zip_path" "$url"; then
            break
        fi
        rm -f "$zip_path"
        if [[ "$attempt" == 2 ]]; then
            die "failed to download skia from $url after 2 attempts"
        fi
        log_warn "download failed, retrying..." >&2
        sleep 2
    done

    rm -rf "$dest_dir"
    mkdir -p "$dest_dir"
    unzip -q "$zip_path" -d "$dest_dir"
    rm -f "$zip_path"

    echo "$dest_dir"
}
