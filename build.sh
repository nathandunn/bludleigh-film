#!/bin/bash
# Make the film: render every frame with Godot's Movie Maker mode, encode it to
# H.264, take a poster, and fill in the player page.
#   ./build.sh [/path/to/godot4]
# Needs Godot 4.4, an X display with OpenGL (xvfb-run + Mesa's software
# rasterizer will do: apt install xvfb libgl1-mesa-dri) and an ffmpeg with
# libx264 (pip install imageio-ffmpeg gives you one). The full film is ~6
# minutes, ~9,000 frames; with software GL on two cores that is about an hour,
# so this is run on purpose, not by the commit hook (see .githooks/pre-commit).
# It renders a scene at a time into $WORK (default /tmp/bludleigh-chunks) and
# skips scenes already rendered, so a killed build picks up where it stopped;
# delete $WORK (or a chunk) to re-render after a change.
set -euo pipefail
GODOT="${1:-godot4}"
RES="${RES:-1920x1080}"
CRF="${CRF:-20}"
cd "$(dirname "$0")"
export HOME="${HOME:-/root}"
FFMPEG="${FFMPEG:-$(python3 -c 'import imageio_ffmpeg as f; print(f.get_ffmpeg_exe())' 2>/dev/null || command -v ffmpeg)}"
"$FFMPEG" -hide_banner -encoders 2>/dev/null | grep -q libx264 || { echo "build: need an ffmpeg with libx264 (pip install imageio-ffmpeg)" >&2; exit 1; }

work="${WORK:-/tmp/bludleigh-chunks}"   # kept, so a re-run resumes
mkdir -p "$work" web
"$GODOT" --headless --path project --import > /dev/null 2>&1 || true

echo "build: checking the timeline..." >&2
"$GODOT" --headless --path project -- --check > "$work/check.log" 2>&1 || true
if grep -qE "SCRIPT ERROR|Parse Error" "$work/check.log" || ! grep -q "^FILM COMPLETE" "$work/check.log"; then
	grep -E "SCRIPT ERROR|Parse Error" "$work/check.log" | head >&2 || true
	echo "build: the timeline check failed (log: $work/check.log)" >&2
	exit 1
fi
grep "^FILM COMPLETE" "$work/check.log" >&2

echo "build: auditing the lettering at $RES..." >&2
xvfb-run -a -s "-screen 0 ${RES}x24" env LIBGL_ALWAYS_SOFTWARE=1 \
	"$GODOT" --display-driver x11 --rendering-driver opengl3 --resolution "$RES" --path project -- --audit \
	> "$work/audit.log" 2>&1 || true
if grep -qE "SCRIPT ERROR|Parse Error|^LAYOUT" "$work/audit.log" || ! grep -q "0 layout problems" "$work/audit.log"; then
	grep -E "SCRIPT ERROR|Parse Error|^LAYOUT" "$work/audit.log" | head >&2 || true
	echo "build: the lettering audit failed (log: $work/audit.log)" >&2
	exit 1
fi
grep "^FILM COMPLETE" "$work/audit.log" >&2

# Render scene by scene (resumable), then stitch: the chunks share a codec, so
# ffmpeg's concat demuxer joins them without touching a frame before the one
# real encode below. Chapter times come from each chunk's log, offset by the
# frames before it.
echo "build: rendering the film at $RES, scene by scene (an hour or so with software GL)..." >&2
WORK="$work" RES="$RES" bash tools/render-chunks.sh "$GODOT" || { echo "build: render failed" >&2; exit 1; }
: > "$work/list.txt"
: > "$work/render.log"
offset=0
for f in $(ls "$work"/chunk_*.avi | sort -t_ -k2 -n); do
	k="$(basename "$f" .avi | cut -d_ -f2)"
	echo "file '$f'" >> "$work/list.txt"
	python3 - "$work/chunk_$k.log" "$offset" >> "$work/render.log" <<'EOF2'
import sys
log, off = sys.argv[1], int(sys.argv[2])
for line in open(log):
    if line.startswith("CHAPTER"):
        _, t, name = line.rstrip("\n").split(" ", 2)
        print("CHAPTER %.2f %s" % (float(t) + off / 24.0, name))
EOF2
	frames="$("$FFMPEG" -hide_banner -i "$f" -map 0:v:0 -c copy -f null - 2>&1 | sed -nE 's/.*frame= *([0-9]+).*/\1/p' | tail -1)"
	offset=$((offset + frames))
done
echo "FILM COMPLETE $(python3 -c "print(round($offset / 24.0, 1))") s ($offset frames at 24 fps)" >> "$work/render.log"

echo "build: encoding..." >&2
"$FFMPEG" -hide_banner -loglevel error -y -f concat -safe 0 -i "$work/list.txt" \
	-c:v libx264 -preset slow -crf "$CRF" -pix_fmt yuv420p -movflags +faststart -an web/bludleigh.mp4
"$FFMPEG" -hide_banner -loglevel error -y -ss 3.2 -i web/bludleigh.mp4 -frames:v 1 -q:v 80 web/poster.webp

# Chapters from the render log -> the player.
secs="$(grep '^FILM COMPLETE' "$work/render.log" | sed -E 's/FILM COMPLETE ([0-9.]+) s.*/\1/')"
minutes="$(python3 -c "s=float('$secs'); print('%d min %02d s' % (s // 60, s % 60))")"
chapters="$(grep '^CHAPTER' "$work/render.log" | python3 -c '
import sys, json
rows = []
for line in sys.stdin:
    _, t, name = line.rstrip("\n").split(" ", 2)
    rows.append([round(float(t), 2), name])
print(json.dumps(rows))')"
python3 - "$chapters" "$minutes" <<'EOF'
import sys
html = open("player/index.html").read().replace("__CHAPTERS__", sys.argv[1]).replace("__MINUTES__", sys.argv[2])
open("web/index.html", "w").write(html)
EOF
echo "made web/bludleigh.mp4 ($(du -h web/bludleigh.mp4 | cut -f1), $minutes), poster and player"
