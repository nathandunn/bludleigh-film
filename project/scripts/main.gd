## Main — the director of the film.
##
## The same book as hunting-lodge, played as a film: the pages are beats on a
## timeline. Between pages the cast walk — from mark to mark within a set, and
## off the edge of frame and on again when the scene changes, under a paper
## wipe. On each page the words appear in reading order, each caption and
## balloon held for as long as it takes to read, the speaker gesturing while
## their line is up. Nothing waits for a click.
##
## Built as a film, not run as one: `--write-movie` (Godot's Movie Maker mode)
## renders every frame offline at a fixed 24 fps and build.sh turns that into
## an MP4 — no engine in the browser. Run without it to watch in real time.
## `--check` walks the whole timeline headless at speed and prints its length.
extends Node3D

const FPS := 24.0
const WALK_SPEED := 1.35        # m/s, a gentleman's pace
const EXIT_TIME := 1.3          # s of walking out before a cut
const WIPE := 0.4               # s, paper over a cut between scenes
const TITLE_HOLD := 3.8
const LOOK_HOLD := 2.4          # a page with no words: a look at the scene
const TAIL_HOLD := 1.1          # after the last line, before moving on
const MIN_BEAT := 1.7
const SETTLE := 0.45            # poses ease in before the page is lettered
const PUSH_IN := 0.025          # camera creeps this far toward its subject per page

const CHAPTERS := {
	"parlour": ["The Angler's Rest", "The Angler's Rest, later"],
	"exterior": ["Bludleigh Court", "The 4.15 to Paddington"],
	"hall": ["The great hall"], "dining": ["Dinner"], "gunroom": ["The gun-room"], "moor": ["The moor"],
}

enum State { EXIT, CUT, MOVE, BEATS, END }

var lighting: Lighting
var world: Node3D
var sets: Dictionary = {}
var cast: Dictionary = {}
var camera: Camera3D
var letters: Lettering
var pages: Array = []
var index: int = -1

var _state: State = State.CUT
var _clock: float = 0.0
var _dur: float = 0.0
var _film_time: float = 0.0
var _speed: float = 1.0
var _check := false
var _audit := false
var _problems := 0
var _prev_set := ""
var _seen_sets: Dictionary = {}
var _cut_done := false
var _pending: int = 0
var _report := 0.0

## Camera: eases from A to B over _cam_dur, then pushes in a little.
var _cam_a: Array = [Vector3.ZERO, Vector3.FORWARD, 42.0]
var _cam_b: Array = [Vector3.ZERO, Vector3.FORWARD, 42.0]
var _cam_t: float = 1.0
var _cam_dur: float = 0.0

## id -> {from, to, t, dur, yaw, pose, seated, hide, mark}
var _walks: Dictionary = {}
var _beats: Array = []
var _beat: int = -1
var _beats_total: float = 0.0


func _ready() -> void:
	RenderingServer.set_default_clear_color(Ink.PAPER)
	_check = _has_flag("--check")
	# --audit: the whole film at speed, rendered but not recorded, so every
	# page's lettering is laid out at the real frame size and checked. Minutes,
	# not the hour the render takes.
	_audit = _has_flag("--audit")
	if _audit:
		_speed = 16.0
	if _arg("--stop") != "":
		_stop_at = float(_arg("--stop"))
	if _check:
		_speed = float(_arg("--speed")) if _arg("--speed") != "" else 40.0
	get_viewport().scaling_3d_scale = 1.0
	get_viewport().msaa_3d = Viewport.MSAA_DISABLED if _audit else Viewport.MSAA_4X
	lighting = Lighting.new()
	add_child(lighting)
	world = Node3D.new()
	world.name = "Sets"
	add_child(world)
	var skins := Ink.SKINS
	var i := 0
	for id in Story.CAST:
		var c: Dictionary = Story.CAST[id]
		var f := Figure.create(c["face"], c["costume"], c["tint"], skins[c["skin"]], c["h"], i * 0.37)
		f.name = id
		f.visible = false
		add_child(f)
		cast[id] = f
		i += 1
	camera = Camera3D.new()
	camera.current = true
	add_child(camera)
	var layer := CanvasLayer.new()
	add_child(layer)
	letters = Lettering.new()
	letters.folio = ""
	layer.add_child(letters)
	pages = Story.pages()
	print("film: %d pages, %s" % [pages.size(), "movie maker" if OS.has_feature("movie") else ("check" if _check else "preview")])
	_pending = 0
	_start_cut()


