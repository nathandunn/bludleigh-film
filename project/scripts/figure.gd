## Figure — the paper doll from flipbook-field, cast as a Wodehouse character.
##
## Every part is a slim slab with a drawing on its front and another on its
## back. The head is one of Nathan's pen drawings; its back is inferred from it.
## Costumes are the bodygen.py drawings, repurposed: the legal waistcoat and
## bow tie make a poet, the engineer's plaid makes shooting tweeds.
##
## Poses are targets the rig eases toward, and the easing is quantised to 12 fps
## like everything else — stepped poses read as drawn frames.
class_name Figure
extends Node3D

const FLIPBOOK_FPS := 12.0

const HIP_Y := 0.76
const TORSO_H := 0.58
const TORSO_W := 0.50
const SHOULDER_DROP := 0.06
const ARM_LEN := 0.56
const ARM_W := 0.15
const LEG_LEN := 0.74
const LEG_W := 0.18
const HEAD := Vector3(0.38, 0.40, 0.36)
const CARD := 0.62
const SLAB := 0.12

## Arm swing (x) and splay (z) for each arm, head pitch/roll, torso lean.
## Positive arm x swings the hand forward; negative head x bows the head.
const POSES := {
	"stand":   {"al": Vector2(0.05, 0.0),  "ar": Vector2(0.05, 0.0),  "hx": 0.0,   "hz": 0.0,   "lean": 0.0},
	"clasp":   {"al": Vector2(0.55, 0.35), "ar": Vector2(0.55, -0.35), "hx": 0.0,  "hz": 0.0,   "lean": 0.0},
	"talk":    {"al": Vector2(0.05, 0.0),  "ar": Vector2(0.9, -0.2),  "hx": 0.05,  "hz": 0.0,   "lean": 0.0},
	"point":   {"al": Vector2(0.05, 0.0),  "ar": Vector2(1.45, -0.1), "hx": 0.05,  "hz": 0.0,   "lean": 0.05},
	"shock":   {"al": Vector2(0.3, 0.75),  "ar": Vector2(0.3, -0.75), "hx": 0.12,  "hz": 0.0,   "lean": -0.08},
	"cling":   {"al": Vector2(0.7, -0.5),  "ar": Vector2(0.7, -0.9),  "hx": -0.05, "hz": -0.18, "lean": 0.0},
	"recite":  {"al": Vector2(0.05, 0.0),  "ar": Vector2(1.2, -0.55), "hx": 0.18,  "hz": 0.0,   "lean": -0.04},
	"relish":  {"al": Vector2(0.4, 0.25),  "ar": Vector2(1.3, -0.35), "hx": -0.12, "hz": 0.22,  "lean": 0.08},
	"carry":   {"al": Vector2(0.75, -0.55),"ar": Vector2(0.45, -0.1), "hx": 0.0,   "hz": 0.0,   "lean": 0.0},
	"aim":     {"al": Vector2(1.5, -0.45), "ar": Vector2(1.35, -0.05),"hx": -0.08, "hz": 0.18,  "lean": 0.06},
	"aim_up":  {"al": Vector2(2.2, -0.45), "ar": Vector2(2.05, -0.05),"hx": 0.35,  "hz": 0.15,  "lean": -0.05},
	"triumph": {"al": Vector2(2.9, 0.25),  "ar": Vector2(2.7, -0.25), "hx": 0.2,   "hz": 0.0,   "lean": -0.06},
	"bow":     {"al": Vector2(0.15, 0.1),  "ar": Vector2(0.15, -0.1), "hx": -0.45, "hz": 0.0,   "lean": 0.12},
	"sit":     {"al": Vector2(0.9, 0.15),  "ar": Vector2(0.9, -0.15), "hx": 0.0,   "hz": 0.0,   "lean": 0.0},
	"drink":   {"al": Vector2(0.05, 0.0),  "ar": Vector2(2.1, -0.55), "hx": 0.2,   "hz": 0.0,   "lean": -0.03},
}

