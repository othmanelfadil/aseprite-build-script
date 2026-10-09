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