# --- The timeline ---------------------------------------------------------------------

var _frames := 0
var _stop_at := 0.0


func _process(delta: float) -> void:
	_frames += 1
	if _frames == 1:
		return   # the first frame carries the load time; not film time
	delta = minf(delta, 1.0 / FPS) * _speed
	_film_time += delta
	if _stop_at > 0.0 and _film_time >= _stop_at and _state != State.END:
		_state = State.END
		_clock = 0.0
	_clock += delta
	_step_walks(delta)
	_step_camera(delta)
	_update_anchors()
	match _state:
		State.EXIT:
			if _clock >= _dur:
				_start_cut()
		State.CUT:
			# Paper rises over the first half, the world changes under it, paper falls.
			var half := WIPE * 0.5
			letters.wipe = clampf(1.0 - absf(_clock / half - 1.0), 0.0, 1.0) if index >= 0 or _cut_done else 1.0
			if not _cut_done and _clock >= half:
				_cut_done = true
				_arrive(_pending, false)
			if _clock >= WIPE:
				letters.wipe = 0.0
				_state = State.MOVE
				_clock = 0.0
		State.MOVE:
			if _clock >= _dur:
				_start_beats()
		State.BEATS:
			if _beat >= 0 and _clock >= _beats[_beat]["dur"]:
				_next_beat()
		State.END:
			letters.wipe = clampf(_clock / 1.2, 0.0, 1.0)
			if _clock >= 1.6:
				print("FILM COMPLETE %.1f s (%d frames at %d fps), %d layout problems" % [_film_time, int(_film_time * FPS), int(FPS), _problems])
				get_tree().quit()
	if _film_time >= _report:
		_report += 15.0
		if _has_flag("--trace"):
			print("trace: frame %d film %.2f state %d page %d clock %.2f dur %.2f" % [_frames, _film_time, _state, index, _clock, _dur])
		if OS.has_feature("movie"):
			print("film: %d:%02d rendered (page %d)" % [int(_film_time) / 60, int(_film_time) % 60, index + 1])


## Leave the current page: if the next is in another set, the travellers walk
## out of frame first; otherwise go straight to moving into the new shot.
func _leave_for(next: int) -> void:
	_pending = next
	if next >= pages.size():
		_state = State.END
		_clock = 0.0
		return
	var same: bool = index >= 0 and pages[index]["set"] == pages[next]["set"]
	letters.page = {}
	for id in cast:
		(cast[id] as Figure).talking = false
	if same:
		_arrive(next, true)
		_state = State.MOVE
		_clock = 0.0
		return
	# Walk out toward the nearer edge, then cut.
	var walkers := 0
	var nxt: Dictionary = pages[next].get("cast", {})
	for id in cast:
		var f: Figure = cast[id]
		if not f.visible or f.seated or not nxt.has(id):
			continue
		var out := _offstage(f.position, _side_of(f.position))
		_walk_to(id, out, f.position.distance_to(out) / WALK_SPEED, {"hide": true})
		walkers += 1
	_state = State.EXIT
	_clock = 0.0
	_dur = EXIT_TIME if walkers > 0 else 0.3


func _start_cut() -> void:
	_state = State.CUT
	_clock = 0.0
	_cut_done = false
	_dur = WIPE


