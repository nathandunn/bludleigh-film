## Lettering — everything printed on top of the picture.
##
## The panel border and paper margin, the narrator's caption boxes, speech
## balloons with tails that find the speaker's head every frame, sound effects,
## title plates and the folio. Pure drawing: the director hands it a page and
## the screen positions of heads; it never touches the 3D scene.
class_name Lettering
extends Control

const BALLOON := Color("fbf8ef")
const CAPTION := Color("efdc9c")
const SFX_FILL := Color("c2412f")

var f_text: Font
var f_italic: Font
var f_bold: Font
var f_title: Font

var page: Dictionary = {}:
	set(v):
		page = v
		_layout = {}
		queue_redraw()
## who -> Vector2 screen point just above the head, or absent when off-screen.
## who -> Rect2 of that face card on screen. Balloons stay off these.
var faces: Dictionary = {}
var anchors: Dictionary = {}:
	set(v):
		anchors = v
		queue_redraw()
var folio: String = ""
var show_hint: bool = false
## What has been said so far. The page is laid out whole, so nothing moves when
## the next line appears; these only decide what is drawn yet.
var show_caption: bool = true
var show_caption2: bool = true
var show_title: bool = true
var show_sfx: bool = true
var reveal: int = 99
## 0..1 paper over the picture, for the cut between scenes.
var wipe: float = 0.0

var _panel: Rect2
var _last: Rect2
## Where every box on the current page sits and at what size, worked out once
## when the page opens and then held: only the balloon tails follow the heads
## as the camera creeps. Laying out afresh every frame let a balloon hop
## between two spots, or two sizes, as a head drifted across a threshold.
var _layout: Dictionary = {}
## This page's caption and title boxes, which a balloon may graze as a last resort.
var _captions: Array[Rect2] = []
var _layout_size: Vector2


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	f_text = load("res://fonts/CrimsonPro-Regular.ttf")
	f_italic = load("res://fonts/CrimsonPro-Italic.ttf")
	f_bold = load("res://fonts/CrimsonPro-Bold.ttf")
	f_title = load("res://fonts/Gloock-Regular.ttf")
	# Each face keeps a glyph atlas per size it has drawn, so sizes are whole
	# pixels and a page is fitted once, not every frame. (Distance-field fonts
	# would share one atlas across sizes, but Crimson Pro's overlapping contours
	# print white specks inside the letters that way.)


## The picture's rectangle in screen space — the director fits the camera to it.
func panel_rect() -> Rect2:
	var s := size
	var m := clampf(minf(s.x, s.y) * 0.03, 10.0, 28.0)
	var r := Rect2(m, m, s.x - m * 2.0, s.y - m * 2.0)
	if page.get("frame", "full") == "wide" and s.x > s.y:
		var bar := s.y * 0.08
		r = r.grow_individual(0, -bar, 0, -bar)
	return r


## Every size the lettering uses comes off this ladder, so the fonts only ever
## rasterise a handful of sizes (each one is its own glyph atlas in GPU memory).
const SIZES := [22.0, 26.0, 30.0, 34.0, 40.0, 46.0, 52.0, 60.0, 68.0, 78.0, 90.0, 104.0, 120.0, 140.0]


static func _snap(fs: float) -> float:
	var best: float = SIZES[0]
	for v in SIZES:
		if v <= fs + 0.5:
			best = v
	return best


## The book's proportions: its pages are printed at 2560x1440, where the
## lettering comes out at 104 px — 7.2% of the height. The film is 1080p, so
## the size follows the height rather than the book's pixel clamp, or the type
## would be a quarter larger on the frame than on the page and crowd it.
func _text_size() -> float:
	return size.y * 0.0722


func _process(_d: float) -> void:
	queue_redraw()