var face: int = 0
var costume: String = "staff"
var tint: Color = Color.WHITE
var skin: Color = Color("e8c4a0")
var height_scale: float = 1.0
var seated: bool = false

var torso: Node3D
var head_pivot: Node3D
var arm_l: Node3D
var arm_r: Node3D
var leg_l: Node3D
var leg_r: Node3D

var gun: Node3D
var hat: Node3D
var hat_hole: Node3D

var pose: String = "stand"
var talking: bool = false
## Set by the director while the figure is on its way somewhere: legs and arms
## swing, the body bobs. Off, the legs go back to standing (or seated).
var walking: bool = false
var _stride: float = 0.0
var _phase: float = 0.0
var _seed: float = 0.0
var _from: Dictionary = POSES["stand"]
var _blend: float = 1.0
var _parts: Array[MeshInstance3D] = []


static func create(p_face: int, p_costume: String, p_tint: Color,
		p_skin: Color, p_height: float = 1.0, p_seed: float = 0.0) -> Figure:
	var f := Figure.new()
	f.face = p_face
	f.costume = p_costume
	f.tint = p_tint
	f.skin = p_skin
	f.height_scale = p_height
	f._seed = p_seed
	f._build()
	return f


func _build() -> void:
	scale = Vector3.ONE * height_scale
	var slab := Ink.mat(tint.lerp(Ink.PAPER, 0.3))

	torso = Node3D.new()
	torso.name = "Torso"
	torso.position = Vector3(0, HIP_Y, 0)
	add_child(torso)
	_paper_part(torso, Vector2(TORSO_W, TORSO_H), Vector3(0, TORSO_H * 0.5, 0), slab,
		"torso_f", "torso_b", "Torso")

	head_pivot = Node3D.new()
	head_pivot.name = "Head"
	head_pivot.position = Vector3(0, TORSO_H + 0.06, 0)
	torso.add_child(head_pivot)
	_box(head_pivot, Vector3(HEAD.x * 0.78, HEAD.y * 0.88, HEAD.z * 0.46),
		Vector3(0, HEAD.y * 0.5, 0), Ink.mat(skin), "HeadBack")
	var front := _card(head_pivot, Vector2(CARD, CARD),
		Vector3(0, HEAD.y * 0.46, -HEAD.z * 0.23 - 0.014), Ink.face_mat(face), "FaceCard")
	front.rotation.y = PI
	_card(head_pivot, Vector2(CARD, CARD),
		Vector3(0, HEAD.y * 0.46, HEAD.z * 0.23 + 0.014), Ink.back_mat(face), "BackCard")

	arm_l = _limb(torso, Vector3(-(TORSO_W * 0.5 + ARM_W * 0.5), TORSO_H - SHOULDER_DROP, 0),
		Vector2(ARM_W, ARM_LEN), slab, "arm", "ArmL")
	arm_r = _limb(torso, Vector3(TORSO_W * 0.5 + ARM_W * 0.5, TORSO_H - SHOULDER_DROP, 0),
		Vector2(ARM_W, ARM_LEN), slab, "arm", "ArmR")
	leg_l = _limb(self, Vector3(-0.13, HIP_Y, 0), Vector2(LEG_W, LEG_LEN), slab, "leg", "LegL")
	leg_r = _limb(self, Vector3(0.13, HIP_Y, 0), Vector2(LEG_W, LEG_LEN), slab, "leg", "LegR")


## Change clothes in place — the whole of the transformation is a wardrobe.
func set_costume(p_costume: String, p_tint: Color) -> void:
	if p_costume == costume and p_tint == tint:
		return
	costume = p_costume
	tint = p_tint
	var slab := Ink.mat(tint.lerp(Ink.PAPER, 0.3))
	for mi in _parts:
		var role: String = mi.get_meta("role", "")
		match role:
			"slab": mi.material_override = slab
			"":
				pass
			_:
				mi.material_override = Ink.body_mat(costume, role)


func set_seated(v: bool) -> void:
	seated = v
	# Seated: legs forward. The page drops the figure onto the chair seat.
	leg_l.rotation.x = 1.45 if v else 0.0
	leg_r.rotation.x = 1.45 if v else 0.0