## Put page [param i] up. [param same_set]: the cast walk between marks and the
## camera eases; otherwise it is a cut, and everyone standing walks in from the
## side of frame nearest their mark.
func _arrive(i: int, same_set: bool) -> void:
	var old_cam: Array = [camera.position, _cam_look_now, camera.fov]
	var was: Dictionary = {}
	for id in cast:
		var f: Figure = cast[id]
		if f.visible:
			was[id] = {"pos": f.position, "seated": f.seated}
	index = i
	var pg: Dictionary = pages[i]
	var set_name: String = pg["set"]
	var origin := Sets.origin(set_name)
	var root := _ensure_set(set_name)
	for s in sets:
		sets[s].visible = s == set_name
	_prune_sets(set_name)
	if not same_set:
		var n: int = _seen_sets.get(set_name, 0)
		_seen_sets[set_name] = n + 1
		var names: Array = CHAPTERS.get(set_name, [set_name])
		print("CHAPTER %.2f %s" % [_film_time, names[mini(n, names.size() - 1)]])
	var windows: Array = root.get_meta("windows", []) if set_name == "exterior" else []
	lighting.apply(pg.get("light", "golden"), origin, windows, not same_set)

	# Everyone to their marks first, so the shot (and its headroom) is framed
	# on where they will end up; then send the walkers back to where they start.
	var who: Dictionary = pg.get("cast", {})
	_walks.clear()
	for id in cast:
		var f: Figure = cast[id]
		f.talking = false
		if not who.has(id):
			if f.visible and same_set and not f.seated:
				_walk_to(id, _offstage(f.position, _side_of(f.position)), 1.2, {"hide": true})
			else:
				f.visible = false
				f.walking = false
			continue
		var c: Dictionary = who[id]
		var d: Dictionary = Story.CAST[id]
		f.visible = true
		f.walking = false
		f.set_costume(c.get("costume", d["costume"]), c.get("tint", d["tint"]))
		f.give_gun(c.get("gun", false))
		f.give_hat(c.get("hat", false), c.get("holed", false))
		f.position = origin + c.get("at", Vector3.ZERO)
		f.rotation.y = deg_to_rad(c.get("yaw", 0.0))
		f.set_seated(c.get("seated", false))
		f.set_pose(c.get("pose", "stand"), true)

	var cam: Array = pg["cam"]
	_cam_b = [origin + cam[0], origin + cam[1], pg.get("fov", 42.0)]
	if not same_set:
		_cam_a = _cam_b.duplicate()
		_cam_t = 1.0
		_cam_dur = 0.0
	_aim_camera(_cam_b)
	_make_headroom(pg)

	var longest := 0.0
	for id in who:
		var f: Figure = cast[id]
		var c: Dictionary = who[id]
		var mark: Vector3 = f.position
		if c.get("seated", false):
			continue   # seated people are discovered in their chairs
		var from: Vector3
		if same_set and was.has(id) and not was[id]["seated"]:
			from = was[id]["pos"]
			if from.distance_to(mark) < 0.25:
				continue
		else:
			from = _offstage(mark, _side_of(mark))
		var dur := maxf(from.distance_to(mark) / WALK_SPEED, 0.5)
		longest = maxf(longest, dur)
		_walk_to(id, mark, dur, {"from": from, "yaw": deg_to_rad(c.get("yaw", 0.0)), "pose": c.get("pose", "stand")})
	if same_set:
		# Ease the camera from the old shot to the new over the walk (or a beat).
		_cam_a = old_cam
		_cam_dur = maxf(longest, 0.9)
		_cam_t = 0.0
		_aim_camera(_cam_a)
		_dur = _cam_dur
	else:
		_dur = maxf(longest, 0.4)
	_beats = []
	_beat = -1


func _start_beats() -> void:
	var pg: Dictionary = pages[index]
	for id in cast:
		(cast[id] as Figure).walking = false
	letters.show_caption = false
	letters.show_caption2 = false
	letters.show_title = false
	letters.show_sfx = true
	letters.reveal = 0
	_beats = []
	# A breath before anyone speaks: the poses finish easing in, and the page
	# is laid out around where the heads actually are.
	_beats.append({"kind": "settle", "dur": SETTLE})
	if pg.has("title"):
		_beats.append({"kind": "title", "dur": TITLE_HOLD})
	if pg.has("caption"):
		_beats.append({"kind": "caption", "dur": _read(pg["caption"])})
	var said: Array = pg.get("say", [])
	for k in said.size():
		_beats.append({"kind": "say", "i": k, "who": said[k][0], "dur": _read(said[k][1], said[k].size() > 2 and said[k][2] == "shout")})
	if pg.has("caption2"):
		_beats.append({"kind": "caption2", "dur": _read(pg["caption2"])})
	if _beats.is_empty():
		_beats.append({"kind": "look", "dur": LOOK_HOLD})
	_beats.append({"kind": "tail", "dur": TAIL_HOLD})
	_beats_total = 0.0
	for b in _beats:
		_beats_total += b["dur"]
	_state = State.BEATS
	_beat = -1
	_next_beat()


