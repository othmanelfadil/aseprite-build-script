#!/usr/bin/env bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"
source "$SCRIPT_DIR/lib/os-detect.sh"
source "$SCRIPT_DIR/lib/deps.sh"
source "$SCRIPT_DIR/lib/skia.sh"
source "$SCRIPT_DIR/lib/build.sh"

PREFIX="${PREFIX:-$HOME/.local/share/aseprite-installer}"
BIN_DIR="${BIN_DIR:-$HOME/.local/bin}"
REF=""
JOBS=""
BUILD_TYPE="RelWithDebInfo"
SKIP_DEPS=0
REINSTALL=0
ASSUME_YES=0
DO_UNINSTALL=0

usage() {
    cat <<'EOF'
Usage: ./install.sh [options]

  -y, --yes            Don't prompt for confirmation
  -v, --ref <tag>       Git tag/branch to build
  -j, --jobs <N>         Parallel build jobs
      --prefix <dir>       Install location
      --skip-deps            Skip OS package dependency installation
      --reinstall              Force rebuild
      --debug                    Debug build
      --uninstall                    Remove the install and exit
  -h, --help                          Show this help
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        -y|--yes) ASSUME_YES=1; shift ;;
        -v|--ref) REF="${2:?--ref requires a value}"; shift 2 ;;
        -j|--jobs) JOBS="${2:?--jobs requires a value}"; shift 2 ;;
        --prefix) PREFIX="${2:?--prefix requires a value}"; shift 2 ;;
        --skip-deps) SKIP_DEPS=1; shift ;;
        --reinstall) REINSTALL=1; shift ;;
        --debug) BUILD_TYPE="Debug"; shift ;;
        --uninstall) DO_UNINSTALL=1; shift ;;
        -h|--help) usage; exit 0 ;;
        *) die "unknown option: $1 (see --help)" ;;
    esac
done
export ASSUME_YES

SOURCE_DIR="$PREFIX/src"
VERSIONS_DIR="$PREFIX/versions"
MARKER_FILE="$PREFIX/installed-ref"

detect_os

if [[ "$SKIP_DEPS" != "1" ]]; then
    install_dependencies
    check_clang_version
fi

resolved_ref=$(fetch_source "$SOURCE_DIR" "$REF")
skia_dir=$(ensure_skia "$SOURCE_DIR")
build_aseprite "$SOURCE_DIR" "$skia_dir" "$BUILD_TYPE" "$JOBS"

log_step "installing"
version_dir="$VERSION_DIR/$resolved_ref"
build_bin_dir="$SOURCE_DIR/build/bin"
[[ -f "$build_bin_dir/aseprite" ]] || die "expected build output at $build_bin_dir/aseprite, but it's missing"

rm -rf "$version_dir"
mkdir -p "$version_dir"
cp -a "$build_bin_dir/." "$version_dir/"

mkdir -p "$BIN_DIR"
ln -sf "$version_dir/aseprite" "$BIN_DIR/aseprite"
echo "$resolved_ref" > "$MARKER_FILE"

if [[ "$OS_KIND" == "linux" ]]; then
    desktop_dir="$HOME/.local/share/applications"
    icon_dir="$HOME/.local/share/icons/hicolor/256x256/apps"
    mkdir -p "$desktop_dir" "$icon_dir"
    icon_src="$SOURCE_DIR/data/icons/ase256.png"
    if [[ -f "$icon_src" ]]; then
        cp -f "$icon_src" "$icon_dir/aseprite.png"
    fi
    cat > "$desktop_dir/aseprite.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=Aseprite
Comment=Animated sprite editor & pixel art tool
Exec=$BIN_DIR/aseprite %f
Icon=aseprite
Terminal=false
Categories=Graphics;2DGraphics;RasterGraphics;
EOF
fi

log_ok "aseprite ${resolved_ref} installed -> ${BIND_DIR}/aseprite"