# --- Props ---------------------------------------------------------------------

## A twelve-bore, carried in the right hand, barrel along the arm.
func give_gun(on: bool) -> void:
	if on and gun == null:
		gun = Node3D.new()
		gun.name = "Gun"
		arm_r.add_child(gun)
		gun.position = Vector3(0, -ARM_LEN + 0.02, -0.05)
		var stock := _box(gun, Vector3(0.07, 0.34, 0.1), Vector3(0, 0.2, 0.02), Ink.mat(Ink.WALNUT, 0.8), "Stock")
		stock.rotation.x = 0.12
		_box(gun, Vector3(0.05, 0.12, 0.07), Vector3(0, -0.02, 0), Ink.mat(Ink.GUNMETAL, 0.8), "Action")
		_box(gun, Vector3(0.035, 0.72, 0.035), Vector3(-0.012, -0.44, 0), Ink.mat(Ink.GUNMETAL, 0.8), "BarrelL")
		_box(gun, Vector3(0.035, 0.72, 0.035), Vector3(0.018, -0.44, 0), Ink.mat(Ink.GUNMETAL, 0.8), "BarrelR")
	elif not on and gun != null:
		gun.queue_free()
		gun = null


## A deerstalker. [param holed] puts daylight through the crown.
func give_hat(on: bool, holed: bool = false) -> void:
	if on and hat == null:
		hat = Node3D.new()
		hat.name = "Hat"
		head_pivot.add_child(hat)
		# Sits back on the crown, behind the face card, so the drawing stays visible.
		hat.position = Vector3(0, HEAD.y * 0.92, 0.04)
		var tweed := Ink.mat(Color("8a7a5c"), 0.7)
		_box(hat, Vector3(0.34, 0.12, 0.3), Vector3(0, 0.05, 0), tweed, "Crown")
		_box(hat, Vector3(0.28, 0.025, 0.46), Vector3(0, -0.005, 0), tweed, "Peaks")
		_box(hat, Vector3(0.05, 0.04, 0.05), Vector3(0, 0.13, 0), tweed, "Button")
	if hat:
		hat.visible = on
		if holed and hat_hole == null:
			hat_hole = Node3D.new()
			hat.add_child(hat_hole)
			var mi := _card(hat_hole, Vector2(0.09, 0.09), Vector3(0.05, 0.06, -0.155),
				Ink.glow(Ink.INK), "Hole")
			mi.rotation.y = PI
			var mi2 := _card(hat_hole, Vector2(0.07, 0.07), Vector3(-0.06, 0.07, 0.155),
				Ink.glow(Ink.INK), "Hole2")
			mi2.rotation.y = 0.0
		if hat_hole:
			hat_hole.visible = holed


# --- Pose ------------------------------------------------------------------------

func set_pose(p: String, instant: bool = false) -> void:
	if not POSES.has(p):
		p = "stand"
	_from = _current_pose()
	pose = p
	_blend = 1.0 if instant else 0.0
	if instant:
		_apply(POSES[p], 0.0)


func _current_pose() -> Dictionary:
	return {
		"al": Vector2(arm_l.rotation.x, arm_l.rotation.z),
		"ar": Vector2(arm_r.rotation.x, arm_r.rotation.z),
		"hx": head_pivot.rotation.x, "hz": head_pivot.rotation.z,
		"lean": torso.rotation.x,
	}


