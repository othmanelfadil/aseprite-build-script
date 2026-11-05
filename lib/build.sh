#!/usr/bin/env bash

if [[ -n "${_ASEPRITE_INSTALLER_BUILD_SH:-}" ]]; then
    return 0
fi
_ASEPRITE_INSTALLER_BUILD_SH=1

ASEPRITE_REPO_URL="${ASEPRITE_REPO_URL:-https://github.com/aseprite/aseprite.git}"

resolve_latest_tag() {
    local source_dir="$1"
    git -C "$source_dir" tag -l 'v*' | { grep -vE '(-beta|-rc|-alpha)' || true; } | sort -V | tail -n1
}

RESOLVED_REF=""

checkout_target() {
    local source_dir="$1" ref="$2"
    if git -C "$source_dir" show-ref --verify --quiet "refs/remotes/origin/$ref"; then
        echo "origin/$ref"
    else
        echo "$ref"
    fi
}

# only the ref goes to stdout, git output goes to stderr so ref=$(fetch_source) doesn't pick up submodule's status lines
fetch_source() {
    local source_dir="$1"
    local ref="$2"

    if [[ -d "$source_dir/.git" ]]; then
        log_step "updating aseprite source"
        run_logged git -C "$source_dir" fetch --tags --prune --progress origin
    else
        log_step "cloning aseprite"
        mkdir -p "$(dirname "$source_dir")"
        run_logged git clone --progress "$ASEPRITE_REPO_URL" "$source_dir"
    fi

    if [[ -z "$ref" ]]; then
        ref=$(resolve_latest_tag "$source_dir")
        [[ -n "$ref" ]] || die "could not resolve a latest release tag, pass --ref <tag|branch> explicitly"
    fi
    log_info "ref: ${ref}"

    run_logged git -C "$source_dir" checkout --force --detach "$(checkout_target "$source_dir" "$ref")"
    log_step "fetching submodules"
    run_logged git -C "$source_dir" submodule sync --recursive
    run_logged git -C "$source_dir" submodule update --init --force --recursive --progress

    RESOLVED_REF="$ref"
}

build_aseprite() {
    local source_dir="$1"
    local skia_dir="$2"
    local build_type="${3:-RelWithDebInfo}"
    local jobs="${4:-}"
    local build_dir="$source_dir/build"

    log_step "building (${build_type})"
    # without this a failed build leaves the previous binary here and passes the check below
    rm -f "$build_dir/bin/aseprite"
    has_cmd ccache && log_info "ccache found, rebuilds after this one will be faster"

    if [[ "$OS_KIND" == "macos" ]]; then
        if [[ -x "$source_dir/build.sh" ]] && try_upstream_auto_build "$source_dir" "$skia_dir" "$jobs"; then
            return 0
        fi
        log_warn "build.sh --auto unavailable, falling back to manual mode"
    fi

    local -a cmake_args=(
        -B "$build_dir" -S "$source_dir" -G Ninja
        "-DCMAKE_BUILD_TYPE=${build_type}"
        -DLAF_BACKEND=skia
        "-DSKIA_DIR=${skia_dir}"
    )

    case "$OS_KIND" in
        linux)
            cmake_args+=(
                "-DSKIA_LIBRARY_DIR=${skia_dir}/out/Release-x64"
                "-DSKIA_LIBRARY=${skia_dir}/out/Release-x64/libskia.a"
                -DCMAKE_CXX_FLAGS:STRING=-stdlib=libstdc++
                -DCMAKE_EXE_LINKER_FLAGS:STRING=-stdlib=libstdc++
            )
            export CC="${CC:-clang}"
            export CXX="${CXX:-clang++}"
            ;;
        macos)
            local lib_subdir="Release-x64"
            [[ "$ARCH" == "arm64" ]] && lib_subdir="Release-arm64"
            cmake_args+=(
                "-DCMAKE_OSX_ARCHITECTURES=${ARCH/x64/x86_64}"
                "-DSKIA_LIBRARY_DIR=${skia_dir}/out/${lib_subdir}"
                "-DSKIA_LIBRARY=${skia_dir}/out/${lib_subdir}/libskia.a"
            )
            if [[ "$ARCH" == "arm64" ]]; then
                cmake_args+=(-DCMAKE_OSX_DEPLOYMENT_TARGET=11.0 -DPNG_ARM_NEON:STRING=on)
            else
                cmake_args+=(-DCMAKE_OSX_DEPLOYMENT_TARGET=10.14)
            fi
            ;;
    esac

    log_info "configuring..."
    run_logged cmake "${cmake_args[@]}"

    local -a ninja_args=(-C "$build_dir" aseprite)
    [[ -n "$jobs" ]] && ninja_args=(-j "$jobs" "${ninja_args[@]}")
    run_ninja_with_bar "${ninja_args[@]}"

    [[ -f "$build_dir/bin/aseprite" ]] || die "build finished but $build_dir/bin/aseprite was not produced"
}

try_upstream_auto_build() {
    local source_dir="$1" skia_dir="$2" jobs="$3"
    local deps_dir="$HOME/deps"
    local tag
    tag=$(skia_read_tag "$source_dir")
    mkdir -p "$deps_dir"
    if [[ ! -e "$deps_dir/skia-$tag" ]]; then
        ln -s "$skia_dir" "$deps_dir/skia-$tag" 2>/dev/null || return 1
    fi
    (
        cd "$source_dir" || exit 1
        [[ -n "$jobs" ]] && export CMAKE_BUILD_PARALLEL_LEVEL="$jobs"
        export NINJA_STATUS="[%p %f/%t] "
        run_logged ./build.sh --auto --norun
    )
}
