## Sets — the Angler's Rest and Bludleigh Court, built from primitives.
##
## Each set is built around its own origin and parked at its own spot along X,
## so the director only has to show one and point a camera at it. Convention:
## the camera stands at -Z looking toward +Z; a figure with yaw 0 faces it.
## Nothing here is hand-placed in an editor — change a number, rebuild.
class_name Sets
extends RefCounted

const SPACING := 120.0
const ORDER := ["parlour", "exterior", "hall", "dining", "gunroom", "moor"]


static func origin(set_name: String) -> Vector3:
	return Vector3(ORDER.find(set_name) * SPACING, 0, 0)


## Builds one set and returns its root. Sets are heavy — the hall alone is a
## couple of hundred mesh instances — so [param parent] (Main) builds them
## lazily, one or two at a time, rather than calling this for every name up
## front: six sets resident in GPU memory at once is fine on a desktop or the
## software rasterizer used for headless testing, but risks the tighter VRAM
## budget of a phone or older browser, which is the likeliest cause of a
## WebGL context loss a few pages in.
static func build_one(s: String, parent: Node3D) -> Node3D:
	var n := Node3D.new()
	n.name = s.capitalize().replace(" ", "")
	n.position = origin(s)
	parent.add_child(n)
	match s:
		"parlour": _parlour(n)
		"exterior": _exterior(n)
		"hall": _hall(n)
		"dining": _dining(n)
		"gunroom": _gunroom(n)
		"moor": _moor(n)
	return n


# --- Primitives ------------------------------------------------------------------

