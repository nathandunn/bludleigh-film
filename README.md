# Bludleigh — the film

The graphic novel [hunting-lodge](https://github.com/nathandunn/hunting-lodge)
played as a film: about six minutes, no sound, the words on the picture as
they are on the page. Two gentle poets visit a house that has been killing
things for four hundred years, and the house wins. After P. G. Wodehouse's
*Unpleasantness at Bludleigh Court*; faces drawn by Nathan.

## Watch it

Visit the deployed film. Space plays and pauses, ← and → skip five seconds,
`[` and `]` change scene, F is full screen, and `#3:10` in the address starts
there. The scene buttons under the film are chapters.

## How it is made

`project/` is the hunting-lodge Godot project — the same sets, cast, lighting
and lettering, copied rather than shared so the two can drift — with a
different director. `scripts/main.gd` here plays the book's 28 pages as beats
on a timeline instead of waiting for a click:

- **Walking.** Between pages the cast walk: from mark to mark when the next page
  is in the same set (the camera eases from shot to shot over the walk), and
  off the edge of frame and on again, under a paper wipe, when the scene
  changes. The paper doll got a walk cycle (`Figure.walking`): legs and arms
  swing at two steps a second, quantised to the same 12 drawn frames a second
  as everything else. Seated people are discovered in their chairs.
- **Reading time.** On each page the words appear in reading order — title,
  caption, each balloon, closing caption — and each is held for 0.9 s plus a
  third of a second a word (shouts go quicker; 1.7 s minimum), then a beat
  before moving on. The speaker gestures while their line is up. The page is
  laid out whole when it opens (same collision rules as the book: nothing on a
  face, in the wrong order, or over the folio), so nothing shifts as lines
  appear; `Lettering.reveal` and the `show_*` flags just decide what is drawn
  yet.
- **Headroom.** As in the book, a shot with dialogue rises until the speakers'
  heads sit below mid-panel, so the balloons have somewhere to go. The camera
  pushes in 2.5% over each page so a held panel is never quite still.

Nothing runs in a browser. A Godot web export lost its WebGL context in Safari
a few pages into the book, so the book ships as pictures and the film ships as
a film: `build.sh` renders every frame with Godot's Movie Maker mode
(`--write-movie`, a fixed 24 fps, 1920x1080, 4x MSAA — no browser GPU budget to
respect offline), encodes it to H.264 with ffmpeg, takes a poster, reads the
`CHAPTER` lines the director prints into the player's scene buttons, and
writes `player/index.html` to `web/`. The Dockerfile serves `web/` from nginx.

## Building

```
./build.sh                # the whole film: about an hour with software GL on two cores
STOP=25 ./build.sh        # the first 25 seconds, for a look
godot4 --headless --path project -- --check     # walk the timeline in seconds; prints its length
godot4 --path project                           # watch it in real time in the editor's runtime
```

`build.sh` needs Godot 4.4, `xvfb-run` with Mesa's software rasterizer
(`apt install xvfb libgl1-mesa-dri`) and an ffmpeg with libx264
(`pip install imageio-ffmpeg`). It runs the timeline check first, and the
render fails the build if it prints a `LAYOUT` line (a balloon over a face or
out of order) or a script error.

Because the render takes an hour, the commit hook does **not** re-render:
`tools/install-hooks.sh` installs a pre-commit that runs the timeline check
(seconds) and reminds you to run `./build.sh` when `project/` changed but
`web/bludleigh.mp4` didn't, and a post-commit that, on `main` on a machine with
`/opt/scripts/deploy.sh`, pushes and redeploys. `SKIP_BUILD=1` skips the check;
`SKIP_DEPLOY=1` skips the deploy. Deployed on the Precog hub as
`bludleigh-film`.
