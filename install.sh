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
REINSTALL=0
DO_UNINSTALL=0

usage() {
    cat <<'EOF'
Usage: ./install.sh [options]

  -y, --yes            Don't prompt for confirmation
  -v, --ref <tag>       Git tag/branch to build
  -j, --jobs <N>         Parallel build jobs
      --prefix <dir>       Install location
      --reinstall              Force rebuild
      --uninstall                    Remove the install and exit
EOF
}