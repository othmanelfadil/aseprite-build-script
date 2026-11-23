#!/usr/bin/env bash

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"
source "$SCRIPT_DIR/lib/os-detect.sh"
source "$SCRIPT_DIR/lib/deps.sh"
source "$SCRIPT_DIR/lib/skia.sh"
source "$SCRIPT_DIR/lib/build.sh"

install_error_trap

PREFIX="${PREFIX:-$HOME/.local/share/aseprite-installer}"
BIN_DIR="${BIN_DIR:-$HOME/.local/bin}"
REF=""
JOBS=""
BUILD_TYPE="RelWithDebInfo"
SKIP_DEPS=0
REINSTALL=0
ASSUME_YES=0
DO_UNINSTALL=0
PURGE=0
VERBOSE=0

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
      --purge                          With --uninstall, also remove the source and skia cache
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
        --verbose) VERBOSE=1; shift ;;
        --uninstall) DO_UNINSTALL=1; shift ;;
        --purge) PURGE=1; shift ;;
        -h|--help) usage; exit 0 ;;
        *) die "unknown option: $1 (see --help)" ;;
    esac
done
export ASSUME_YES VERBOSE

if [[ "$DO_UNINSTALL" == "1" ]]; then
    uninstall_args=(--prefix "$PREFIX")
    [[ "$ASSUME_YES" == "1" ]] && uninstall_args+=(--yes)
    [[ "$PURGE" == "1" ]] && uninstall_args+=(--purge)
    exec "$SCRIPT_DIR/uninstall.sh" "${uninstall_args[@]}"
fi

SOURCE_DIR="$PREFIX/src"
VERSIONS_DIR="$PREFIX/versions"
MARKER_FILE="$PREFIX/installed-ref"

detect_os
check_skia_platform

init_log_file "$PREFIX/install.log"
log_info "full build output goes to $PREFIX/install.log (use --verbose to see it live)"

# "<ref> <commit> <build type>", fails if the ref can't be resolved yet
wanted_build_id() {
    local ref commit
    ref="${REF:-$(resolve_latest_tag "$SOURCE_DIR")}"
    [[ -n "$ref" ]] || return 1
    commit=$(git -C "$SOURCE_DIR" rev-parse --verify --quiet "$(checkout_target "$SOURCE_DIR" "$ref")^{commit}") || return 1
    echo "$ref $commit $BUILD_TYPE"
}

wanted_id=""
if [[ "$REINSTALL" != "1" && -d "$SOURCE_DIR/.git" ]] && has_cmd git; then
    git -C "$SOURCE_DIR" fetch --tags --prune --quiet origin || log_warn "couldn't reach origin, comparing against the last fetch"
    wanted_id="$(wanted_build_id)" || wanted_id=""
fi

if [[ -n "$wanted_id" && -f "$MARKER_FILE" && "$wanted_id" == "$(cat "$MARKER_FILE")" ]]; then
    log_ok "aseprite ${wanted_id%% *} already installed (${BIN_DIR}/aseprite), use --reinstall to force a rebuild"
    exit 0
fi

avail_gb=$(free_space_gb "$PREFIX")
if [[ -n "$avail_gb" && "$avail_gb" -lt 8 ]]; then
    log_warn "only ~${avail_gb}GB free under $PREFIX, the build typically needs 5-10GB"
    confirm "continue anyway?" || die "aborted"
fi

if [[ "$SKIP_DEPS" != "1" ]]; then
    install_dependencies
    check_clang_version
fi

for tool in git cmake ninja curl unzip; do
    has_cmd "$tool" || die "'$tool' not found, install it or drop --skip-deps"
done

fetch_source "$SOURCE_DIR" "$REF"
ensure_skia "$SOURCE_DIR"
build_id="$RESOLVED_REF $RESOLVED_COMMIT $BUILD_TYPE"
prepare_build_dir "$SOURCE_DIR/build" "$build_id"
build_aseprite "$SOURCE_DIR" "$SKIA_DIR" "$BUILD_TYPE" "$JOBS"

log_step "installing"
version_dir="$VERSIONS_DIR/$RESOLVED_REF"
build_bin_dir="$SOURCE_DIR/build/bin"
[[ -f "$build_bin_dir/aseprite" ]] || die "expected build output at $build_bin_dir/aseprite, but it's missing"

rm -rf "$version_dir"
mkdir -p "$version_dir"
cp -a "$build_bin_dir/." "$version_dir/"

mkdir -p "$BIN_DIR"
ln -sf "$version_dir/aseprite" "$BIN_DIR/aseprite"
echo "$build_id" > "$MARKER_FILE"

if [[ "$OS_KIND" == "linux" ]]; then
    desktop_dir="$HOME/.local/share/applications"
    hicolor_dir="$HOME/.local/share/icons/hicolor"
    icon_dir="$hicolor_dir/256x256/apps"
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

    if has_cmd update-desktop-database; then
         update-desktop-database "$desktop_dir" >/dev/null 2>&1 || true
    fi

fi

log_ok "aseprite ${RESOLVED_REF} installed -> ${BIN_DIR}/aseprite"

if [[ ":$PATH:" != *":$BIN_DIR:"* ]]; then
    log_warn "$BIN_DIR is not on your PATH, add: export PATH=\"$BIN_DIR:\$PATH\""
fi