func _next_beat() -> void:
	_beat += 1
	_clock = 0.0
	if _beat >= _beats.size():
		if not _check and DisplayServer.get_name() != "headless":
			for problem in letters.audit():
				_problems += 1
				print("LAYOUT page %d: %s" % [index + 1, problem])
		_leave_for(index + 1)
		return
	var b: Dictionary = _beats[_beat]
	for id in cast:
		(cast[id] as Figure).talking = false
	if _beat == 1 or (b["kind"] != "settle" and letters.page.is_empty()):
		_update_anchors()
		letters.page = pages[index]
	match b["kind"]:
		"title": letters.show_title = true
		"caption": letters.show_caption = true
		"caption2": letters.show_caption2 = true
		"say":
			letters.reveal = b["i"] + 1
			var f: Figure = cast.get(b["who"])
			if f:
				f.talking = true


## Seconds to read [param t]: a beat for the eye to land, then a third of a
## second a word. Shouts are short and go quicker.
func _read(t: String, shout: bool = false) -> float:
	var words := t.split(" ", false).size()
	return clampf(0.9 + words * (0.28 if shout else 0.34), MIN_BEAT, 7.5)


# --- Walking ----------------------------------------------------------------------------

func _walk_to(id: String, to: Vector3, dur: float, opts: Dictionary) -> void:
	var f: Figure = cast[id]
	var from: Vector3 = opts.get("from", f.position)
	f.position = from
	f.visible = true
	f.walking = true
	f.set_seated(false)
	f.set_pose("stand", true)
	var d := to - from
	if d.length() > 0.01:
		f.rotation.y = atan2(d.x, -d.z)
	_walks[id] = {"from": from, "to": to, "t": 0.0, "dur": maxf(dur, 0.01),
		"yaw": opts.get("yaw", f.rotation.y), "pose": opts.get("pose", "stand"), "hide": opts.get("hide", false)}


func _step_walks(delta: float) -> void:
	for id in _walks.keys():
		var w: Dictionary = _walks[id]
		var f: Figure = cast[id]
		w["t"] += delta
		var k: float = clampf(w["t"] / w["dur"], 0.0, 1.0)
		f.position = (w["from"] as Vector3).lerp(w["to"], k)
		if k >= 1.0:
			f.walking = false
			if w["hide"]:
				f.visible = false
			else:
				f.rotation.y = w["yaw"]
				f.set_pose(w["pose"], false)
			_walks.erase(id)


## Which side of frame [param p] is nearer: -1 left, +1 right.
func _side_of(p: Vector3) -> float:
	var s := camera.unproject_position(p)
	return -1.0 if s.x < get_viewport().get_visible_rect().size.x * 0.5 else 1.0


## A point off the edge of frame on [param side], level with [param mark].
func _offstage(mark: Vector3, side: float) -> Vector3:
	var right := camera.global_transform.basis.x
	right.y = 0.0
	right = right.normalized()
	var vp := get_viewport().get_visible_rect().size
	var k := 1.5
	while k < 16.0:
		var p := mark + right * side * k
		if camera.is_position_behind(p):
			return p
		var s := camera.unproject_position(p)
		if s.x < -160.0 or s.x > vp.x + 160.0:
			return p
		k += 0.5
	return mark + right * side * 8.0


# --- Camera -----------------------------------------------------------------------------

var _cam_look_now: Vector3


func _aim_camera(shot: Array) -> void:
	camera.position = shot[0]
	camera.fov = shot[2]
	_cam_look_now = shot[1]
	if not camera.position.is_equal_approx(shot[1]):
		camera.look_at(shot[1], Vector3.UP)


