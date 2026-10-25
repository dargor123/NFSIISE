### Script to build and install SDL2 on ARMHF build platform
### Based the build scripts from https://github.com/JeodC/RHH-Ports repository

set -euo pipefail

SDL_VERSION="2.32.10"
DEPS_DIR="libs"
RHH_DEP_MARKER_DIR="libs_marker"

mkdir -p "$DEPS_DIR"

# _dep_marker <name> <identity...>
#   Marker path for <name>, keyed on everything that would change the build
#   (url, pinned ref, cmake args). Bump any of them and the old marker no
#   longer matches, so the dep rebuilds instead of silently going stale.
_dep_marker() {
    local name=$1
    shift
    local key
    key=$(printf '%s\0' "$@" | md5sum | cut -d' ' -f1)
    echo "$RHH_DEP_MARKER_DIR/$name-$key"
}

# _dep_cached <marker> — true if this exact dep/config is already installed.
_dep_cached() {
    [[ "${RHH_FORCE_DEPS:-0}" != "1" && -f "$1" ]]
}

_dep_mark_built() {
    mkdir -p "$RHH_DEP_MARKER_DIR"
    : > "$1"
}

# GitHub occasionally returns transient HTTP 500s during git clone. Retry with
# backoff so single failures don't abort the whole build.
git_clone_retry() {
    local attempt
    for attempt in 1 2 3 4 5; do
        if git clone "$@"; then
            return 0
        fi
        local delay=$((attempt * 5))
        echo "git clone failed (attempt $attempt); retrying in ${delay}s..." >&2
        sleep "$delay"
    done
    echo "git clone failed after 5 attempts" >&2
    return 1
}

# _build_dep <name> <git-url> <ref> [extra cmake -D args...]
#   Clones into $DEPS_DIR/<name>, checks out <ref>, configures into <name>/build,
#   builds, installs into /usr/local.
_build_dep() {
    local name=$1 url=$2 ref=$3
    shift 3
    local extra_args=("$@")

    local src="$DEPS_DIR/$name"
    local build="$src/build"

    local marker
    marker=$(_dep_marker "$name" "$url" "$ref" "${extra_args[@]}")
    if _dep_cached "$marker"; then
        echo ">>> _build_dep $name: already installed at this ref/config, skipping"
        return 0
    fi

    if [[ -d "$src/.git" ]]; then
        echo ">>> _build_dep $name: already cloned, skipping fetch"
    else
        echo ">>> _build_dep $name: cloning $url"
        git_clone_retry "$url" "$src"
    fi

    # A cached $src may predate a bumped pin, in which case the ref isn't in
    # the local object store yet — fetch and retry before giving up.
    echo ">>> _build_dep $name: checking out $ref"
    if ! git -C "$src" checkout "$ref"; then
        echo ">>> _build_dep $name: $ref not present locally, fetching"
        git -C "$src" fetch --tags --force origin
        git -C "$src" checkout "$ref"
    fi

    echo ">>> _build_dep $name: configuring"
    cmake -S "$src" -B "$build" \
        -DCMAKE_INSTALL_PREFIX=/usr/local \
        -DBUILD_TESTING=OFF \
        "${extra_args[@]}"

    echo ">>> _build_dep $name: building"
    cmake --build "$build" -j"$(nproc)"

    echo ">>> _build_dep $name: installing"
    cmake --install "$build"

    _dep_mark_built "$marker"
}

build_sdl2() {
    _build_dep SDL https://github.com/libsdl-org/SDL.git release-${SDL_VERSION} \
        -DBUILD_SHARED_LIBS=ON \
        -DSDL_TEST=OFF \
        "$@"
}

build_sdl2 \
    -DSDL_VIDEO_OPENGL=OFF \
    -DSDL_VIDEO_OPENGL_GLX=OFF \
    -DSDL_VIDEO_OPENGL_EGL=ON \
    -DSDL_VIDEO_OPENGL_ES2=ON \
    -DSDL_VIDEO_VULKAN=OFF \
    -DSDL_OPENGLES=ON \
    -DSDL_STATIC=OFF \
    -DSDL_SHARED=ON
