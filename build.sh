#!/bin/bash
# Make the film: render every frame with Godot's Movie Maker mode, encode it to
# H.264, take a poster, and fill in the player page.
#   ./build.sh [/path/to/godot4]
# Needs Godot 4.4, an X display with OpenGL (xvfb-run + Mesa's software
# rasterizer will do: apt install xvfb libgl1-mesa-dri) and an ffmpeg with
# libx264 (pip install imageio-ffmpeg gives you one). The full film is ~6
# minutes, ~8,900 frames; with software GL on two cores that is about an hour,
# so this is run on purpose, not by the commit hook (see .githooks/pre-commit).
#   STOP=25 ./build.sh     renders only the first 25 seconds, for a quick look.
set -euo pipefail
GODOT="${1:-godot4}"
RES="${RES:-1920x1080}"
CRF="${CRF:-20}"
cd "$(dirname "$0")"
export HOME="${HOME:-/root}"
FFMPEG="${FFMPEG:-$(python3 -c 'import imageio_ffmpeg as f; print(f.get_ffmpeg_exe())' 2>/dev/null || command -v ffmpeg)}"
"$FFMPEG" -hide_banner -encoders 2>/dev/null | grep -q libx264 || { echo "build: need an ffmpeg with libx264 (pip install imageio-ffmpeg)" >&2; exit 1; }

work="${WORK:-$(mktemp -d)}"
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
	"$GODOT" --display-driver x11 --rendering-driver opengl3 --resolution "$RES" --path project -- --audit ${STOP:+--stop=$STOP} \
	> "$work/audit.log" 2>&1 || true
if grep -qE "SCRIPT ERROR|Parse Error|^LAYOUT" "$work/audit.log" || ! grep -q "0 layout problems" "$work/audit.log"; then
	grep -E "SCRIPT ERROR|Parse Error|^LAYOUT" "$work/audit.log" | head >&2 || true
	echo "build: the lettering audit failed (log: $work/audit.log)" >&2
	exit 1
fi
grep "^FILM COMPLETE" "$work/audit.log" >&2

if [ -s "$work/film.avi" ] && grep -q "^FILM COMPLETE" "$work/render.log" 2>/dev/null; then
	echo "build: reusing the render in $work" >&2
else
echo "build: rendering ${STOP:+the first ${STOP}s of }the film at $RES..." >&2
stop_arg=""; [ -n "${STOP:-}" ] && stop_arg="--stop=$STOP"
xvfb-run -a -s "-screen 0 ${RES}x24" env LIBGL_ALWAYS_SOFTWARE=1 \
	"$GODOT" --display-driver x11 --rendering-driver opengl3 --resolution "$RES" \
	--write-movie "$work/film.avi" --fixed-fps 24 --path project -- $stop_arg 2>&1 \
	| grep -E "^(film:|CHAPTER|LAYOUT|FILM)|SCRIPT ERROR|Parse Error" | tee "$work/render.log" >&2 || true
if grep -qE "SCRIPT ERROR|Parse Error|^LAYOUT" "$work/render.log" || ! grep -q "^FILM COMPLETE" "$work/render.log"; then
	echo "build: the render reported problems (log: $work/render.log)" >&2
	exit 1
fi
fi

echo "build: encoding..." >&2
"$FFMPEG" -hide_banner -loglevel error -y -i "$work/film.avi" \
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
[ -n "${KEEP:-}" ] || rm -rf "$work"
echo "made web/bludleigh.mp4 ($(du -h web/bludleigh.mp4 | cut -f1), $minutes), poster and player"
