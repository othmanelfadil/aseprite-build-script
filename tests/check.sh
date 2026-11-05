#!/usr/bin/env bash
# runs the real install.sh against a local git repo and fake curl/unzip/cmake/ninja,
# nothing is downloaded or compiled. usage: bash tests/check.sh

set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

ORIGIN="$WORK/origin"
STUBS="$WORK/stubs"
FAILURES=0
HOMES=0

check() {
    local name="$1"
    shift
    if "$@"; then
        printf 'ok    %s\n' "$name"
    else
        printf 'FAIL  %s\n' "$name"
        FAILURES=$((FAILURES + 1))
    fi
}

make_stub() {
    local name="$1" body="${2:-}"
    {
        echo '#!/usr/bin/env bash'
        echo "echo \"$name \$*\" >>\"\$HOME/calls.log\""
        echo "$body"
    } >"$STUBS/$name"
    chmod +x "$STUBS/$name"
}

mkdir -p "$STUBS"
make_stub clang
make_stub cmake
make_stub curl '[[ -z "${FAKE_CURL_FAIL:-}" ]] || exit 22
while [[ $# -gt 0 ]]; do [[ "$1" == -o ]] && : >"$2"; shift; done'
make_stub unzip 'mkdir -p "${@: -1}/out/Release-x64"'
make_stub ninja '[[ -z "${FAKE_NINJA_FAIL:-}" ]] || { echo "FAILED: foo.o"; exit 1; }
while [[ $# -gt 0 ]]; do [[ "$1" == -C ]] && dir="$2"; shift; done
mkdir -p "$dir/bin/data"
echo built >"$dir/bin/aseprite"'

git_origin() { git -C "$ORIGIN" -c user.name=fake -c user.email=fake@example.invalid "$@"; }

git init -q -b main "$ORIGIN"
mkdir -p "$ORIGIN/laf/misc" "$ORIGIN/data/icons"
echo m000-test >"$ORIGIN/laf/misc/skia-tag.txt"
: >"$ORIGIN/data/icons/ase256.png"
git_origin add -A
git_origin commit -qm one
git_origin tag v1.0.0
git_origin commit -q --allow-empty -m two
git_origin tag v2.0.0

new_home() {
    HOMES=$((HOMES + 1))
    TEST_HOME="$WORK/home-$HOMES"
    mkdir -p "$TEST_HOME"
    : >"$TEST_HOME/calls.log"
}

run_install() {
    env -i HOME="$TEST_HOME" PATH="$STUBS:$PATH" ASEPRITE_REPO_URL="$ORIGIN" \
        "FAKE_NINJA_FAIL=${FAKE_NINJA_FAIL:-}" "FAKE_CURL_FAIL=${FAKE_CURL_FAIL:-}" \
        "$ROOT/install.sh" -y --skip-deps "$@" >"$TEST_HOME/out.log" 2>&1
}

installed_ref() { cut -d' ' -f1 "$TEST_HOME/.local/share/aseprite-installer/installed-ref" 2>/dev/null; }
ninja_runs() { grep -c '^ninja ' "$TEST_HOME/calls.log"; }
cmake_runs() { grep -c '^cmake ' "$TEST_HOME/calls.log"; }
bin_works() { [[ -f "$TEST_HOME/.local/bin/aseprite" ]]; }
is_eq() { [[ "$1" == "$2" ]]; }
failed() { ! "$@"; }

new_home
run_install
check "fresh install exits 0" is_eq "$?" 0
check "fresh install picks the latest tag" is_eq "$(installed_ref)" v2.0.0
check "fresh install leaves a working binary" bin_works

run_install
check "second run exits 0" is_eq "$?" 0
check "second run doesn't rebuild" is_eq "$(ninja_runs)" 1

new_home
run_install --ref v1.0.0
FAKE_NINJA_FAIL=1 run_install --ref v2.0.0
check "failed build exits non-zero" failed is_eq "$?" 0
check "failed build keeps the old version" is_eq "$(installed_ref)" v1.0.0

new_home
run_install --ref v1.0.0
run_install --ref does-not-exist
check "bad ref exits non-zero" failed is_eq "$?" 0
check "bad ref keeps the old version" is_eq "$(installed_ref)" v1.0.0

new_home
FAKE_CURL_FAIL=1 run_install
check "failed skia download exits non-zero" failed is_eq "$?" 0
check "failed skia download never reaches cmake" is_eq "$(cmake_runs)" 0

new_home
run_install
run_install --uninstall
check "--uninstall exits 0" is_eq "$?" 0
check "--uninstall removes the binary" failed bin_works
check "--uninstall doesn't build" is_eq "$(ninja_runs)" 1

echo
if [[ "$FAILURES" -gt 0 ]]; then
    echo "$FAILURES check(s) failed"
    exit 1
fi
echo "all checks passed"