func _step_camera(delta: float) -> void:
	if _cam_t < 1.0 and _cam_dur > 0.0:
		_cam_t = minf(_cam_t + delta / _cam_dur, 1.0)
		var k := smoothstep(0.0, 1.0, _cam_t)
		_aim_camera([(_cam_a[0] as Vector3).lerp(_cam_b[0], k), (_cam_a[1] as Vector3).lerp(_cam_b[1], k), lerpf(_cam_a[2], _cam_b[2], k)])
	elif _state == State.BEATS and _beats_total > 0.0:
		# The slow push-in that keeps a still panel alive.
		var done := 0.0
		for b in range(_beat):
			done += _beats[b]["dur"]
		var k := clampf((done + _clock) / _beats_total, 0.0, 1.0)
		_aim_camera([(_cam_b[0] as Vector3).lerp(_cam_b[1], PUSH_IN * k), _cam_b[1], _cam_b[2]])


const HEADROOM := 0.46
const MAX_RISE := 1.4


## Comics leave room at the top of a panel for the words: on a page with
## dialogue the shot rises, same angle, until the highest speaking head sits
## a little below mid-panel. Computed with everyone on their marks.
func _make_headroom(pg: Dictionary) -> void:
	var said: Array = pg.get("say", [])
	if said.is_empty():
		return
	var panel := letters.panel_rect()
	var room := minf(HEADROOM + 0.08 * maxf(said.size() - 2, 0), 0.62)
	var want := panel.position.y + panel.size.y * room
	var risen := 0.0
	for _iter in 6:
		var top := INF
		var depth := 0.0
		for line in said:
			var f: Figure = cast.get(line[0])
			if f == null or not f.visible:
				continue
			var h := f.head_top()
			if camera.is_position_behind(h):
				continue
			var y := camera.unproject_position(h).y
			if y < top:
				top = y
				depth = -(camera.global_transform.affine_inverse() * h).z
		if top == INF or top >= want - 2.0 or risen >= MAX_RISE:
			return
		var per_px := 2.0 * depth * tan(deg_to_rad(camera.fov) * 0.5) / get_viewport().get_visible_rect().size.y
		var rise := minf((want - top) * per_px, MAX_RISE - risen)
		risen += rise
		_cam_b[0] += Vector3(0, rise, 0)
		_cam_b[1] += Vector3(0, rise, 0)
		_aim_camera(_cam_b)


func _update_anchors() -> void:
	var a := {}
	var faces := {}
	var vp := get_viewport().get_visible_rect()
	for id in cast:
		var f: Figure = cast[id]
		if not f.visible:
			continue
		var p := f.head_top()
		if camera.is_position_behind(p):
			continue
		var s := camera.unproject_position(p)
		if vp.grow(-8).has_point(s):
			a[id] = s
		var fr := Rect2()
		var first := true
		for q in f.face_corners():
			if camera.is_position_behind(q):
				continue
			var sq := camera.unproject_position(q)
			if first:
				fr = Rect2(sq, Vector2.ZERO)
				first = false
			else:
				fr = fr.expand(sq)
		if not first and fr.intersects(vp):
			faces[id] = fr.grow(8)
	letters.faces = faces
	letters.anchors = a


# --- Sets --------------------------------------------------------------------------------

func _ensure_set(name: String) -> Node3D:
	if sets.has(name):
		return sets[name]
	var root := Sets.build_one(name, world)
	sets[name] = root
	return root


func _prune_sets(current: String) -> void:
	var keep := {current: true}
	if _prev_set != "":
		keep[_prev_set] = true
	for s in sets.keys():
		if not keep.has(s):
			var n: Node3D = sets[s]
			sets.erase(s)
			n.queue_free()
	_prev_set = current


# --- Command line ---------------------------------------------------------------------------

func _arg(key: String) -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with(key + "="):
			return a.substr(key.length() + 1)
	return ""


func _has_flag(key: String) -> bool:
	return OS.get_cmdline_user_args().has(key)
