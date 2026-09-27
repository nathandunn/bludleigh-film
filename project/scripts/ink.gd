## Ink — material factory and palette, carried over from flipbook-field.
##
## Every solid thing is a duplicate of materials/toon_base.tres with its own
## base colour, cached per colour. Heads and costumes are Nathan's pen drawings
## on unlit paper cards, so ink stays ink under every light in the scene.
class_name Ink
extends RefCounted

const TOON_BASE := "res://materials/toon_base.tres"
## Ink weight at outline = 1.0. Angular, not world-space — see outline.gdshader.
const OUTLINE_BASE := 0.0045

static var _cache: Dictionary = {}
static var _shadow := Color(0.40, 0.385, 0.56)


## A toon material tinted [param color]. [param outline] scales the ink weight;
## 0 drops the outline (ground planes, whose inverted hull would be a huge box).
static func mat(color: Color, outline: float = 1.0, bands: int = 3) -> ShaderMaterial:
	var key := "%s|%.3f|%d" % [color.to_html(), outline, bands]
	if _cache.has(key):
		return _cache[key]
	var base: ShaderMaterial = load(TOON_BASE)
	var m: ShaderMaterial = base.duplicate(true)
	m.set_shader_parameter("base_color", color)
	m.set_shader_parameter("band_count", bands)
	m.set_shader_parameter("shadow_tint", _shadow)
	if outline <= 0.0:
		m.next_pass = null
	else:
		var op := m.next_pass as ShaderMaterial
		if op:
			op.set_shader_parameter("thickness", OUTLINE_BASE * outline)
	_cache[key] = m
	return m


## The shadow colour of every toon surface at once. The story uses it: shadows
## start a cool printer's purple and go oxblood as Bludleigh gets into them.
static func set_shadow_tint(c: Color) -> void:
	_shadow = c
	for m in _cache.values():
		(m as ShaderMaterial).set_shader_parameter("shadow_tint", c)


static func shadow_tint() -> Color:
	return _shadow


# --- Paper: faces and costumes -------------------------------------------------

const FACE_COUNT := 20

static var _paper_cache: Dictionary = {}


static func face_mat(index: int) -> StandardMaterial3D:
	return _paper("res://faces/face_%02d.png" % posmod(index, FACE_COUNT))


static func back_mat(index: int) -> StandardMaterial3D:
	return _paper("res://faces/back_%02d.png" % posmod(index, FACE_COUNT))


## [param costume] is a file stem in res://bodies/ (ceo, legal, engineer...);
## [param part] is torso_f, torso_b, arm or leg.
static func body_mat(costume: String, part: String) -> StandardMaterial3D:
	return _paper("res://bodies/%s_%s.png" % [costume, part])


## Unlit, scissored, two-sided: a drawing on paper.
static func _paper(path: String) -> StandardMaterial3D:
	if _paper_cache.has(path):
		return _paper_cache[path]
	var m := StandardMaterial3D.new()
	m.albedo_texture = load(path)
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	# Scissor, not blend: it sorts correctly on the web's Compatibility renderer,
	# where a depth pre-pass falls back to per-object sorting.
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	m.alpha_scissor_threshold = 0.5
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
	_paper_cache[path] = m
	return m


static var _glow_cache: Dictionary = {}


## A flat unlit colour — windows, lamp glass, things that are light rather than
## lit. Cached by colour: re-applying a lighting preset re-lights the same
## windows every page turn, and building fresh materials each time is needless
## churn — cheap on a desktop GPU, but a real cost on the tighter memory
## budget a web build gets on a phone or an older browser.
static func glow(color: Color) -> StandardMaterial3D:
	var key := color.to_html()
	if _glow_cache.has(key):
		return _glow_cache[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_glow_cache[key] = m
	return m


# --- Palette -------------------------------------------------------------------
# Warm paper, desaturated fills, nothing at full saturation: printed colour never
# is, and it keeps the ink the darkest thing on the page.

const PAPER := Color("efe7d6")
const INK := Color("12101a")

const GRASS := Color("7d9560")
const GRASS_DARK := Color("62784b")
const HEATHER := Color("8c6a86")
const HEATHER_DARK := Color("6d5268")
const BRACKEN := Color("a57a45")
const GRAVEL := Color("c9b99b")
const STONE := Color("b8ae9c")
const STONE_DARK := Color("8f8676")
const SLATE := Color("5d6068")
const OAK := Color("7a5a3c")
const OAK_DARK := Color("4f3a28")
const PANEL := Color("6b4f36")
const PLASTER := Color("d8ccb2")
const CLOTH := Color("e9e2cf")
const CLARET := Color("7a2e2e")
const BRASS := Color("c9a14a")
const GUNMETAL := Color("3b3d44")
const WALNUT := Color("5e3b22")
const ANTLER := Color("d9c8a3")
const HIDE := Color("8a6444")
const BOTTLE := Color("3f5b3f")
const LEAF := Color("6d8f52")
const LEAF_DARK := Color("54703f")
const BARK := Color("6e5745")
const MOTOR := Color("2f4a5c")

const SKINS: Array[Color] = [
	Color("e8c4a0"), Color("d4a276"), Color("f2d5b8"), Color("c99670"),
]
