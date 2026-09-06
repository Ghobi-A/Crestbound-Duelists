#!/usr/bin/env bash
# Deterministic visual baseline capture for Crestbound Duelists.
#
#   tools/capture_screenshots.sh [output_dir]
#
# Downloads (and caches) a pinned, checksum-verified Godot build, imports the
# project, then renders one Greymere frame and one Hollow Court command-menu
# frame. Output defaults to docs/visual_refs/.
#
# Requires: curl, unzip, sha512sum, xvfb-run (rendering needs a real GL
# context; --headless cannot rasterize).

set -euo pipefail

GODOT_VERSION="4.3-stable"
GODOT_ARCHIVE="Godot_v${GODOT_VERSION}_linux.x86_64.zip"
GODOT_BINARY="Godot_v${GODOT_VERSION}_linux.x86_64"
GODOT_URL="https://github.com/godotengine/godot/releases/download/${GODOT_VERSION}/${GODOT_ARCHIVE}"
# Official SHA-512 from the 4.3-stable release SHA512-SUMS.txt.
GODOT_SHA512="fd52bb4ba8acc30ca5accd1c566d470ad7282f891ccc0995dfafabcf92bcf76280ce182bf9d80ebd885f3ed2165d01e1fc3f2928436b15498dfbd98656c2a45a"

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CACHE_DIR="${CRESTBOUND_GODOT_CACHE:-$HOME/.cache/crestbound-godot}"
OUT_DIR="$(cd "$(dirname "${1:-$REPO_ROOT/docs/visual_refs}")" && pwd)/$(basename "${1:-visual_refs}")"
# Host window to render into. Defaults to the 1280x720 logical canvas;
# set it to a whole multiple (2560x1440) to check a larger host window.
CAPTURE_RESOLUTION="${CAPTURE_RESOLUTION:-1280x720}"
TARGETS=(boot party_setup overworld battle battle_target)

mkdir -p "$CACHE_DIR" "$OUT_DIR"

if [[ ! -x "$CACHE_DIR/$GODOT_BINARY" ]]; then
	echo "Downloading Godot $GODOT_VERSION ..."
	curl -sSL -o "$CACHE_DIR/$GODOT_ARCHIVE" "$GODOT_URL"
	echo "${GODOT_SHA512}  ${CACHE_DIR}/${GODOT_ARCHIVE}" | sha512sum -c -
	unzip -o -q "$CACHE_DIR/$GODOT_ARCHIVE" -d "$CACHE_DIR"
	chmod +x "$CACHE_DIR/$GODOT_BINARY"
else
	echo "Using cached Godot at $CACHE_DIR/$GODOT_BINARY"
fi

GODOT="$CACHE_DIR/$GODOT_BINARY"
"$GODOT" --version

# Force software GL so results do not depend on host graphics drivers.
export LIBGL_ALWAYS_SOFTWARE=1
export GALLIUM_DRIVER=llvmpipe

# Godot resolves user:// under $XDG_DATA_HOME, so a save written by an
# earlier capture leaks into the next one: once crestbound_save.json
# exists the boot menu offers "Continue" instead of "Controls" and the
# baseline silently stops matching. Give every run a throwaway data home
# so captures are reproducible from a clean slate.
SAVE_SANDBOX="$(mktemp -d)"
trap 'rm -rf "$SAVE_SANDBOX"' EXIT
export XDG_DATA_HOME="$SAVE_SANDBOX"

echo "Importing project ..."
xvfb-run -a "$GODOT" --path "$REPO_ROOT/game" --import --quit-after 200 >/dev/null 2>&1 || true

for target in "${TARGETS[@]}"; do
	echo "Capturing $target ..."
	# Drive the window at the internal resolution so the captured viewport
	# texture is the 1280x720 game canvas itself, not a scaled OS window.
	xvfb-run -a "$GODOT" --path "$REPO_ROOT/game" --fixed-fps 60 \
		--resolution "$CAPTURE_RESOLUTION" \
		"res://scenes/tools/screenshot_capture.tscn" \
		-- "--target=$target" "--out=$OUT_DIR"
done

echo
echo "Screenshots written to $OUT_DIR:"
ls -1 "$OUT_DIR"/*.png
