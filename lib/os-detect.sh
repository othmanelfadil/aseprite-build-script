#!/usr/bin/env bash

if [[ -n "${_ASEPRITE_INSTALLER_OSDETECT_SH:-}" ]]; then
    return 0
fi
_ASEPRITE_INSTALLER_OSDETECT_SH=1

detect_os() {
    local uname_s
    uname_s="$(uname -s)"

    case "$uname_s" in
        Linux)
            OS_KIND="linux"
            if [[ -r /etc/os-release ]]; then
                #shellcheck disable=SC1091
                source /etc/os-release
                OS_ID="${ID:-unknown}"
                OS_ID_LIKE="${ID_LIKE:-}"
            else
                OS_ID="unknown"
                OS_ID_LIKE=""
            fi
            ;;
        Darwin)
            OS_KIND="macos"
            OS_ID="macos"
            OS_ID_LIKE=""
            ;;
        *)
            die "unsupported OS: $uname_s (this installer supports Linux and macOS)"
            ;;
    esac