static func box(p: Node3D, size: Vector3, at: Vector3, c: Color, ink: float = 1.0, rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var bm := BoxMesh.new()
	bm.size = size
	return _mi(p, bm, at, Ink.mat(c, ink), rot)


static func cyl(p: Node3D, r_top: float, r_bot: float, h: float, at: Vector3, c: Color, ink: float = 1.0, rot: Vector3 = Vector3.ZERO, sides: int = 12) -> MeshInstance3D:
	var cm := CylinderMesh.new()
	cm.top_radius = r_top
	cm.bottom_radius = r_bot
	cm.height = h
	cm.radial_segments = sides
	cm.rings = 1
	return _mi(p, cm, at, Ink.mat(c, ink), rot)


static func ball(p: Node3D, r: float, at: Vector3, c: Color, squash: Vector3 = Vector3.ONE, ink: float = 1.0) -> MeshInstance3D:
	var sm := SphereMesh.new()
	sm.radius = r
	sm.height = r * 2.0
	sm.radial_segments = 14
	sm.rings = 7
	var mi := _mi(p, sm, at, Ink.mat(c, ink), Vector3.ZERO)
	mi.scale = squash
	return mi


static func prism(p: Node3D, size: Vector3, at: Vector3, c: Color, ink: float = 1.0, rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var pm := PrismMesh.new()
	pm.size = size
	return _mi(p, pm, at, Ink.mat(c, ink), rot)


static func flat(p: Node3D, size: Vector2, at: Vector3, m: Material, rot_y: float = PI) -> MeshInstance3D:
	var q := QuadMesh.new()
	q.size = size
	var mi := _mi(p, q, at, m, Vector3(0, rot_y, 0))
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


static func _mi(p: Node3D, mesh: Mesh, at: Vector3, m: Material, rot: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = m
	mi.position = at
	mi.rotation = rot
	p.add_child(mi)
	return mi


static func group(p: Node3D, at: Vector3, rot_y: float = 0.0, s: float = 1.0) -> Node3D:
	var g := Node3D.new()
	g.position = at
	g.rotation.y = rot_y
	g.scale = Vector3.ONE * s
	p.add_child(g)
	return g


# --- Furniture and fauna -----------------------------------------------------------

## A mounted stag's head on a shield, facing -Z out of a wall behind it.
static func stag_head(p: Node3D, at: Vector3, rot_y: float = 0.0, s: float = 1.0, ten_point: bool = true) -> Node3D:
	var g := group(p, at, rot_y, s)
	box(g, Vector3(0.55, 0.7, 0.06), Vector3(0, 0, 0.02), Ink.OAK_DARK)
	box(g, Vector3(0.24, 0.26, 0.34), Vector3(0, -0.02, -0.17), Ink.HIDE)
	box(g, Vector3(0.2, 0.22, 0.26), Vector3(0, 0.02, -0.4), Ink.HIDE, 1.0, Vector3(0.35, 0, 0))
	box(g, Vector3(0.12, 0.12, 0.2), Vector3(0, -0.06, -0.56), Ink.HIDE, 1.0, Vector3(0.55, 0, 0))
	box(g, Vector3(0.06, 0.05, 0.03), Vector3(0, -0.07, -0.66), Ink.INK, 0.5, Vector3(0.55, 0, 0))
	for side in [-1.0, 1.0]:
		box(g, Vector3(0.14, 0.05, 0.03), Vector3(side * 0.16, 0.12, -0.36), Ink.HIDE, 0.8, Vector3(0, 0, side * 0.5))
		box(g, Vector3(0.03, 0.03, 0.02), Vector3(side * 0.07, 0.1, -0.49), Ink.INK, 0.0)
		# Antler: a main beam up and out, tines forward off it.
		var a := group(g, Vector3(side * 0.07, 0.14, -0.38))
		box(a, Vector3(0.035, 0.5, 0.035), Vector3(side * 0.12, 0.22, 0), Ink.ANTLER, 0.8, Vector3(0, 0, -side * 0.55))
		box(a, Vector3(0.03, 0.34, 0.03), Vector3(side * 0.3, 0.52, 0.02), Ink.ANTLER, 0.8, Vector3(0, 0, -side * 0.15))
		var tines := 3 if ten_point else 2
		for i in tines:
			var y := 0.12 + i * 0.16
			box(a, Vector3(0.025, 0.2, 0.025), Vector3(side * (0.08 + i * 0.07), y + 0.08, -0.07), Ink.ANTLER, 0.7,
				Vector3(-0.7, 0, -side * 0.2))
	return g


## A trophy fish in a glass case.
static func fish_case(p: Node3D, at: Vector3, rot_y: float = 0.0) -> void:
	var g := group(p, at, rot_y)
	box(g, Vector3(0.9, 0.42, 0.18), Vector3(0, 0, 0), Ink.OAK_DARK)
	box(g, Vector3(0.8, 0.34, 0.02), Vector3(0, 0, -0.1), Color("cfe0da"), 0.0)
	ball(g, 0.14, Vector3(0.02, 0, -0.03), Color("9aa27a"), Vector3(2.2, 0.8, 0.4), 0.6)
	prism(g, Vector3(0.14, 0.18, 0.04), Vector3(-0.34, 0, -0.03), Color("8a9268"), 0.6, Vector3(0, 0, PI * 0.5))


static func crossed_guns(p: Node3D, at: Vector3, rot_y: float = 0.0) -> void:
	var g := group(p, at, rot_y)
	for side in [-1.0, 1.0]:
		var r := Vector3(0, 0, side * 0.7)
		box(g, Vector3(0.05, 1.2, 0.04), Vector3(0, 0, 0), Ink.GUNMETAL, 0.8, r)
		var st := group(g, Vector3.ZERO)
		st.rotation.z = side * 0.7
		box(st, Vector3(0.09, 0.36, 0.06), Vector3(0, -0.66, 0), Ink.WALNUT, 0.8)


static func painting(p: Node3D, at: Vector3, size: Vector2, sky: Color, land: Color, rot_y: float = 0.0, beast: Color = Ink.HIDE) -> void:
	var g := group(p, at, rot_y)
	box(g, Vector3(size.x + 0.16, size.y + 0.16, 0.06), Vector3.ZERO, Ink.BRASS, 0.8)
	box(g, Vector3(size.x, size.y * 0.55, 0.02), Vector3(0, size.y * 0.22, -0.035), sky, 0.0)
	box(g, Vector3(size.x, size.y * 0.45, 0.02), Vector3(0, -size.y * 0.27, -0.035), land, 0.0)
	# A beast at bay and a horseman: two blobs, which is all a hunting print is.
	box(g, Vector3(size.x * 0.18, size.y * 0.14, 0.02), Vector3(size.x * 0.18, -size.y * 0.12, -0.05), beast, 0.4)
	box(g, Vector3(size.x * 0.1, size.y * 0.28, 0.02), Vector3(-size.x * 0.22, -size.y * 0.06, -0.05), Ink.CLARET, 0.4)


static func tree(p: Node3D, at: Vector3, s: float = 1.0, leaf: Color = Ink.LEAF) -> void:
	var g := group(p, at, 0.0, s)
	cyl(g, 0.16, 0.26, 2.6, Vector3(0, 1.3, 0), Ink.BARK)
	ball(g, 1.3, Vector3(0, 3.3, 0), leaf, Vector3(1.1, 0.9, 1.0))
	ball(g, 0.95, Vector3(0.8, 2.8, -0.3), leaf.darkened(0.12), Vector3(1.0, 0.85, 1.0))
	ball(g, 0.9, Vector3(-0.8, 2.9, 0.2), leaf.lightened(0.08), Vector3(1.0, 0.85, 1.0))


static func chair(p: Node3D, at: Vector3, rot_y: float = 0.0, c: Color = Ink.OAK_DARK) -> void:
	var g := group(p, at, rot_y)
	box(g, Vector3(0.48, 0.06, 0.46), Vector3(0, 0.46, 0), c)
	box(g, Vector3(0.48, 0.62, 0.06), Vector3(0, 0.78, 0.22), c)
	for x in [-0.2, 0.2]:
		for z in [-0.19, 0.19]:
			box(g, Vector3(0.05, 0.46, 0.05), Vector3(x, 0.23, z), c, 0.6)


static func candle(p: Node3D, at: Vector3) -> void:
	cyl(p, 0.05, 0.08, 0.06, at, Ink.BRASS, 0.6)
	cyl(p, 0.025, 0.025, 0.26, at + Vector3(0, 0.16, 0), Ink.CLOTH, 0.5)
	ball(p, 0.03, at + Vector3(0, 0.33, 0), Color("ffd27a"), Vector3(0.8, 1.6, 0.8), 0.0).material_override = Ink.glow(Color("ffd98a"))


static func bottle(p: Node3D, at: Vector3, c: Color = Ink.BOTTLE) -> void:
	cyl(p, 0.05, 0.05, 0.22, at + Vector3(0, 0.11, 0), c, 0.5, Vector3.ZERO, 8)
	cyl(p, 0.018, 0.03, 0.1, at + Vector3(0, 0.27, 0), c, 0.5, Vector3.ZERO, 8)


static func tankard(p: Node3D, at: Vector3) -> void:
	cyl(p, 0.06, 0.07, 0.16, at + Vector3(0, 0.08, 0), Color("a7a39a"), 0.6, Vector3.ZERO, 10)
	cyl(p, 0.055, 0.055, 0.02, at + Vector3(0, 0.165, 0), Color("f1e6c8"), 0.0, Vector3.ZERO, 10)


static func wainscot_room(p: Node3D, w: float, d: float, h: float, lower: Color, upper: Color, floor_c: Color) -> void:
	box(p, Vector3(w, 0.1, d), Vector3(0, -0.05, 0), floor_c, 0.0)
	# Back wall and both side walls: dark panelling below, plaster above.
	var dado := 1.2
	box(p, Vector3(w, dado, 0.2), Vector3(0, dado * 0.5, d * 0.5), lower)
	box(p, Vector3(w, h - dado, 0.2), Vector3(0, dado + (h - dado) * 0.5, d * 0.5), upper)
	for side in [-1.0, 1.0]:
		box(p, Vector3(0.2, dado, d), Vector3(side * w * 0.5, dado * 0.5, 0), lower)
		box(p, Vector3(0.2, h - dado, d), Vector3(side * w * 0.5, dado + (h - dado) * 0.5, 0), upper)
	# A picture rail and a skirting line: ink where the eye expects a joint.
	box(p, Vector3(w, 0.08, 0.26), Vector3(0, dado, d * 0.5 - 0.02), lower.darkened(0.25), 0.6)
	# Floorboards read as boards only if some of them are drawn.
	for i in range(int(w / 0.9)):
		box(p, Vector3(0.02, 0.012, d), Vector3(-w * 0.5 + 0.45 + i * 0.9, 0.001, 0), floor_c.darkened(0.25), 0.0)


static func tufts(p: Node3D, count: int, area: Rect2, colors: Array, rng: RandomNumberGenerator, size: float = 0.35, y: float = 0.0, keep_clear: Callable = Callable(), spiky: bool = false) -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	if spiky:
		# Heather and bracken: a low cone reads as a shrub; a ball reads as a stone.
		var cm := CylinderMesh.new()
		cm.top_radius = 0.0
		cm.bottom_radius = size
		cm.height = size * 2.4
		cm.radial_segments = 5
		cm.rings = 1
		mm.mesh = cm
	else:
		var sm := SphereMesh.new()
		sm.radius = size
		sm.height = size * 1.2
		sm.radial_segments = 8
		sm.rings = 4
		mm.mesh = sm
	var pts: Array = []
	var tries := 0
	while pts.size() < count and tries < count * 4:
		tries += 1
		var v := Vector2(rng.randf_range(area.position.x, area.end.x), rng.randf_range(area.position.y, area.end.y))
		if keep_clear.is_valid() and keep_clear.call(v):
			continue
		pts.append(v)
	mm.instance_count = pts.size()
	for i in pts.size():
		var s := rng.randf_range(0.6, 1.4)
		var t := Transform3D(Basis.from_scale(Vector3(s * 1.3, s * 0.7, s)), Vector3(pts[i].x, y, pts[i].y))
		mm.set_instance_transform(i, t)
		var c: Color = colors[rng.randi() % colors.size()]
		mm.set_instance_color(i, c)
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = Ink.mat(Color.WHITE, 0.7)
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.add_child(mmi)


# --- The Angler's Rest ---------------------------------------------------------------

static func _parlour(p: Node3D) -> void:
	wainscot_room(p, 11.0, 9.0, 3.4, Ink.PANEL, Color("b7ab94"), Ink.OAK)
	# The bar: counter, brass rail, a mirror and shelves of bottles behind.
	var bar := group(p, Vector3(0.6, 0, 3.0))
	box(bar, Vector3(6.0, 1.05, 0.7), Vector3(0, 0.525, 0), Ink.OAK_DARK)
	box(bar, Vector3(6.2, 0.07, 0.86), Vector3(0, 1.08, 0), Ink.OAK)
	cyl(bar, 0.025, 0.025, 6.0, Vector3(0, 0.22, -0.48), Ink.BRASS, 0.5, Vector3(0, 0, PI * 0.5))
	box(p, Vector3(4.0, 1.3, 0.05), Vector3(0.6, 2.25, 4.38), Color("b9c7c4"), 0.6)
	for row in 2:
		box(p, Vector3(5.4, 0.05, 0.3), Vector3(0.6, 1.5 + row * 1.1, 4.25), Ink.OAK_DARK, 0.6)
		for i in 12:
			var c: Color = [Ink.BOTTLE, Color("6b3a26"), Color("b8a36a"), Color("3a4a5c")][(i + row) % 4]
			bottle(p, Vector3(-1.9 + i * 0.42, 1.53 + row * 1.1, 4.22), c)
	tankard(p, Vector3(-0.4, 1.12, 2.8))
	tankard(p, Vector3(1.9, 1.12, 2.75))
	# The hot Scotch and lemon, which is how you know which one is Mr Mulliner's.
	cyl(p, 0.05, 0.04, 0.12, Vector3(0.75, 1.18, 2.72), Color("e8d9a8"), 0.5)
	# Stools.
	for x in [-1.3, 0.2, 1.7]:
		cyl(p, 0.2, 0.2, 0.06, Vector3(x, 0.72, 2.2), Ink.OAK, 0.8)
		cyl(p, 0.035, 0.05, 0.7, Vector3(x, 0.35, 2.2), Ink.OAK_DARK, 0.6)
	# Fireplace on the left wall, with a fish over it (anglers).
	var fp := group(p, Vector3(-5.35, 0, 0.3), PI * 0.5)
	box(fp, Vector3(1.9, 1.4, 0.4), Vector3(0, 0.7, 0), Ink.STONE)
	box(fp, Vector3(1.1, 0.8, 0.3), Vector3(0, 0.45, -0.1), Ink.INK, 0.0)
	box(fp, Vector3(2.1, 0.1, 0.5), Vector3(0, 1.45, -0.05), Ink.OAK_DARK)
	ball(fp, 0.16, Vector3(0, 0.22, -0.2), Color("ff9a3c"), Vector3(1.8, 1.2, 0.8), 0.0).material_override = Ink.glow(Color("ffa24a"))
	fish_case(p, Vector3(-5.3, 2.2, 0.3), -PI * 0.5)
	# A table and settle down front for the regulars.
	box(p, Vector3(1.1, 0.06, 0.8), Vector3(-2.8, 0.74, 0.2), Ink.OAK)
	cyl(p, 0.06, 0.1, 0.72, Vector3(-2.8, 0.36, 0.2), Ink.OAK_DARK, 0.6)
	tankard(p, Vector3(-2.7, 0.77, 0.1))
	# A window on the right with the dusk showing through.
	box(p, Vector3(0.2, 1.4, 1.6), Vector3(5.45, 2.0, 0.5), Ink.OAK_DARK)
	flat(p, Vector2(1.4, 1.2), Vector3(5.33, 2.0, 0.5), Ink.glow(Color("e9c98a")), -PI * 0.5)
	box(p, Vector3(0.05, 1.2, 0.05), Vector3(5.3, 2.0, 0.5), Ink.OAK_DARK, 0.5)
	box(p, Vector3(0.05, 0.05, 1.4), Vector3(5.3, 2.0, 0.5), Ink.OAK_DARK, 0.5)
	# Beams across the top of the frame.
	for z in [-2.5, 0.5, 3.5]:
		box(p, Vector3(11.0, 0.3, 0.3), Vector3(0, 3.35, z), Ink.OAK_DARK)


# --- Bludleigh Court, from the drive ---------------------------------------------------

static func _exterior(p: Node3D) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1929
	box(p, Vector3(90, 0.1, 90), Vector3(0, -0.05, 20), Ink.GRASS, 0.0)
	box(p, Vector3(5.0, 0.02, 30), Vector3(0, 0.01, -4), Ink.GRAVEL, 0.0)
	box(p, Vector3(16, 0.02, 4.5), Vector3(0, 0.012, 4.2), Ink.GRAVEL, 0.0)
	# The house: a long stone front, two storeys and an attic of windows.
	var h := group(p, Vector3(0, 0, 11.0))
	box(h, Vector3(26, 9.0, 7.0), Vector3(0, 4.5, 0), Ink.STONE)
	box(h, Vector3(26.6, 0.4, 7.4), Vector3(0, 9.1, 0), Ink.STONE_DARK)
	prism(h, Vector3(26, 3.2, 7.0), Vector3(0, 10.9, 0), Ink.SLATE)
	for x in [-9.0, 9.0]:
		box(h, Vector3(1.0, 2.6, 1.0), Vector3(x, 12.0, 0.6), Ink.STONE_DARK)
	for x in [-10.5, 10.5]:
		box(h, Vector3(5.0, 10.0, 7.6), Vector3(x, 5.0, -0.3), Ink.STONE.darkened(0.05))
	h.set_meta("windows", [])
	var lit: Array = []
	for row in 2:
		for i in 10:
			var x := -11.5 + i * 2.55
			if absf(x) < 2.0 and row == 0:
				continue
			var y := 2.4 + row * 3.6
			box(h, Vector3(1.2, 2.0, 0.12), Vector3(x, y, -3.52), Ink.STONE_DARK, 0.6)
			var w := flat(h, Vector2(0.95, 1.75), Vector3(x, y, -3.6), Ink.glow(Color("4a4f5a")))
			w.set_meta("window", true)
			lit.append(w)
			box(h, Vector3(0.05, 1.75, 0.04), Vector3(x, y, -3.62), Ink.STONE_DARK, 0.0)
			box(h, Vector3(0.95, 0.05, 0.04), Vector3(x, y + 0.2, -3.62), Ink.STONE_DARK, 0.0)
	p.set_meta("windows", lit)
	# Portico: steps, columns, pediment, the door, and a stag over the door.
	var po := group(p, Vector3(0, 0, 6.6))
	for i in 4:
		box(po, Vector3(6.4 - i * 0.4, 0.2, 2.4 - i * 0.45), Vector3(0, 0.1 + i * 0.2, -0.6 + i * 0.22), Ink.STONE)
	for x in [-2.2, -0.8, 0.8, 2.2]:
		cyl(po, 0.24, 0.28, 3.6, Vector3(x, 2.6, -0.2), Ink.STONE.lightened(0.08))
	box(po, Vector3(5.4, 0.45, 1.6), Vector3(0, 4.6, -0.5), Ink.STONE)
	prism(po, Vector3(5.6, 1.3, 1.5), Vector3(0, 5.45, -0.5), Ink.STONE.lightened(0.04))
	box(po, Vector3(1.6, 2.7, 0.14), Vector3(0, 2.15, 0.9), Ink.OAK_DARK)
	box(po, Vector3(0.05, 2.6, 0.02), Vector3(0, 2.15, 0.82), Ink.INK, 0.0)
	stag_head(po, Vector3(0, 3.95, 0.82), 0.0, 0.8)
	# The door-knocker, which is also a stag.
	stag_head(po, Vector3(0.4, 2.1, 0.8), 0.0, 0.16, false)
	# Trees and yew hedges.
	for t in [Vector3(-9, 0, 1), Vector3(9.5, 0, 0), Vector3(-15, 0, -4), Vector3(14, 0, -6), Vector3(-19, 0, 8), Vector3(19, 0, 9)]:
		tree(p, t, rng.randf_range(0.95, 1.3), [Ink.LEAF, Ink.LEAF_DARK][rng.randi() % 2])
	for side in [-1.0, 1.0]:
		for i in 5:
			ball(p, 0.7, Vector3(side * 3.4, 0.6, -2.0 - i * 2.6), Ink.LEAF_DARK, Vector3(1.0, 1.3, 1.0), 0.8)
	tufts(p, 160, Rect2(-30, -20, 60, 24), [Ink.GRASS, Ink.GRASS_DARK, Ink.GRASS.lightened(0.1)], rng, 0.22, 0.0,
		func(v: Vector2) -> bool: return absf(v.x) < 3.2 or (v.y > 1.5 and absf(v.x) < 9.0))
	# The motor, a 1920s tourer in the family blue.
	var car := group(p, Vector3(-1.2, 0, -1.6), -PI * 0.08)
	box(car, Vector3(1.6, 0.5, 3.8), Vector3(0, 0.75, 0), Ink.MOTOR)
	box(car, Vector3(1.2, 0.55, 1.4), Vector3(0, 1.05, -1.2), Ink.MOTOR.lightened(0.08))
	box(car, Vector3(1.45, 0.4, 1.9), Vector3(0, 1.18, 0.7), Ink.OAK_DARK)
	box(car, Vector3(1.2, 0.5, 0.04), Vector3(0, 1.55, -0.35), Color("c9dcdf"), 0.6, Vector3(-0.2, 0, 0))
	box(car, Vector3(1.0, 0.7, 0.1), Vector3(0, 1.02, -1.92), Ink.BRASS, 0.8)
	for x in [-0.82, 0.82]:
		for z in [-1.25, 1.3]:
			cyl(car, 0.38, 0.38, 0.22, Vector3(x, 0.38, z), Ink.INK, 0.6, Vector3(0, 0, PI * 0.5), 14)
			cyl(car, 0.16, 0.16, 0.24, Vector3(x, 0.38, z), Ink.CLOTH, 0.0, Vector3(0, 0, PI * 0.5), 10)
	# Luggage strapped on the back, which is how you know they came to stay.
	box(car, Vector3(1.1, 0.5, 0.5), Vector3(0, 1.1, 2.05), Ink.HIDE)


# --- The great hall -----------------------------------------------------------------

static func _hall(p: Node3D) -> void:
	wainscot_room(p, 16.0, 11.0, 6.5, Ink.PANEL, Ink.PLASTER, Ink.OAK)
	box(p, Vector3(6.5, 0.02, 4.0), Vector3(0, 0.02, 0.8), Ink.CLARET, 0.0)
	box(p, Vector3(6.0, 0.022, 3.5), Vector3(0, 0.022, 0.8), Ink.CLARET.lightened(0.12), 0.0)
	# Fireplace, centre back.
	var fp := group(p, Vector3(0, 0, 5.2))
	box(fp, Vector3(3.2, 2.4, 0.6), Vector3(0, 1.2, 0), Ink.STONE)
	box(fp, Vector3(1.8, 1.4, 0.4), Vector3(0, 0.7, -0.15), Ink.INK, 0.0)
	box(fp, Vector3(3.6, 0.18, 0.8), Vector3(0, 2.45, -0.1), Ink.OAK_DARK)
	for x in [-0.4, 0.0, 0.4]:
		ball(fp, 0.22, Vector3(x, 0.3, -0.3), Color("ff9a3c"), Vector3(1.0, 1.6, 0.8), 0.0).material_override = Ink.glow(Color("ffab52"))
	# The monarch of the glen over the mantel, and his relations everywhere else.
	stag_head(p, Vector3(0, 4.3, 5.35), 0.0, 1.6)
	for i in 6:
		var x: float = [-6.4, -4.6, -2.8, 2.8, 4.6, 6.4][i]
		var y := 3.1 if i % 2 == 0 else 4.7
		stag_head(p, Vector3(x, y, 5.35), 0.0, 0.9 + (i % 3) * 0.12, i % 2 == 0)
	for i in 4:
		var z := -3.0 + i * 2.2
		stag_head(p, Vector3(-7.85, 3.6 + (i % 2) * 1.3, z), PI * 0.5, 0.95, i % 2 == 1)
		stag_head(p, Vector3(7.85, 3.6 + ((i + 1) % 2) * 1.3, z), -PI * 0.5, 0.95, i % 2 == 0)
	fish_case(p, Vector3(-4.6, 1.8, 5.3))
	fish_case(p, Vector3(4.6, 1.8, 5.3))
	crossed_guns(p, Vector3(-2.3, 2.1, 5.35))
	crossed_guns(p, Vector3(2.3, 2.1, 5.35))
	# A bear, rearing, by the fire. Nobody at Bludleigh remembers where it came from.
	var bear := group(p, Vector3(3.4, 0, 3.7), -0.35)
	var fur := Color("5a4232")
	box(bear, Vector3(0.95, 1.5, 0.7), Vector3(0, 1.15, 0), fur)
	box(bear, Vector3(0.6, 0.5, 0.55), Vector3(0, 2.1, -0.05), fur)
	box(bear, Vector3(0.28, 0.22, 0.3), Vector3(0, 2.02, -0.42), fur.lightened(0.15))
	box(bear, Vector3(0.1, 0.07, 0.05), Vector3(0, 2.07, -0.58), Ink.INK, 0.0)
	for s in [-1.0, 1.0]:
		box(bear, Vector3(0.16, 0.16, 0.08), Vector3(s * 0.22, 2.4, -0.02), fur)
		box(bear, Vector3(0.24, 0.8, 0.24), Vector3(s * 0.55, 1.8, -0.2), fur, 1.0, Vector3(0.9, 0, s * 0.5))
		box(bear, Vector3(0.3, 0.7, 0.34), Vector3(s * 0.25, 0.35, 0), fur)
	# A long table down one side, guns and a game book on it.
	box(p, Vector3(0.9, 0.08, 3.0), Vector3(-5.8, 0.85, 1.2), Ink.OAK)
	for z in [0.0, 2.4]:
		box(p, Vector3(0.7, 0.8, 0.08), Vector3(-5.8, 0.4, z), Ink.OAK_DARK, 0.6)
	box(p, Vector3(0.4, 0.06, 0.3), Vector3(-5.8, 0.92, 0.6), Ink.CLARET, 0.6)
	box(p, Vector3(0.1, 0.05, 1.3), Vector3(-5.7, 0.92, 1.8), Ink.GUNMETAL, 0.6)


# --- The dining room -----------------------------------------------------------------

static func _dining(p: Node3D) -> void:
	wainscot_room(p, 12.0, 9.0, 4.2, Ink.PANEL, Color("8c3a34"), Ink.OAK_DARK)
	# Hunting prints and a boar.
	painting(p, Vector3(-3.4, 2.6, 4.35), Vector2(1.8, 1.1), Color("d9c9a2"), Color("7d8a5a"))
	painting(p, Vector3(3.4, 2.6, 4.35), Vector2(1.8, 1.1), Color("cdb99a"), Color("8a7a52"), 0.0, Color("b0643a"))
	var boar := group(p, Vector3(0, 2.9, 4.35))
	box(boar, Vector3(0.6, 0.6, 0.06), Vector3(0, 0, 0.02), Ink.OAK_DARK)
	box(boar, Vector3(0.36, 0.36, 0.4), Vector3(0, -0.02, -0.2), Color("4a3a30"))
	box(boar, Vector3(0.2, 0.18, 0.2), Vector3(0, -0.08, -0.46), Color("5a463a"))
	for s in [-1.0, 1.0]:
		box(boar, Vector3(0.03, 0.12, 0.03), Vector3(s * 0.09, -0.02, -0.52), Ink.ANTLER, 0.5, Vector3(0, 0, s * 0.4))
	# Sideboard with a salmon on a platter.
	box(p, Vector3(2.6, 0.95, 0.6), Vector3(0, 0.47, 4.0), Ink.OAK)
	ball(p, 0.15, Vector3(0, 1.05, 3.95), Color("d98a6a"), Vector3(3.0, 0.7, 1.0), 0.6)
	# The long table, laid.
	box(p, Vector3(6.2, 0.1, 1.9), Vector3(0, 0.78, 0.4), Ink.OAK_DARK)
	box(p, Vector3(6.3, 0.03, 2.0), Vector3(0, 0.845, 0.4), Color("d9cdb4"), 0.0)
	for x in [-2.8, 2.8]:
		for z in [-0.35, 1.15]:
			box(p, Vector3(0.1, 0.78, 0.1), Vector3(x, 0.39, z), Ink.OAK_DARK, 0.6)
	for x in [-2.0, -0.8, 0.4, 1.6]:
		for z in [-0.2, 1.0]:
			cyl(p, 0.16, 0.14, 0.02, Vector3(x + 0.2, 0.87, z), Color("f4efe2"), 0.4, Vector3.ZERO, 14)
	for x in [-1.3, 1.3]:
		candle(p, Vector3(x, 0.86, 0.4))
		candle(p, Vector3(x - 0.15, 0.86, 0.3))
		candle(p, Vector3(x + 0.15, 0.86, 0.5))
	# The pheasant, the centre of the table and of every conversation.
	ball(p, 0.2, Vector3(0, 0.98, 0.4), Color("b8793c"), Vector3(1.3, 0.8, 1.0))
	cyl(p, 0.35, 0.28, 0.04, Vector3(0, 0.87, 0.4), Color("e4ddcf"), 0.5, Vector3.ZERO, 16)
	# Chairs along the far side (facing us) and the ends.
	for x in [-2.0, -0.8, 0.4, 1.6]:
		chair(p, Vector3(x + 0.2, 0, 1.75), 0.0)
	chair(p, Vector3(-3.35, 0, 0.4), -PI * 0.5)
	chair(p, Vector3(3.35, 0, 0.4), PI * 0.5)
	# Candle sconces on the back wall.
	for x in [-5.0, 5.0]:
		candle(p, Vector3(x, 2.4, 4.3))


# --- The gun-room ------------------------------------------------------------------------

static func _gunroom(p: Node3D) -> void:
	wainscot_room(p, 9.0, 7.0, 3.6, Ink.OAK_DARK, Color("b9b39f"), Ink.OAK)
	# The rack: a dozen guns stood upright in a walnut frame.
	var rack := group(p, Vector3(-1.4, 0, 3.3))
	box(rack, Vector3(3.6, 0.12, 0.4), Vector3(0, 0.3, 0), Ink.WALNUT)
	box(rack, Vector3(3.6, 0.1, 0.25), Vector3(0, 1.5, 0.05), Ink.WALNUT)
	box(rack, Vector3(3.8, 0.12, 0.45), Vector3(0, 2.05, 0), Ink.WALNUT)
	for i in 11:
		var x := -1.6 + i * 0.32
		box(rack, Vector3(0.08, 0.5, 0.11), Vector3(x, 0.6, 0), Ink.WALNUT.lightened(0.08), 0.6)
		box(rack, Vector3(0.05, 1.3, 0.05), Vector3(x, 1.45, 0.02), Ink.GUNMETAL, 0.6)
	# Antlers over the rack, naturally.
	stag_head(p, Vector3(-1.4, 2.8, 3.4), 0.0, 0.8)
	# The cleaning table, cartridges, a gun broken open, a game book.
	box(p, Vector3(2.4, 0.08, 1.1), Vector3(1.4, 0.86, 0.9), Ink.OAK)
	for x in [0.5, 2.3]:
		for z in [0.5, 1.3]:
			box(p, Vector3(0.08, 0.86, 0.08), Vector3(x, 0.43, z), Ink.OAK_DARK, 0.6)
	for i in 4:
		box(p, Vector3(0.26, 0.14, 0.18), Vector3(0.8 + (i % 2) * 0.3, 0.97 + (i / 2) * 0.15, 1.1), Color("b0402e"), 0.6)
	box(p, Vector3(0.9, 0.05, 0.05), Vector3(1.8, 0.93, 0.8), Ink.GUNMETAL, 0.6, Vector3(0, 0.3, 0))
	box(p, Vector3(0.4, 0.07, 0.08), Vector3(2.35, 0.93, 0.95), Ink.WALNUT, 0.6, Vector3(0, 0.3, 0))
	box(p, Vector3(0.3, 0.04, 0.4), Vector3(1.0, 0.92, 0.6), Ink.CLARET, 0.6)
	# Boots, coats on pegs.
	for i in 3:
		box(p, Vector3(0.18, 0.4, 0.3), Vector3(3.2 + i * 0.3, 0.2, 2.9), Ink.OAK_DARK, 0.6)
	for i in 3:
		box(p, Vector3(0.5, 1.0, 0.12), Vector3(3.3, 1.9, 3.3 - i * 0.02), [Color("6f7a55"), Color("8a7a52"), Color("5b5a40")][i], 0.8, Vector3(0, 0, 0.1 * (i - 1)))
	# A tall window on the left wall throwing the morning in.
	box(p, Vector3(0.24, 2.4, 1.8), Vector3(-4.45, 1.9, 0.5), Ink.OAK_DARK)
	flat(p, Vector2(1.5, 2.1), Vector3(-4.3, 1.9, 0.5), Ink.glow(Color("eef1ea")), PI * 0.5)
	box(p, Vector3(0.05, 2.1, 0.05), Vector3(-4.28, 1.9, 0.5), Ink.OAK_DARK, 0.5)
	box(p, Vector3(0.05, 0.05, 1.5), Vector3(-4.28, 2.2, 0.5), Ink.OAK_DARK, 0.5)


# --- The moor --------------------------------------------------------------------------

static func _moor(p: Node3D) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 12
	box(p, Vector3(200, 0.1, 200), Vector3(0, -0.05, 40), Ink.HEATHER_DARK, 0.0)
	# Rolling ground: big squashed hills, heather-purple and bracken-brown.
	var hills := [
		[Vector3(-30, -6, 45), 22.0, Ink.HEATHER], [Vector3(10, -8, 60), 28.0, Ink.HEATHER_DARK],
		[Vector3(40, -7, 40), 20.0, Ink.BRACKEN], [Vector3(-8, -5.5, 30), 14.0, Ink.HEATHER.lightened(0.06)],
		[Vector3(22, -4.5, 22), 10.0, Ink.BRACKEN.darkened(0.1)], [Vector3(-60, -10, 70), 34.0, Ink.HEATHER_DARK.lightened(0.05)],
	]
	for h in hills:
		ball(p, h[1], h[0], h[2], Vector3(1.6, 0.45, 1.0), 0.6)
	# The rise they stand on, and a grouse butt of dry stone.
	ball(p, 9.0, Vector3(0, -7.2, 4), Ink.HEATHER, Vector3(1.5, 0.95, 1.2), 0.0)
	var butt := group(p, Vector3(0, 1.3, 1.4))
	for i in 9:
		var a := PI * 0.1 + i * PI * 0.1
		box(butt, Vector3(0.7, 0.9, 0.35), Vector3(cos(a) * 1.8, 0.1, sin(a) * 1.8 + 0.2), Ink.STONE_DARK, 1.0, Vector3(0, -a + PI * 0.5, 0))
	tufts(p, 700, Rect2(-14, -8, 28, 20), [Ink.HEATHER, Ink.HEATHER_DARK, Ink.HEATHER.lightened(0.1), Ink.BRACKEN.darkened(0.15)], rng, 0.16, 1.05,
		func(v: Vector2) -> bool: return v.length() < 2.4, true)
	# A dry-stone wall running away over the hill.
	for i in 30:
		box(p, Vector3(1.9, 0.9, 0.5), Vector3(-26 + i * 1.95, 0.2 + sin(i * 0.3) * 0.3, 16 + i * 0.4), Ink.STONE_DARK, 0.7, Vector3(0, -0.2, 0))
	# The copse on the skyline.
	for i in 7:
		tree(p, Vector3(18 + i * 2.4, 3.0 + rng.randf() * 1.2, 44 + rng.randf() * 4), 1.3, Ink.LEAF_DARK)
	# Clouds: flat paper shapes, unlit. One of them has been shot.
	for c in [[Vector3(-14, 18, 55), 5.0], [Vector3(8, 22, 70), 7.0], [Vector3(26, 17, 50), 4.0], [Vector3(-34, 24, 80), 8.0]]:
		var g := group(p, c[0])
		for j in 4:
			var m := ball(g, c[1] * (0.55 + j * 0.12), Vector3((j - 1.5) * c[1] * 0.7, (j % 2) * c[1] * 0.25, 0), Color("fbf6ea"), Vector3(1.4, 0.7, 0.35), 0.0)
			m.material_override = Ink.glow(Color("f7f0e0"))
			m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# The birds: black ticks in the sky, as every hunting print draws them.
	var birds := group(p, Vector3(4, 9, 22))
	birds.name = "Birds"
	for i in 7:
		var b := group(birds, Vector3(rng.randf_range(-6, 6), rng.randf_range(-1.5, 2.5), rng.randf_range(-2, 2)))
		for s in [-1.0, 1.0]:
			box(b, Vector3(0.5, 0.06, 0.1), Vector3(s * 0.22, 0.08, 0), Ink.INK, 0.0, Vector3(0, 0, s * 0.45))
	p.set_meta("birds", birds)
