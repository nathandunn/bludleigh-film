## Story — the cast and every page of the book, as data.
##
## A loose adaptation of P. G. Wodehouse's "Unpleasantness at Bludleigh Court"
## (Mr Mulliner Speaking, 1929): the premise and the people, with the dialogue
## written fresh. Two gentle poets visit a house that has been killing things
## for four hundred years, and the house wins.
##
## Every page is self-contained — where everyone stands, what they wear and
## hold, the light, the camera — so paging backwards is as cheap as forwards.
##
## Page keys:
##   set, light      Sets.ORDER / Lighting.PRESETS
##   cam             [camera position, look-at point], set-local
##   fov, drift      lens, and how far the camera creeps (fraction of the way
##                   to its target) while the page is open
##   frame           "full" or "wide" (letterboxed)
##   cast            id -> {at, yaw (deg; 0 faces the camera side), pose,
##                   gun, hat, holed, costume, tint, seated}
##   caption         the narrator's box, top left; caption2 bottom right
##   say             [[who, text, kind?]] in reading order; kind "shout"
##   sfx             [[text, Vector2 screen fraction, degrees]]
##   title           [title, subtitle]
class_name Story
extends RefCounted

## face = index into res://faces (0 and 1 are the two drawings the player and
## nemesis wore in flipbook-field); costume = a file stem in res://bodies.
const CAST := {
	"mulliner":  {"face": 16,  "costume": "legal",     "tint": Color("7d7a8c"), "skin": 0, "h": 0.97},
	"stout":     {"face": 6,   "costume": "sales",     "tint": Color("8a5a3c"), "skin": 3, "h": 1.03},
	"bass":      {"face": 4,  "costume": "staff",     "tint": Color("6a7a8a"), "skin": 1, "h": 0.99},
	"charlotte": {"face": 0,  "costume": "marketing", "tint": Color("b59ac4"), "skin": 2, "h": 0.95},
	"aubrey":    {"face": 1,  "costume": "legal",     "tint": Color("9fb59a"), "skin": 0, "h": 1.0},
	"sir_alex":  {"face": 2,  "costume": "ceo",       "tint": Color("8a7454"), "skin": 3, "h": 1.08},
	"aunt":      {"face": 3,  "costume": "hr",        "tint": Color("7a5a6a"), "skin": 2, "h": 0.97},
	"uncle":     {"face": 18, "costume": "engineer",  "tint": Color("6f7a55"), "skin": 0, "h": 1.0},
	"wilfred":   {"face": 19, "costume": "sales",     "tint": Color("8e8a5a"), "skin": 1, "h": 1.03},
}

const NAMES := {
	"mulliner": "Mr Mulliner", "stout": "A Pint of Stout", "bass": "A Small Bass",
	"charlotte": "Charlotte", "aubrey": "Aubrey", "sir_alex": "Sir Alexander",
	"aunt": "Aunt Emily", "uncle": "Uncle Joe", "wilfred": "Cousin Wilfred",
}

## Shooting tweeds: the engineer's plaid, re-dyed.
const TWEED_C := Color("7b8a5a")
const TWEED_A := Color("8a7a52")


