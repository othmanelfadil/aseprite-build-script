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
        -h|--help) usage; exit 0 ;;
        *) die "unknown option: $1 (see --help)" ;;
    esac
done
export ASSUME_YES VERBOSE

SOURCE_DIR="$PREFIX/src"
VERSIONS_DIR="$PREFIX/versions"
MARKER_FILE="$PREFIX/installed-ref"

detect_os

init_log_file "$PREFIX/install.log"
log_info "full build output goes to $PREFIX/install.log (use --verbose to see it live)"

avail_gb=$(free_space_gb "$HOME")
if [[ -n "$avail_gb" && "$avail_gb" -lt 8 ]]; then
    log_warn "only ~${avail_gb}GB free under \$HOME, the build typically needs 5-10GB"
    confirm "continue anyway?" || die "aborted"
fi

if [[ "$SKIP_DEPS" != "1" ]]; then
    install_dependencies
    check_clang_version
fi

if [[ "$REINSTALL" != "1" && -f "$MARKER_FILE" ]]; then
    installed_ref="$(cat "$MARKER_FILE")"
    if [[ -z "$REF" || "$REF" == "$installed_ref" ]]; then
        if [[ -z "$REF" ]]; then
            if [[ -d "$SOURCE_DIR/.git" ]]; then
                git -C "$SOURCE_DIR" fetch --tags --quiet origin || true
                latest=$(resolve_latest_tag "$SOURCE_DIR")
                if [[ -n "$latest" && "$latest" != "$installed_ref" ]]; then
                    log_info "${installed_ref} -> ${latest}"
                    REF="$latest"
                fi
            fi
        fi
        if [[ -z "$REF" || "$REF" == "$installed_ref" ]]; then
            log_ok "aseprite ${installed_ref} already installed (${BIN_DIR}/aseprite), use --reinstall to force a rebuild"
            exit 0
        fi
    fi
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
    if [[ ! -f "$hicolor_dir/index.theme" ]]; then
        existing_dirs=()
        while IFS= read -r -d '' d; do
            existing_dirs+=("$d")
        done < <(find "$hicolor_dir" -mindepth 2 -maxdepth 2 -type d -printf '%P\0' 2>/dev/null | sort -z)
        if [[ ${#existing_dirs[@]} -eq 0 ]]; then
            existing_dirs=("256x256/apps")
        fi
        {
            echo "[Icon Theme]"
            echo "Name=Hicolor"
            echo "Comment=Fallback icon theme"
            echo "Hidden=true"
            printf 'Directories=%s\n' "$(IFS=,; echo "${existing_dirs[*]}")"
            for d in "${existing_dirs[@]}"; do
                size="${d%%/*}"; size="${size%%x*}"
                context="${d#*/}"
                case "$context" in
                    apps) context="Applications" ;;
                    mimetypes) context="MimeTypes" ;;
                    *) context="Applications" ;;
                esac
                echo ""
                echo "[$d]"
                echo "Size=${size}"
                echo "Context=${context}"
                echo "Type=Fixed"
            done
        } > "$hicolor_dir/index.theme"
    fi
    if has_cmd gtk-update-icon-cache; then
        gtk-update-icon-cache -q -f "$hicolor_dir" >/dev/null 2>&1 || true
    fi
fi

log_ok "aseprite ${resolved_ref} installed -> ${BIND_DIR}/aseprite"