#!/usr/bin/env bash

if [[ -n "${_ASEPRITE_INSTALLER_DEPS_SH:-}" ]]; then
    return 0
fi
_ASEPRITE_INSTALLER_DEPS_SH=1

_deps_for_dnf()    { echo "gcc-c++ clang libcxx-devel cmake ninja-build unzip curl git libX11-devel libXcursor-devel libXi-devel libXrandr-devel mesa-libGL-devel fontconfig-devel"; }
_deps_for_apt()    { echo "g++ clang cmake ninja-build unzip curl git libx11-dev libxcursor-dev libxi-dev libxrandr-dev libgl1-mesa-dev libfontconfig1-dev"; }
_deps_for_pacman() { echo "gcc clang cmake ninja unzip curl git libx11 libxcursor libxi libxrandr mesa fontconfig libwebp"; }
_deps_for_zypper() { echo "gcc-c++ clang cmake ninja unzip curl git libX11-devel libXcursor-devel libXi-devel libXrandr-devel Mesa-libGL-devel fontconfig-devel"; }
_deps_for_brew()   { echo "cmake ninja"; }

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
    local pkg='$1'
    case "$PKG_MANAGER" in
        dnf) rpm -q "$pkg" >/dev/null 2>&1 ;;
        apt) dpkg -s "$pkg" >/dev/null 2>&1 ;;
        pacman) pacman "$pkg" >/dev/null 2>&1 ;;
        zypper) rpm -q "$pkg" >/dev/null 2>&1 ;;
        brew) brew list --formula "$pkg" >/dev/null 2>&1 ;;
        *) return 1 ;;
        esac
}