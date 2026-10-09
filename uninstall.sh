#!/usr/bin/env bash

PREFIX="${PREFIX:-$HOME/.local/share/aseprite-installer}"
BIN_DIR="${BIN_DIR:-$HOME/.local/bin}"
ASSUME_YES=0

while [[ $# -gt 0 ]]; do
    case "$1" in
        -y|--yes) ASSUME_YES=1; shift ;;
        *) die "unknown option: $1" ;;
    esac
done
export ASSUME_YES

if [[ ! -d "$PREFIX" && ! -L "$BIN_DIR/aseprite" ]]; then
    log_warn "nothing found to uninstall at $PREFIX or $BIN_DIR/aseprite"
    exit 0
fi

confirm "remove aseprite installed via this installer ($PREFIX)?" || die "aborted"

if [[ -L "$BIN_DIR/aseprite" || -f "$BIN_DIR/aseprite" ]]; then
    rm -f "$BIN_DIR/aseprite"
fi

rm -f "$HOME/.local/share/applications/aseprite.desktop"
rm -f "$HOME/.local/share/icons/hicolor/256x256/apps/aseprite.png"

if [[ -d "$PREFIX/versions" ]]; then
    rm -rf "$PREFIX/versions"
fi
rm -f "$PREFIX/installed-ref"

log_ok "uninstalled"