func _draw() -> void:
	if size.x < 160.0 or size.y < 120.0:
		return
	_panel = panel_rect()
	var ts := _text_size()
	if _layout_size != size:
		_layout = {}
		_layout_size = size
	var taken: Array[Rect2] = []
	_last = Rect2()

	var avoid: Array[Rect2] = []
	var folio_zone := _folio_zone(ts)
	if folio_zone.size.x > 0.0:
		avoid.append(folio_zone)
	if page.has("caption"):
		taken.append(_caption(page["caption"], true, ts, avoid))
	if page.has("caption2"):
		taken.append(_caption(page["caption2"], false, ts, avoid))
	if page.has("title"):
		taken.append(_title(page["title"], taken))
	_captions = taken.duplicate()
	# The folio plate is off limits to balloons, always.
	taken.append_array(avoid)

	var said: Array = page.get("say", [])
	for i in said.size():
		var line: Array = said[i]
		var kind: String = line[2] if line.size() > 2 else "speech"
		_last = _balloon(i, line[0], line[1], kind, ts, taken)
		taken.append(_last)

	# Sound effects last, each nudged to the nearest spot clear of the words.
	var fx_taken: Array[Rect2] = taken + avoid
	for i in page.get("sfx", []).size():
		var fx: Array = page["sfx"][i]
		_sfx(i, fx[0], fx[1], fx[2], fx_taken)


	_frame()
	_folio(ts)
	if wipe > 0.0:
		draw_rect(Rect2(Vector2.ZERO, size), Color(Ink.PAPER, wipe))


# --- Frame and folio ------------------------------------------------------------

func _frame() -> void:
	var s := size
	var p := _panel
	var paper := Ink.PAPER
	draw_rect(Rect2(0, 0, s.x, p.position.y), paper)
	draw_rect(Rect2(0, p.end.y, s.x, s.y - p.end.y), paper)
	draw_rect(Rect2(0, p.position.y, p.position.x, p.size.y), paper)
	draw_rect(Rect2(p.end.x, p.position.y, s.x - p.end.x, p.size.y), paper)
	draw_rect(p, Ink.INK, false, 5.0)


## Where the folio plate will land, so a caption anchored to that same corner
## can get out of its way instead of printing underneath it.
func _folio_zone(ts: float) -> Rect2:
	if folio == "":
		return Rect2()
	var p := _panel
	var fs := _snap(ts * 0.62)
	var pad := Vector2(16, 10)
	var sz := f_italic.get_string_size(folio, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
	return Rect2(p.end - sz - pad * 2.0 - Vector2(12, 12), sz + pad * 2.0).grow(8)


## The folio and the turn-page hint print on a paper plate inside the bottom
## corners of the picture itself — the thin outer margin is only ever a few
## points wide and cannot hold lettering at a readable size.
func _folio(ts: float) -> void:
	var p := _panel
	var fs := _snap(ts * 0.62)
	var pad := Vector2(16, 10)
	if folio != "":
		var sz := f_italic.get_string_size(folio, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
		var box := Rect2(p.end - sz - pad * 2.0 - Vector2(12, 12), sz + pad * 2.0)
		_plate(box)
		draw_string(f_italic, box.position + pad + Vector2(0, f_italic.get_ascent(fs)), folio,
			HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Ink.INK)
	if show_hint:
		var hint := "tap, click or space to turn the page  ·  ← back"
		var hfs := _snap(ts * 0.46)
		var hsz := f_italic.get_string_size(hint, HORIZONTAL_ALIGNMENT_LEFT, -1, hfs)
		var hbox := Rect2(Vector2(p.position.x + 12.0, p.end.y - hsz.y - pad.y * 2.0 - 12.0), hsz + pad * 2.0)
		_plate(hbox)
		draw_string(f_italic, hbox.position + pad + Vector2(0, f_italic.get_ascent(hfs)), hint,
			HORIZONTAL_ALIGNMENT_LEFT, -1, hfs, Ink.INK)


func _plate(box: Rect2) -> void:
	draw_rect(box, Color(Ink.PAPER, 0.92))
	draw_rect(box, Ink.INK, false, 2.0)


# --- Captions ------------------------------------------------------------------------

func _caption(t: String, top: bool, ts: float, avoid: Array[Rect2]) -> Rect2:
	var p := _panel
	var maxw := minf(p.size.x * (0.48 if p.size.x > p.size.y else 0.78), 720.0)
	var pad := Vector2(22, 16)
	var fs := 0.0
	var key := "caption_%s" % top
	var box: Rect2
	if _layout.has(key):
		box = _layout[key][0]
		fs = _layout[key][1]
	else:
		box = _fit_caption(t, top, ts, avoid, maxw, pad)
		fs = _layout[key][1] if _layout.has(key) else fs
	if show_caption if top else show_caption2:
		draw_rect(box, CAPTION)
		draw_rect(box, Ink.INK, false, 2.5)
		draw_multiline_string(f_italic, box.position + pad + Vector2(0, f_italic.get_ascent(fs)), t,
			HORIZONTAL_ALIGNMENT_LEFT, maxw - pad.x * 2, fs, -1, Ink.INK)
	return box.grow(26)


func _fit_caption(t: String, top: bool, ts: float, avoid: Array[Rect2], maxw: float, pad: Vector2) -> Rect2:
	var p := _panel
	var fs := _snap(ts * 0.62)
	var floor_fs := _snap(ts * 0.34)
	var max_h := p.size.y * 0.62
	var tsz := f_italic.get_multiline_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, maxw - pad.x * 2, fs)
	# A long caption at this much bigger size can ask for more height than the
	# panel has; shrink it rather than let the last line run off the page.
	while tsz.y + pad.y * 2.0 > max_h and fs > floor_fs:
		fs = _snap(maxf(fs - 1.0, floor_fs))
		tsz = f_italic.get_multiline_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, maxw - pad.x * 2, fs)
	var box := Rect2(Vector2.ZERO, tsz + pad * 2 + Vector2(0, fs * 0.3))
	var inset := 14.0
	if top:
		box.position = p.position + Vector2(inset, inset)
	else:
		box.position = p.end - box.size - Vector2(inset, inset)
	# The folio plate always prints last, in the same corner a bottom caption
	# would naturally sit in — get out of its way rather than let it paint
	# over the caption's last line.
	for o in avoid:
		if box.intersects(o):
			box.position.y = minf(box.position.y, o.position.y - box.size.y - 10.0)
	_layout["caption_%s" % top] = [box, fs]
	return box


