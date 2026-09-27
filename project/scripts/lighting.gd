## Lighting — one preset per mood, eased between on every page turn.
##
## The story is told in the shadows as much as the words: every toon surface's
## shadow tint starts a cool printer's purple and runs to oxblood as Bludleigh
## gets into the lovers, then cools again on the 4.15 to Paddington.
class_name Lighting
extends Node3D

const PRESETS := {
	"parlour": {
		"bg": Color("2a221c"), "amb": Color("cbbca6"), "amb_e": 0.5,
		"sun": Color("fbe6c4"), "sun_e": 0.8, "sun_rot": Vector3(-38, 30, 0),
		"shadow": Color(0.42, 0.36, 0.5),
		"omni": [[Vector3(-4.6, 0.8, 0.3), Color("ff9a4a"), 1.2, 5.0], [Vector3(0.6, 2.9, 0.5), Color("ffe6c0"), 0.5, 6.0]],
	},
	"golden": {
		"bg": Color("e9dcc0"), "amb": Color("e8dcc0"), "amb_e": 0.6,
		"sun": Color("ffe2b0"), "sun_e": 1.15, "sun_rot": Vector3(-32, -35, 0),
		"shadow": Color(0.40, 0.385, 0.56),
		"windows": Color("4a4f5a"),
	},
	"hall": {
		"bg": Color("1f1813"), "amb": Color("c89a6a"), "amb_e": 0.45,
		"sun": Color("ffc98a"), "sun_e": 0.55, "sun_rot": Vector3(-50, 20, 0),
		"shadow": Color(0.42, 0.33, 0.44),
		"omni": [[Vector3(0, 1.0, 4.4), Color("ff9a4a"), 2.2, 9.0], [Vector3(-4, 4.5, 0), Color("ffd49a"), 0.8, 9.0]],
	},
	"candle": {
		"bg": Color("160f0c"), "amb": Color("b07a4a"), "amb_e": 0.35,
		"sun": Color("ffcf8a"), "sun_e": 0.35, "sun_rot": Vector3(-60, 10, 0),
		"shadow": Color(0.46, 0.30, 0.38),
		"omni": [[Vector3(-1.3, 1.9, 0.4), Color("ffd49a"), 0.9, 5.0], [Vector3(1.3, 1.9, 0.4), Color("ffd49a"), 0.9, 5.0]],
	},
	"candle_red": {
		"bg": Color("1a0c0a"), "amb": Color("b05a3a"), "amb_e": 0.4,
		"sun": Color("ffb070"), "sun_e": 0.35, "sun_rot": Vector3(-60, 10, 0),
		"shadow": Color(0.52, 0.22, 0.26),
		"omni": [[Vector3(-1.3, 1.9, 0.4), Color("ff8a5a"), 1.1, 5.0], [Vector3(1.3, 1.9, 0.4), Color("ff8a5a"), 1.1, 5.0]],
	},
	"morning": {
		"bg": Color("d6d8d0"), "amb": Color("e8ece6"), "amb_e": 0.75,
		"sun": Color("fbfbf4"), "sun_e": 1.25, "sun_rot": Vector3(-28, -80, 0),
		"shadow": Color(0.48, 0.30, 0.34),
	},
	"moor": {
		"bg": Color("f0cf8e"), "amb": Color("f4d7a0"), "amb_e": 0.6,
		"sun": Color("ffcf88"), "sun_e": 1.45, "sun_rot": Vector3(-14, -70, 0),
		"shadow": Color(0.56, 0.20, 0.22),
		"fog": Color("f0cf8e"), "fog_d": 0.006,
	},
	"dusk": {
		"bg": Color("6f5a78"), "amb": Color("8e86a8"), "amb_e": 0.5,
		"sun": Color("ff9a60"), "sun_e": 0.55, "sun_rot": Vector3(-8, 70, 0),
		"shadow": Color(0.30, 0.28, 0.48),
		"windows": Color("ffcf7a"),
		"fog": Color("6f5a78"), "fog_d": 0.01,
	},
}

var env: Environment
var sun: DirectionalLight3D
var _omnis: Array[OmniLight3D] = []
var _tween: Tween
var current: String = ""


func _ready() -> void:
	var we := WorldEnvironment.new()
	env = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	we.environment = env
	add_child(we)
	sun = DirectionalLight3D.new()
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 40.0
	sun.shadow_blur = 1.5
	add_child(sun)


## Ease to [param name]. [param origin] is where the current set lives, for the
## set-local point lights. [param windows] are the house's glass panes.
func apply(preset: String, origin: Vector3, windows: Array = [], instant: bool = false) -> void:
	var p: Dictionary = PRESETS.get(preset, PRESETS["golden"])
	current = preset
	var dur := 0.0 if instant else 0.6
	if _tween and _tween.is_valid():
		_tween.kill()
	var r: Vector3 = p["sun_rot"]
	var rot := Vector3(deg_to_rad(r.x), deg_to_rad(r.y), deg_to_rad(r.z))
	if dur == 0.0:
		env.background_color = p["bg"]
		env.ambient_light_color = p["amb"]
		env.ambient_light_energy = p["amb_e"]
		sun.light_color = p["sun"]
		sun.light_energy = p["sun_e"]
		sun.rotation = rot
		Ink.set_shadow_tint(p["shadow"])
	else:
		_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE)
		_tween.tween_property(env, "background_color", p["bg"], dur)
		_tween.tween_property(env, "ambient_light_color", p["amb"], dur)
		_tween.tween_property(env, "ambient_light_energy", p["amb_e"], dur)
		_tween.tween_property(sun, "light_color", p["sun"], dur)
		_tween.tween_property(sun, "light_energy", p["sun_e"], dur)
		_tween.tween_property(sun, "rotation", rot, dur)
		var from := Ink.shadow_tint()
		_tween.tween_method(func(t: float) -> void: Ink.set_shadow_tint(from.lerp(p["shadow"], t)), 0.0, 1.0, dur)
	env.fog_enabled = p.has("fog")
	if p.has("fog"):
		env.fog_light_color = p["fog"]
		env.fog_density = p["fog_d"]
		env.fog_sky_affect = 0.0
	for o in _omnis:
		o.queue_free()
	_omnis.clear()
	for o in p.get("omni", []):
		var l := OmniLight3D.new()
		l.position = origin + o[0]
		l.light_color = o[1]
		l.light_energy = o[2]
		l.omni_range = o[3]
		l.omni_attenuation = 1.2
		add_child(l)
		_omnis.append(l)
	var wc: Color = p.get("windows", Color("4a4f5a"))
	for w in windows:
		(w as MeshInstance3D).material_override = Ink.glow(wc)