static func pages() -> Array:
	var P: Array = []

	# --- The Angler's Rest --------------------------------------------------------
	var bar := {
		"mulliner": {"at": Vector3(0.75, 0, 2.05), "yaw": 8, "pose": "drink"},
		"stout":    {"at": Vector3(-0.55, 0, 1.95), "yaw": -28, "pose": "talk"},
		"bass":     {"at": Vector3(2.05, 0, 2.0), "yaw": 20, "pose": "stand"},
	}
	P.append({
		"set": "parlour", "light": "parlour",
		"cam": [Vector3(0.5, 1.75, -3.4), Vector3(0.6, 1.55, 2.2)],
		"cast": bar,
		"title": ["BLUDLEIGH", "A Mulliner story, after P. G. Wodehouse"],
		"caption": "The bar-parlour of the Angler's Rest. A Pint of Stout had been telling us about a stag.",
		"say": [["stout", "Right between the eyes! At four hundred yards!", "shout"]],
	})
	P.append({
		"set": "parlour", "light": "parlour",
		"cam": [Vector3(0.2, 1.65, -1.5), Vector3(0.55, 1.4, 2.0)], "fov": 42,
		"cast": _with(bar, {"mulliner": {"pose": "talk"}, "stout": {"pose": "stand"}}),
		"say": [
			["mulliner", "Blood sports have their place, I suppose. They always put me in mind of my niece Charlotte, and what happened to her at Bludleigh Court."],
			["stout", "Took up shooting, did she?"],
		],
	})
	P.append({
		"set": "parlour", "light": "parlour",
		"cam": [Vector3(0.7, 1.7, -1.0), Vector3(0.75, 1.45, 2.05)], "fov": 36, "drift": 0.06,
		"cast": _with(bar, {"mulliner": {"pose": "stand", "yaw": 0}}),
		"say": [["mulliner", "Worse. She enjoyed it."]],
	})

	# --- Arrival ---------------------------------------------------------------------
	var arrive := {
		"charlotte": {"at": Vector3(0.35, 0, 1.6), "yaw": 160, "pose": "clasp"},
		"aubrey":    {"at": Vector3(-0.55, 0, 1.3), "yaw": 170, "pose": "stand"},
	}
	P.append({
		"set": "exterior", "light": "golden", "frame": "wide",
		"cam": [Vector3(6.5, 2.6, -11.5), Vector3(0, 3.2, 6)], "fov": 44,
		"cast": arrive,
		"caption": "Charlotte wrote vers libre of the gentlest kind. So did her fiancé, Aubrey Bassinger, though he used fewer capital letters.",
		"caption2": "Bludleigh Court was Aubrey's family seat. He had not been home in years.",
	})
	P.append({
		"set": "exterior", "light": "golden",
		"cam": [Vector3(1.4, 1.6, 4.6), Vector3(-0.1, 1.35, 1.3)], "fov": 42,
		"cast": _with(arrive, {"charlotte": {"yaw": 205, "pose": "point"}, "aubrey": {"yaw": 215}}),
		"say": [
			["charlotte", "Aubrey, darling, why is the door-knocker a stag?"],
			["aubrey", "Father shot it, I expect. Try not to catch its eye."],
		],
	})
	var greet := _with(arrive, {
		"charlotte": {"yaw": 175, "pose": "shock"},
		"aubrey": {"yaw": 190},
	})
	greet["sir_alex"] = {"at": Vector3(0.1, 0.8, 6.55), "yaw": 0, "pose": "point", "gun": true, "hat": true}
	P.append({
		"set": "exterior", "light": "golden",
		"cam": [Vector3(-3.4, 1.55, 0.2), Vector3(0.1, 2.0, 4.6)], "fov": 44,
		"cast": greet,
		"say": [
			["sir_alex", "Aubrey! And this is the gel! Capital! D'you hunt, m'dear?", "shout"],
			["charlotte", "I have never so much as swatted a wasp, Sir Alexander."],
		],
	})
	P.append({
		"set": "exterior", "light": "golden",
		"cam": [Vector3(0.8, 2.0, 2.6), Vector3(0.1, 2.15, 6.55)], "fov": 38, "drift": 0.06,
		"cast": _with(greet, {"sir_alex": {"pose": "carry"}}),
		"say": [["sir_alex", "Hm. Early days."]],
		"caption2": "He said it the way a doctor says, \"We'll see.\"",
	})

	# --- The great hall ------------------------------------------------------------------
	var hall := {
		"charlotte": {"at": Vector3(0.3, 0, 0.4), "yaw": 175, "pose": "cling"},
		"aubrey":    {"at": Vector3(-0.35, 0, 0.3), "yaw": 180, "pose": "stand"},
	}
	P.append({
		"set": "hall", "light": "hall", "frame": "wide",
		"cam": [Vector3(0.0, 1.3, -5.4), Vector3(0, 3.1, 5.0)], "fov": 52,
		"cast": hall,
		"caption": "The great hall of Bludleigh had not been decorated so much as stocked.",
	})
	P.append({
		"set": "hall", "light": "hall",
		"cam": [Vector3(0.9, 1.6, -2.6), Vector3(0.0, 1.45, 0.4)], "fov": 42,
		"cast": _with(hall, {"charlotte": {"yaw": 20}, "aubrey": {"yaw": -10, "pose": "clasp"}}),
		"say": [
			["charlotte", "They're all looking at me."],
			["aubrey", "It's only the glass eyes, dearest. One week, and then back to Bloomsbury and civilised people."],
		],
	})
	P.append({
		"set": "hall", "light": "hall",
		"cam": [Vector3(-1.9, 1.5, -1.3), Vector3(1.6, 1.9, 3.2)], "fov": 44, "drift": 0.05,
		"cast": _with(hall, {"aubrey": {"at": Vector3(1.5, 0, 2.3), "yaw": 215, "pose": "clasp"}, "charlotte": {"at": Vector3(-0.4, 0, 1.0), "yaw": 200, "pose": "stand"}}),
		"caption": "Aubrey said this very firmly. It is worth remembering that he had been born in this house.",
	})

	# --- Dinner ----------------------------------------------------------------------------
	var dinner := {
		"sir_alex":  {"at": Vector3(-3.35, -0.22, 0.4), "yaw": -90, "pose": "sit", "seated": true},
		"aunt":      {"at": Vector3(-1.8, -0.22, 1.75), "yaw": 0, "pose": "sit", "seated": true},
		"uncle":     {"at": Vector3(-0.6, -0.22, 1.75), "yaw": 0, "pose": "sit", "seated": true},
		"wilfred":   {"at": Vector3(0.6, -0.22, 1.75), "yaw": 0, "pose": "sit", "seated": true},
		"charlotte": {"at": Vector3(1.8, -0.22, 1.75), "yaw": 0, "pose": "sit", "seated": true},
		"aubrey":    {"at": Vector3(3.35, -0.22, 0.4), "yaw": 90, "pose": "sit", "seated": true},
	}
	var dinner_cam := [Vector3(0.0, 2.1, -4.6), Vector3(0.0, 1.15, 1.2)]
	P.append({
		"set": "dining", "light": "candle", "frame": "wide",
		"cam": dinner_cam, "fov": 54,
		"cast": _with(dinner, {"uncle": {"pose": "talk"}, "aunt": {"pose": "point"}}),
		"caption": "At dinner the Bassingers discussed what they had killed that day, what they would kill tomorrow and, over the savoury, what they would kill if the law allowed.",
		"say": [
			["uncle", "Winged a heron on Tuesday."],
			["aunt", "Rabbits in the rose-beds, Alexander. It is war."],
		],
	})
	P.append({
		"set": "dining", "light": "candle",
		"cam": [Vector3(-1.2, 1.7, -2.4), Vector3(-0.8, 1.2, 1.4)], "fov": 46,
		"cast": _with(dinner, {"wilfred": {"pose": "relish"}, "sir_alex": {"pose": "point"}}),
		"say": [
			["wilfred", "Sat up a tree six hours for a badger. Worth every minute."],
			["sir_alex", "Miss Mulliner writes poetry, I'm told. Give us a verse, m'dear!"],
		],
	})
	var recital := _with(dinner, {"charlotte": {"at": Vector3(1.8, 0, 1.95), "pose": "recite", "seated": false}})
	P.append({
		"set": "dining", "light": "candle",
		"cam": [Vector3(1.9, 1.6, -1.2), Vector3(1.8, 1.55, 1.95)], "fov": 42,
		"cast": recital,
		"caption": "\"Dawn in the Meadow.\"",
		"say": [["charlotte", "Pale morning creeps across the dewy grass, and there among the clover sits a young rabbit, plump..."]],
	})
	P.append({
		"set": "dining", "light": "candle_red",
		"cam": [Vector3(1.7, 1.75, -0.6), Vector3(1.8, 1.6, 1.95)], "fov": 38, "drift": 0.1,
		"cast": _with(recital, {"charlotte": {"pose": "relish"}, "aubrey": {"pose": "shock"}}),
		"say": [["charlotte", "...plump, and sitting well within range of a twelve-bore with the left barrel choked."]],
		"sfx": [["clink!", Vector2(0.84, 0.72), -12]],
		"caption2": "That was not how the poem had been written.",
	})
	P.append({
		"set": "dining", "light": "candle_red", "frame": "wide",
		"cam": dinner_cam, "fov": 54,
		"cast": _with(recital, {"charlotte": {"pose": "clasp"}, "sir_alex": {"pose": "triumph"}, "uncle": {"pose": "triumph"}, "wilfred": {"pose": "point"}, "aubrey": {"pose": "shock"}}),
		"say": [
			["sir_alex", "BRAVO!", "shout"],
			["uncle", "Hear, hear!"],
		],
		"caption": "The family had never cared for a poem before.",
	})

	# --- The gun-room ------------------------------------------------------------------
	var guns := {
		"charlotte": {"at": Vector3(1.2, 0, -0.2), "yaw": -25, "pose": "carry", "gun": true},
		"aubrey":    {"at": Vector3(-0.9, 0, -0.5), "yaw": 30, "pose": "stand"},
	}
	var gun_cam := [Vector3(0.1, 1.6, -3.6), Vector3(0.3, 1.35, 1.2)]
	P.append({
		"set": "gunroom", "light": "morning",
		"cam": gun_cam, "fov": 44,
		"cast": guns,
		"caption": "Next morning Aubrey found his fiancée in the gun-room.",
		"say": [["charlotte", "Aubrey, which one is the choke barrel? Uncle Joe says the left is the killer."]],
	})
	P.append({
		"set": "gunroom", "light": "morning",
		"cam": [Vector3(0.1, 1.6, -3.4), Vector3(0.15, 1.4, 0.0)], "fov": 46,
		"cast": _with(guns, {"aubrey": {"pose": "shock"}, "charlotte": {"pose": "point", "yaw": -15}}),
		"say": [
			["aubrey", "Charlotte! You're a pacifist! You wrote an ode to a wasp!", "shout"],
			["charlotte", "It was a very short ode. Pass me those cartridges."],
		],
	})
	P.append({
		"set": "gunroom", "light": "morning",
		"cam": [Vector3(-0.4, 1.55, -3.0), Vector3(-0.2, 1.6, 0.0)], "fov": 42, "drift": 0.06,
		"cast": _with(guns, {"aubrey": {"pose": "aim_up", "gun": true, "yaw": -75}, "charlotte": {"pose": "clasp", "yaw": -20}}),
		"caption": "He found, to his horror, that he had passed them. He found also that he was holding a gun, and squinting down it with the air of a connoisseur.",
		"say": [["aubrey", "Hm. Nice balance."]],
	})

	# --- The moor ------------------------------------------------------------------------
	var moor := {
		"charlotte": {"at": Vector3(-0.55, 1.3, 1.0), "yaw": 180, "pose": "aim_up", "gun": true, "costume": "engineer", "tint": TWEED_C},
		"aubrey":    {"at": Vector3(0.7, 1.3, 0.85), "yaw": 175, "pose": "aim_up", "gun": true, "costume": "engineer", "tint": TWEED_A, "hat": true},
	}
	P.append({
		"set": "moor", "light": "moor", "frame": "wide",
		"cam": [Vector3(0.9, 1.9, -4.2), Vector3(1.5, 5.5, 20)], "fov": 50,
		"cast": moor,
		"caption": "By Thursday they were out on the moor at dawn, in tweeds.",
		"sfx": [["BANG!", Vector2(0.36, 0.3), -10], ["BANG!", Vector2(0.62, 0.22), 8]],
	})
	var moor_front := _with(moor, {"charlotte": {"yaw": -10, "pose": "triumph"}, "aubrey": {"yaw": 20, "pose": "carry"}})
	P.append({
		"set": "moor", "light": "moor",
		"cam": [Vector3(0.3, 2.7, -1.9), Vector3(0.1, 2.35, 1.0)], "fov": 44,
		"cast": moor_front,
		"say": [
			["charlotte", "Got him!", "shout"],
			["aubrey", "That was a cloud, darling."],
			["charlotte", "It had it coming."],
		],
	})
	P.append({
		"set": "moor", "light": "moor",
		"cam": [Vector3(1.4, 2.5, -2.3), Vector3(0.2, 2.25, 0.9)], "fov": 44,
		"cast": _with(moor_front, {"aubrey": {"pose": "carry", "yaw": -25}, "charlotte": {"pose": "clasp", "yaw": -15}}),
		"say": [
			["aubrey", "Do you know, I feel wonderful. I haven't written a line of verse in three days."],
			["charlotte", "Nor have I! Isn't it heaven? What shall we shoot next?"],
		],
	})
	var hat := _with(moor_front, {"charlotte": {"pose": "carry", "yaw": 30}, "aubrey": {"pose": "carry", "yaw": 50}})
	hat["sir_alex"] = {"at": Vector3(1.9, 1.25, -0.2), "yaw": -35, "pose": "triumph", "hat": true, "holed": true, "gun": false}
	P.append({
		"set": "moor", "light": "moor",
		"cam": [Vector3(0.9, 2.1, -4.4), Vector3(1.1, 2.45, 0.4)], "fov": 50,
		"cast": hat,
		"say": [
			["sir_alex", "Magnificent! Two rabbit, a brace of pigeon, a weathercock..."],
			["sir_alex", "...and my hat.", "shout"],
		],
		"caption2": "It was the hat that did it.",
	})

	# --- Dusk ---------------------------------------------------------------------------
	var dusk := {
		"charlotte": {"at": Vector3(0.45, 0, 3.4), "yaw": -10, "pose": "bow", "costume": "engineer", "tint": TWEED_C},
		"aubrey":    {"at": Vector3(-0.45, 0, 3.3), "yaw": 10, "pose": "bow", "costume": "engineer", "tint": TWEED_A},
	}
	P.append({
		"set": "exterior", "light": "dusk", "frame": "wide",
		"cam": [Vector3(2.0, 1.25, -1.6), Vector3(-0.2, 2.2, 6.0)], "fov": 46,
		"cast": dusk,
		"caption": "That evening, on the steps of Bludleigh, the lovers took stock.",
		"say": [
			["aubrey", "Charlotte, I shot at a sunset today. I got most of it, too."],
			["charlotte", "I winged your father. Only the hat. But still."],
		],
	})
	P.append({
		"set": "exterior", "light": "dusk",
		"cam": [Vector3(0.7, 1.65, 0.4), Vector3(0.0, 1.5, 3.4)], "fov": 42, "drift": 0.06,
		"cast": _with(dusk, {"charlotte": {"pose": "clasp", "yaw": -30}, "aubrey": {"pose": "stand", "yaw": 30}}),
		"say": [
			["charlotte", "Aubrey, it's the house. It gets into you."],
			["aubrey", "Then there is only one thing for it."],
		],
	})
	P.append({
		"set": "exterior", "light": "dusk", "frame": "wide",
		"cam": [Vector3(5.0, 2.0, -6.5), Vector3(-0.5, 1.4, 0.5)], "fov": 46,
		"cast": {
			"charlotte": {"at": Vector3(-0.35, 0, -0.1), "yaw": 150, "pose": "stand", "costume": "marketing"},
			"aubrey":    {"at": Vector3(0.5, 0, 0.0), "yaw": 10, "pose": "carry", "costume": "legal"},
		},
		"say": [
			["aubrey", "The 4.15 to Paddington."],
		],
		"caption2": "They left without packing. They left, it is recorded, without their guns, though Charlotte looked back twice.",
	})

	# --- The Angler's Rest again ------------------------------------------------------------
	P.append({
		"set": "parlour", "light": "parlour",
		"cam": [Vector3(0.2, 1.65, -1.5), Vector3(0.55, 1.4, 2.0)], "fov": 42,
		"cast": _with(bar, {"mulliner": {"pose": "talk"}, "stout": {"pose": "stand"}}),
		"say": [
			["mulliner", "They were married in the spring, and Charlotte went back to vers libre. Very good vers libre it is, too."],
			["stout", "No lasting effects, then?"],
		],
	})
	P.append({
		"set": "parlour", "light": "parlour",
		"cam": [Vector3(0.7, 1.7, -1.0), Vector3(0.75, 1.45, 2.05)], "fov": 36, "drift": 0.06,
		"cast": _with(bar, {"mulliner": {"pose": "drink", "yaw": 0}}),
		"say": [
			["mulliner", "None to speak of. Though she does insist on carving the Sunday joint herself..."],
			["mulliner", "...and she likes to stalk it first."],
		],
	})
	P.append({
		"set": "parlour", "light": "parlour",
		"cam": [Vector3(0.5, 1.75, -3.4), Vector3(0.6, 1.55, 2.2)], "fov": 42,
		"cast": _with(bar, {"stout": {"pose": "drink"}, "mulliner": {"pose": "stand"}}),
		"title": ["THE END", "Faces drawn by Nathan. Story after P. G. Wodehouse, \"Unpleasantness at Bludleigh Court.\""],
	})
	return P


## A copy of [param base] with per-character overrides merged in.
static func _with(base: Dictionary, over: Dictionary) -> Dictionary:
	var out := {}
	for k in base:
		out[k] = (base[k] as Dictionary).duplicate()
	for k in over:
		if not out.has(k):
			out[k] = {}
		for f in over[k]:
			out[k][f] = over[k][f]
	return out