func _title(t: Array, taken: Array[Rect2]) -> Rect2:
	var p := _panel
	var big := _snap(clampf(p.size.y * 0.16, 60.0, 150.0))
	var small := _snap(clampf(big * 0.3, 30.0, 46.0))
	var tw := f_title.get_string_size(t[0], HORIZONTAL_ALIGNMENT_LEFT, -1, big).x
	var maxw := minf(p.size.x * 0.8, maxf(tw, 300.0) + 80.0)
	var sub_sz := f_italic.get_multiline_string_size(t[1], HORIZONTAL_ALIGNMENT_CENTER, maxw - 40.0, small)
	var h := big * 1.15 + sub_sz.y + 40.0
	var box := Rect2(Vector2(p.get_center().x - maxw * 0.5, p.position.y + p.size.y * 0.52 - h * 0.5), Vector2(maxw, h))
	# A caption already on the page claims its own ground; keep the title off
	# it rather than let the two fight over the same square of panel.
	for o in taken:
		if box.intersects(o):
			if o.get_center().y < p.get_center().y:
				box.position.y = maxf(box.position.y, o.end.y + 14.0)
			else:
				box.position.y = minf(box.position.y, o.position.y - h - 14.0)
	# Nor may it hide a face: drop below the lowest face it would cover.
	for _pass in 3:
		for id in faces:
			var fr: Rect2 = faces[id]
			if box.intersects(fr):
				box.position.y = maxf(box.position.y, fr.end.y + 14.0)
	box.position.y = clampf(box.position.y, p.position.y + 8.0, p.end.y - h - 8.0)
	if _layout.has("title"):
		box = _layout["title"]
	else:
		_layout["title"] = box
	if not show_title:
		return box.grow(6)
	draw_rect(box, Color(Ink.PAPER, 0.94))
	draw_rect(box, Ink.INK, false, 3.0)
	draw_rect(box.grow(-7), Ink.INK, false, 1.0)
	draw_string(f_title, Vector2(box.position.x, box.position.y + 18.0 + big * 0.95), t[0],
		HORIZONTAL_ALIGNMENT_CENTER, maxw, big, Ink.INK)
	draw_multiline_string(f_italic, Vector2(box.position.x + 20.0, box.position.y + 18.0 + big * 1.15 + small),
		t[1], HORIZONTAL_ALIGNMENT_CENTER, maxw - 40.0, small, -1, Ink.INK)
	return box.grow(6)


# --- Balloons ---------------------------------------------------------------------------

