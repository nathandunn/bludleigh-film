#!/bin/bash
# Render the film one scene at a time into $WORK/chunk_K.avi, skipping chunks
# already done, so a killed render resumes where it stopped. Each chunk ends
# with the paper up over the cut and the next begins the same way, so they
# join seamlessly. build.sh stitches them.
#   WORK=/tmp/film/chunks tools/render-chunks.sh [/path/to/godot4]
set -uo pipefail
GODOT="${1:-godot4}"
RES="${RES:-1920x1080}"
WORK="${WORK:-/tmp/bludleigh-chunks}"
cd "$(dirname "$0")/.."
export HOME="${HOME:-/root}"
mkdir -p "$WORK"
"$GODOT" --headless --path project --import > /dev/null 2>&1 || true
n="$("$GODOT" --headless --path project -- --check 2>/dev/null | sed -nE 's/^film: [0-9]+ pages, ([0-9]+) scenes.*/\1/p')"
[ -n "$n" ] || { echo "render-chunks: could not count scenes" >&2; exit 1; }
for k in $(seq 0 $((n - 1))); do
	log="$WORK/chunk_$k.log"
	if [ -s "$WORK/chunk_$k.avi" ] && grep -q "^FILM COMPLETE" "$log" 2>/dev/null; then
		echo "render-chunks: chunk $k done already" >&2
		continue
	fi
	echo "render-chunks: chunk $k of $n..." >&2
	rm -f "$WORK/chunk_$k.avi"
	xvfb-run -a -s "-screen 0 ${RES}x24" env LIBGL_ALWAYS_SOFTWARE=1 \
		"$GODOT" --display-driver x11 --rendering-driver opengl3 --resolution "$RES" \
		--write-movie "$WORK/chunk_$k.avi" --fixed-fps 24 --path project -- --chunk="$k" 2>&1 \
		| grep -E "^(film:|CHAPTER|LAYOUT|FILM)|SCRIPT ERROR|Parse Error" > "$log"
	if ! grep -q "^FILM COMPLETE" "$log" || grep -qE "SCRIPT ERROR|Parse Error|^LAYOUT" "$log"; then
		echo "render-chunks: chunk $k failed (log: $log)" >&2
		exit 1
	fi
	grep "^FILM COMPLETE" "$log" | sed "s/^/render-chunks: chunk $k: /" >&2
done
echo "render-chunks: all $n chunks in $WORK" >&2