func _process(delta: float) -> void:
	_phase += delta
	# Quantise time to the flipbook cadence: one floor() call is most of the look.
	var t: float = floor((_phase + _seed) * FLIPBOOK_FPS) / FLIPBOOK_FPS
	if _blend < 1.0:
		_blend = minf(1.0, _blend + delta * 3.2)
	var k: float = floor(_blend * 6.0) / 6.0   # six drawn in-betweens, no more
	var target: Dictionary = POSES[pose]
	var cur := {}
	for key in target:
		cur[key] = lerp(_from[key], target[key], smoothstep(0.0, 1.0, k))
	var breath: float = sin(t * TAU * 0.35 + _seed * 5.0)
	var gest: float = sin(t * TAU * 0.9 + _seed * 3.0) * (0.28 if talking else 0.0)
	if walking:
		_stride += delta
		# Two steps a second, quantised to the flipbook: each leg is drawn in
		# six positions, and the body rises on the passing leg.
		var sw: float = sin(floor(_stride * FLIPBOOK_FPS) / FLIPBOOK_FPS * TAU * 1.0)
		leg_l.rotation.x = sw * 0.55
		leg_r.rotation.x = -sw * 0.55
		cur = cur.duplicate()
		cur["al"] = Vector2(cur["al"].x - sw * 0.35, cur["al"].y)
		cur["ar"] = Vector2(cur["ar"].x + sw * 0.35, cur["ar"].y)
		_apply(cur, breath * 0.01 + absf(sw) * 0.025, 0.0)
		return
	elif not seated and (absf(leg_l.rotation.x) > 0.001 or absf(leg_r.rotation.x) > 0.001):
		leg_l.rotation.x = 0.0
		leg_r.rotation.x = 0.0
	_apply(cur, breath * 0.02, gest)


func _apply(p: Dictionary, breath: float, gest: float = 0.0) -> void:
	var al: Vector2 = p["al"]
	var ar: Vector2 = p["ar"]
	arm_l.rotation.x = al.x + gest * 0.4
	arm_l.rotation.z = -al.y
	arm_r.rotation.x = ar.x + gest
	arm_r.rotation.z = -ar.y
	head_pivot.rotation.x = p["hx"] + breath * 2.0
	head_pivot.rotation.z = p["hz"]
	torso.rotation.x = -p["lean"]
	torso.position.y = HIP_Y + breath


# --- Construction ------------------------------------------------------------------

func _paper_part(parent: Node3D, size: Vector2, offset: Vector3, slab_mat: Material,
		front_part: String, back_part: String, n: String) -> void:
	var b := _box(parent, Vector3(size.x * 0.92, size.y * 0.98, SLAB), offset, slab_mat, n + "Slab")
	b.set_meta("role", "slab")
	var f := _card(parent, size, offset + Vector3(0, 0, -SLAB * 0.5 - 0.01),
		Ink.body_mat(costume, front_part), n + "Front")
	f.rotation.y = PI
	f.set_meta("role", front_part)
	var k := _card(parent, size, offset + Vector3(0, 0, SLAB * 0.5 + 0.01),
		Ink.body_mat(costume, back_part), n + "Back")
	k.set_meta("role", back_part)
	_parts.append_array([b, f, k])


func _card(parent: Node3D, size: Vector2, offset: Vector3, m: Material, n: String) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = n
	var quad := QuadMesh.new()
	quad.size = size
	mi.mesh = quad
	mi.position = offset
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


func _box(parent: Node3D, size: Vector3, offset: Vector3, m: Material, n: String) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = n
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.position = offset
	mi.material_override = m
	parent.add_child(mi)
	return mi


func _limb(parent: Node3D, at: Vector3, size: Vector2, slab_mat: Material, part: String, n: String) -> Node3D:
	var pivot := Node3D.new()
	pivot.name = n
	pivot.position = at
	parent.add_child(pivot)
	_paper_part(pivot, size, Vector3(0, -size.y * 0.5, 0), slab_mat, part, part, n)
	return pivot


## World position just above the head — where a speech balloon's tail points.
func mouth_point() -> Vector3:
	return head_pivot.global_transform * Vector3(0, HEAD.y * 0.55, 0)


## The drawn face card's corners in world space, for keeping lettering off it.
func face_corners() -> Array[Vector3]:
	var c: Array[Vector3] = []
	var mid := Vector3(0, HEAD.y * 0.46, 0)
	for dx in [-0.5, 0.5]:
		for dy in [-0.5, 0.5]:
			c.append(head_pivot.global_transform * (mid + Vector3(dx * CARD, dy * CARD, 0)))
	return c


func head_top() -> Vector3:
	return head_pivot.global_transform * Vector3(0, HEAD.y * 1.25, 0)