func _balloon(index: int, who: String, txt: String, kind: String, ts: float, taken: Array[Rect2]) -> Rect2:
	var p := _panel
	var landscape := p.size.x > p.size.y
	var maxw := minf(p.size.x * (0.4 if landscape else 0.68), 600.0)
	var f := f_bold if kind == "shout" else f_text
	var has_anchor := anchors.has(who)
	var a: Vector2 = anchors.get(who, Vector2(p.get_center().x, p.position.y))
	var key := "balloon_%d" % index
	if _layout.has(key):
		var m: Array = _layout[key]
		return _draw_balloon(m[0], a, has_anchor, kind, f, m[1], m[2], m[3], txt, index)

	# Heads are sacred: a balloon may not sit on anybody's face.
	var blocked: Array[Rect2] = taken.duplicate()
	for id in faces:
		blocked.append(faces[id])

	# Try to place at full size, then again a little smaller if the page is too
	# crowded to fit it cleanly — big lettering makes a crowded panel a real
	# constraint, and a slightly smaller balloon reads far better than one that
	# overlaps a caption or another line.
	var fs := _snap(ts * (0.78 if kind == "shout" else 0.70))
	var pad := Vector2(30, 20) if kind != "shout" else Vector2(40, 28)
	var floor_fs := _snap(ts * 0.42)
	# Each size is tried narrow and then wide: a long flat balloon fits the
	# strip of wall above people's heads when a tall one won't.
	var widths := [maxw, minf(maxw * 1.5, p.size.x * 0.62)]
	var n: int = page.get("say", []).size()
	var lift := 0.15 + 1.2 * float(n - 1 - index) / float(maxi(n - 1, 1))
	var bs := Vector2.ZERO
	var w: float = maxw
	var found := Rect2(-1, -1, 0, 0)
	# A rectangle of text only fits inside the oval if the oval is bigger by
	# a share of the text itself: with SQUARENESS 3.4 the text's corners land
	# on the curve at ~82% of its half-width, so the margin must be ~12% of the
	# text block each side (~17% inside a shout, whose spikes dip in to 93%).
	var share := 0.17 if kind == "shout" else 0.12
	var pd := pad
	while true:
		for ww in widths:
			var tsz := f.get_multiline_string_size(txt, HORIZONTAL_ALIGNMENT_CENTER, ww, fs)
			pd = Vector2(maxf(pad.x, tsz.x * share), maxf(pad.y, tsz.y * share))
			bs = tsz + pd * 2.0 + Vector2(0, fs * 0.3)
			w = ww
			found = _place_balloon(a, bs, blocked, lift)
			if found.position.x >= 0.0:
				break
		if found.position.x >= 0.0 or fs <= floor_fs:
			break
		fs = _snap(maxf(fs - 1.0, floor_fs))
		pad *= 0.9
	if found.position.x < 0.0:
		# At the smallest size and still nowhere clean: let it graze a caption
		# rather than a face or another balloon.
		var faces_only: Array[Rect2] = []
		for i in taken.size():
			if not _captions.has(taken[i]):
				faces_only.append(taken[i])
		for id in faces:
			faces_only.append(faces[id])
		found = _place_balloon(a, bs, faces_only, lift)
	var r := found
	if r.position.x < 0.0:
		# Truly no room: slide down past what is on the page, in reading order.
		r = _slide_balloon(a, bs, taken)
	_layout[key] = [r, fs, pd, w]
	return _draw_balloon(r, a, has_anchor, kind, f, fs, pd, w, txt, index)


## The best clear spot for a balloon of [param bs] spoken from [param a]: every
## position on a grid across the panel is a candidate; anything that covers a
## face, a caption or another balloon, or would be read out of turn, is out;
## of what is left, the one nearest the speaker wins, above the head if it can
## be. Returns a rect with a negative position when nothing is clear.
func _place_balloon(a: Vector2, bs: Vector2, blocked: Array[Rect2], lift: float = 0.15) -> Rect2:
	var inner := _panel.grow(-10)
	var best := Rect2(-1, -1, 0, 0)
	var best_score := INF
	var step := 20.0
	var y := inner.position.y
	while y <= inner.end.y - bs.y:
		var x := inner.position.x
		while x <= inner.end.x - bs.x:
			var c := Rect2(Vector2(x, y), bs)
			x += step
			if not _in_order(c):
				continue
			var clear := true
			for o in blocked:
				if c.intersects(o):
					clear = false
					break
			if not clear:
				continue
			# Distance from the head to the nearest point of the balloon's
			# bottom edge: short tails read best.
			var edge := Vector2(clampf(a.x, c.position.x, c.end.x), c.end.y)
			var score := edge.distance_to(a)
			if c.get_center().y > a.y:
				score += 600.0   # below the speaker's head: a last resort
			# Nudge up the page; early lines on a busy page hardest, so they
			# take the top and leave room below for the replies.
			score += (c.position.y - _panel.position.y) * lift
			if score < best_score:
				best_score = score
				best = c
		y += step
	return best


