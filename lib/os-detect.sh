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
    local m
    if has_cmd arch; then
        m="$(arch)"
    else
        m="$(uname -m)"
    fi
    case "$m" in
        x86_64|amd64) ARCH="x64" ;;
        arm64|aarch64) ARCH="arm64" ;;
        i386|i686) ARCH="x86" ;;
        *) die "unsupported CPU architecture: $m" ;;
    esac

    PKG_MANAGER="unknown"
    if [[ "$OS_KIND" == "macos" ]]; then
        PKG_MANAGER="brew"
    else
    # to add more distros 
        case "$OS_ID" in
            fedora|rhel|centos|rocky|almalinux) PKG_MANAGER="dnf" ;;
            ubuntu|debian|linuxmint|pop) PKG_MANAGER="apt" ;;
            arch|manjaro|endeavouros) PKG_MANAGER="pacman" ;;
            opensuse*|sles) PKG_MANAGER="zypper" ;;
            *)
+                if [[ "$OS_ID_LIKE" == *fedora* || "$OS_ID_LIKE" == *rhel* ]]; then
+                    PKG_MANAGER="dnf"
+                elif [[ "$OS_ID_LIKE" == *debian* ]]; then
+                    PKG_MANAGER="apt"
+                elif [[ "$OS_ID_LIKE" == *arch* ]]; then
+                    PKG_MANAGER="pacman"
+                elif [[ "$OS_ID_LIKE" == *suse* ]]; then
+                    PKG_MANAGER="zypper"
+                elif has_cmd dnf; then PKG_MANAGER="dnf"
+                elif has_cmd apt-get; then PKG_MANAGER="apt"
+                elif has_cmd pacman; then PKG_MANAGER="pacman"
+                elif has_cmd zypper; then PKG_MANAGER="zypper"
+                fi
+                ;;
        esac
    fi

    export OS_KIND OS_ID ARCH PKG_MANAGER
}