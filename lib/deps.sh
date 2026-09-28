#!/usr/bin/env bash

if [[ -n "${_ASEPRITE_INSTALLER_DEPS_SH:-}" ]]; then
    return 0
fi
_ASEPRITE_INSTALLER_DEPS_SH=1

_deps_for_dnf()    { echo "gcc-c++ clang libcxx-devel cmake ninja-build unzip curl git ccache libX11-devel libXcursor-devel libXi-devel libXrandr-devel mesa-libGL-devel fontconfig-devel"; }
_deps_for_apt()    { echo "g++ clang cmake ninja-build unzip curl git ccache libx11-dev libxcursor-dev libxi-dev libxrandr-dev libgl1-mesa-dev libfontconfig1-dev"; }
_deps_for_pacman() { echo "gcc clang cmake ninja unzip curl git ccache libx11 libxcursor libxi libxrandr mesa fontconfig libwebp"; }
_deps_for_zypper() { echo "gcc-c++ clang cmake ninja unzip curl git ccache libX11-devel libXcursor-devel libXi-devel libXrandr-devel Mesa-libGL-devel fontconfig-devel"; }
_deps_for_brew()   { echo "cmake ninja ccache"; }

deps_package_list() {
    case "$PKG_MANAGER" in
        dnf)    _deps_for_dnf ;;
        apt)    _deps_for_apt ;;
        pacman) _deps_for_pacman ;;
        zypper) _deps_for_zypper ;;
        brew)   _deps_for_brew ;;
        *) die "unknown package manager, can't determine dependency list" ;;
    esac
}

_pkg_installed() {
    local pkg="$1"
    case "$PKG_MANAGER" in
        dnf) rpm -q "$pkg" >/dev/null 2>&1 ;;
        apt) dpkg -s "$pkg" >/dev/null 2>&1 ;;
        pacman) pacman -Qi "$pkg" >/dev/null 2>&1 ;;
        zypper) rpm -q "$pkg" >/dev/null 2>&1 ;;
        brew) brew list --formula "$pkg" >/dev/null 2>&1 ;;
        *) return 1 ;;
    esac
}

install_dependencies() {
    if [[ "$OS_KIND" == "macos" ]]; then
        if ! has_cmd xcodebuild || ! xcode-select -p >/dev/null 2>&1; then
            log_warn "xcode command line tools not found, requesting install"
            run xcode-select --install || true
            die "re-run this installer once the xcode command line tools finish installing"
        fi
        if ! has_cmd brew; then
            die "homebrew is required to install cmake/ninja on macos, get it from https://brew.sh then re-run"
        fi
    fi
    local all_pkgs missing=()
    all_pkgs=$(deps_package_list)
    for pkg in $all_pkgs; do
        if ! _pkg_installed "$pkg"; then
            missing+=("$pkg")
        fi
    done

    if [[ ${#missing[@]} -eq 0 ]]; then
        return 0
    fi

    log_step "installing dependencies: ${missing[*]}"
    if ! confirm "install ${#missing[@]} package(s) via ${PKG_MANAGER}?"; then
        die "dependencies declined, install them manually and re-run with --skip-deps"
    fi

    case "$PKG_MANAGER" in
        dnf)    run_sudo dnf install -y "${missing[@]}" ;;
        apt)    run_sudo apt-get update && run_sudo apt-get install -y "${missing[@]}" ;;
        pacman) run_sudo pacman -Sy --needed --noconfirm "${missing[@]}" ;;
        zypper) run_sudo zypper install -y "${missing[@]}" ;;
        brew)   run brew install "${missing[@]}" ;;
    esac
}

check_clang_version() {
    [[ "$OS_KIND" == "linux" ]] || return 0
    has_cmd clang || return 0
    local ver 
    ver=$(clang --version 2>/dev/null | head -n1 | grep -oE '[0-9]+' | head -n1 || echo 0)
    if [[ "${ver:-0}" -lt 12 ]]; then
        log_warn "clang ${ver} found, aseprite recommend version 12+ (gcc may still work)"
    fi
}