## Comic reading order: left to right, top to bottom. A balloon comes after
## the one before it if it sits clearly lower, or on the same row and to the
## right of it. Anything else gets read first, and the scene plays backwards.
func _in_order(c: Rect2) -> bool:
	if _last.size.x <= 0.0:
		return true
	# Clearly underneath: fine wherever it sits across.
	if c.position.y >= _last.end.y - 30.0:
		return true
	# On the same row: only to the right.
	if c.position.y >= _last.position.y - 12.0 and c.position.x >= _last.end.x - 24.0:
		return true
	# Lower and further right: a step down the page, still read second.
	return c.get_center().x >= _last.get_center().x and c.position.y >= _last.position.y + _last.size.y * 0.35


func _slide_balloon(a: Vector2, bs: Vector2, taken: Array[Rect2]) -> Rect2:
	var p := _panel
	# Start above the speaker (but never above the balloon before it) and
	# slide down past what is on the page, so the order holds.
	var r := Rect2(Vector2(a.x - bs.x * 0.5, a.y - bs.y - 60.0), bs)
	r.position.x = clampf(r.position.x, p.position.x + 10.0, p.end.x - bs.x - 10.0)
	r.position.y = maxf(r.position.y, p.position.y + 10.0)
	if _last.size.x > 0.0:
		r.position.y = maxf(r.position.y, _last.position.y + _last.size.y * 0.35)
	for _i in 8:
		var hit := false
		for o in taken:
			if r.intersects(o):
				r.position.y = o.end.y + 6.0
				hit = true
		if not hit:
			break
	if r.end.y > p.end.y - 10.0:
		# No room below: try beside the column of balloons instead.
		r.position.y = p.end.y - 10.0 - bs.y
		for o in taken:
			if r.intersects(o):
				r.position.x = o.end.x + 8.0 if o.get_center().x < p.get_center().x else o.position.x - bs.x - 8.0
				r.position.x = clampf(r.position.x, p.position.x + 10.0, p.end.x - bs.x - 10.0)
	return r


func _draw_balloon(r: Rect2, a: Vector2, has_anchor: bool, kind: String,
		f: Font, fs: float, pad: Vector2, maxw: float, t: String, index: int = 0) -> Rect2:
	if index >= reveal:
		return r.grow(18)
	var shape := _jagged(r) if kind == "shout" else _oval(r)
	var outline := shape
	if has_anchor and not r.grow(-4).has_point(a):
		var tail := _tail(r, a)
		var merged := Geometry2D.merge_polygons(shape, tail)
		if merged.size() > 0:
			outline = merged[0]
	draw_colored_polygon(outline, BALLOON)
	var closed := outline.duplicate()
	closed.append(outline[0])
	draw_polyline(closed, Ink.INK, 2.5, true)
	# Wrap at the same width the box was measured with (maxw), not the box's
	# own tighter width — rewrapping a second time at a narrower width than
	# the measurement used can add a line the box was never sized for, which
	# is how a balloon's last line ended up printing below its own outline.
	draw_multiline_string(f, Vector2(r.get_center().x - maxw * 0.5, r.position.y + pad.y + f.get_ascent(fs)), t,
		HORIZONTAL_ALIGNMENT_CENTER, maxw, fs, -1, Ink.INK)
	return r.grow(18)


## The first spot near [param want] where a box of [param sz] centred there
## clears everything in [param taken]: up first, then sideways, then down.
func _clear_spot(want: Vector2, sz: Vector2, taken: Array[Rect2]) -> Vector2:
	var inner := _panel.grow(-12)
	var steps: Array[Vector2] = [Vector2.ZERO]
	for k in range(1, 9):
		steps.append(Vector2(0, -sz.y * 0.5 * k))
		steps.append(Vector2(-sz.x * 0.35 * k, 0))
		steps.append(Vector2(sz.x * 0.35 * k, 0))
		steps.append(Vector2(0, sz.y * 0.5 * k))
	for d in steps:
		var c := want + d
		var r := Rect2(c - sz * 0.5, sz)
		if not inner.encloses(r):
			continue
		var clear := true
		for o in taken:
			if r.intersects(o):
				clear = false
				break
		if clear:
			return c
	return want


## A lettered balloon: a superellipse, which is rounder than a rounded rect and
## squarer than an ellipse, like the ones drawn with a template.
## Superellipse exponent for balloons: 2 is an ellipse, higher is boxier. At
## 3.4 a block of text's corners reach the curve at ~82% of its half-width.
const SQUARENESS := 3.4


func _oval(r: Rect2) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var c := r.get_center()
	var hx := r.size.x * 0.5 + 6.0
	var hy := r.size.y * 0.5 + 4.0
	var n := SQUARENESS
	for i in 64:
		var th := TAU * float(i) / 64.0
		var ct := cos(th)
		var st := sin(th)
		var x := pow(absf(ct), 2.0 / n) * signf(ct) * hx
		var y := pow(absf(st), 2.0 / n) * signf(st) * hy
		pts.append(c + Vector2(x, y))
	return pts


func _jagged(r: Rect2) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var c := r.get_center()
	var hx := r.size.x * 0.5 + 4.0
	var hy := r.size.y * 0.5 + 2.0
	var spikes := 22
	for i in spikes * 2:
		var th := TAU * float(i) / float(spikes * 2)
		var k := 1.14 if i % 2 == 0 else 0.93
		var ct := cos(th)
		var st := sin(th)
		var x := pow(absf(ct), 2.0 / SQUARENESS) * signf(ct) * hx * k
		var y := pow(absf(st), 2.0 / SQUARENESS) * signf(st) * hy * k
		pts.append(c + Vector2(x, y))
	return pts


## A tail from the balloon's edge toward [param a], stopping short of the head.
func _tail(r: Rect2, a: Vector2) -> PackedVector2Array:
	var c := r.get_center()
	var below := a.y > c.y
	var bx := clampf(a.x, r.position.x + r.size.x * 0.25, r.end.x - r.size.x * 0.25)
	var by := r.end.y - 6.0 if below else r.position.y + 6.0
	var tip := a
	var d := a - Vector2(bx, by)
	if d.length() > 30.0:
		tip = a - d.normalized() * 16.0
	var w := clampf(r.size.x * 0.07, 10.0, 18.0)
	return PackedVector2Array([Vector2(bx - w, by), tip, Vector2(bx + w, by)])


# --- Sound effects ---------------------------------------------------------------------

func _sfx(index: int, t: String, at: Vector2, deg: float, taken: Array[Rect2]) -> void:
	var p := _panel
	var fs := _snap(clampf(p.size.y * 0.14, 56.0, 150.0))
	var w := f_title.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var key := "sfx_%d" % index
	var pos: Vector2
	if _layout.has(key):
		pos = _layout[key]
	else:
		pos = _clear_spot(p.position + p.size * at, Vector2(w, fs) * 1.1, taken)
		_layout[key] = pos
	# Claim the ground, so the next effect on the page lands somewhere else.
	taken.append(Rect2(pos - Vector2(w, fs) * 0.55, Vector2(w, fs) * 1.1))
	if not show_sfx:
		return
	draw_set_transform(pos, deg_to_rad(deg), Vector2.ONE)
	draw_string_outline(f_title, Vector2(-w * 0.5, fs * 0.35), t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 10, Ink.INK)
	draw_string(f_title, Vector2(-w * 0.5, fs * 0.35), t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, SFX_FILL)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## Problems with the current page's layout, for the page gate: balloons out of
## reading order, or sitting on a face, a caption or each other.
func audit() -> Array[String]:
	var out: Array[String] = []
	var said: Array = page.get("say", [])
	var boxes: Array[Rect2] = []
	for k in ["caption_true", "caption_false"]:
		if _layout.has(k):
			boxes.append(_layout[k][0])
	if _layout.has("title"):
		boxes.append(_layout["title"])
	var prev := Rect2()
	for i in said.size():
		var key := "balloon_%d" % i
		if not _layout.has(key):
			out.append("balloon %d never laid out" % i)
			continue
		var r: Rect2 = _layout[key][0]
		if prev.size.x > 0.0:
			var under := r.position.y >= prev.end.y - 48.0
			var right := r.position.y >= prev.position.y - 30.0 and r.position.x >= prev.end.x - 60.0
			var step := r.get_center().x >= prev.get_center().x and r.position.y >= prev.position.y + prev.size.y * 0.3
			if not (under or right or step):
				out.append("balloon %d (%s) reads before balloon %d" % [i, said[i][0], i - 1])
		for b in boxes:
			if r.intersects(b):
				out.append("balloon %d (%s) overlaps a box" % [i, said[i][0]])
		for id in faces:
			var fr: Rect2 = faces[id]
			if r.intersects(fr.grow(-12)):
				out.append("balloon %d (%s) covers %s's face" % [i, said[i][0], id])
		boxes.append(r)
		prev = r
	return out

