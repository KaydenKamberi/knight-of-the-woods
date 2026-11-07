extends RefCounted
## The 19 mini bosses, one per wave (PRD V-3, V-7, W-5).
##
## Each one is a bigger, tougher straw dummy with its own name, colour and
## headgear, and each is stronger than the last. Use it from another script with
## `const MiniBosses := preload("res://scripts/mini_bosses.gd")`, then call
## `MiniBosses.info(wave)`.

const NAMES := [
	"Old Stuffing", "Burlap Bart", "Patchwork Pete", "The Hay Baron", "Sir Sackcloth",
	"Thistle Tom", "The Scarecrown", "Bramble Jack", "Stitchface", "Mossy Marge",
	"Rattlestraw", "Grim Gunnysack", "Lady Lumpkin", "The Twine King", "Rotroot",
	"Ironpatch", "Ember Burlap", "Old Mossjaw", "The Last Scarecrow",
]
const COLORS := [
	Color(0.58, 0.44, 0.28), Color(0.46, 0.36, 0.52), Color(0.62, 0.32, 0.26), Color(0.7, 0.6, 0.3),
	Color(0.36, 0.42, 0.52), Color(0.42, 0.52, 0.3), Color(0.56, 0.5, 0.44), Color(0.46, 0.3, 0.2),
	Color(0.62, 0.56, 0.5), Color(0.3, 0.46, 0.32), Color(0.52, 0.46, 0.26), Color(0.3, 0.3, 0.33),
	Color(0.66, 0.42, 0.46), Color(0.52, 0.38, 0.2), Color(0.36, 0.28, 0.18), Color(0.46, 0.48, 0.52),
	Color(0.64, 0.3, 0.14), Color(0.28, 0.38, 0.26), Color(0.24, 0.21, 0.2),
]
const HEADGEAR := ["crown", "horns", "bucket", "antlers", "hood"]
const Config := preload("res://scripts/game_config.gd")


## Everything about one wave's mini boss: name, colour, headgear and stats.
## Wave 20's "mini boss" is the big boss, so its wanted posters show him.
static func info(wave: int) -> Dictionary:
	if wave >= Config.LAST_WAVE:
		return big_boss_info()
	var index := clampi(wave, 1, NAMES.size()) - 1
	return {
		"wave": wave,
		"name": NAMES[index],
		"color": COLORS[index],
		"headgear": HEADGEAR[index % HEADGEAR.size()],
		# V-7: 300 health in wave 1, +100 each wave, so 2,100 in wave 19.
		"health": Config.MINI_BOSS_BASE_HEALTH + Config.MINI_BOSS_HEALTH_PER_WAVE * (wave - 1),
		# Grows from about 1.45x to 1.9x a regular dummy.
		"size": 1.45 + 0.025 * (wave - 1),
		# E-4: dummies hit for 10; mini bosses for 15 plus 1 per wave.
		"damage": Config.MINI_BOSS_BASE_DAMAGE + Config.MINI_BOSS_DAMAGE_PER_WAVE * wave,
		"walk_speed": 2.0 + 0.03 * wave,
	}


## The big boss of wave 20 (V-4, V-8): a towering straw effigy with a crown.
static func big_boss_info() -> Dictionary:
	return {
		"wave": Config.LAST_WAVE,
		"name": Config.BIG_BOSS_NAME,
		"color": Config.BIG_BOSS_COLOR,
		"headgear": "crown",
		"health": Config.BIG_BOSS_HEALTH,
		"size": Config.BIG_BOSS_SIZE,
		"damage": Config.BIG_BOSS_DAMAGE,
		"walk_speed": Config.BIG_BOSS_SPEED,
	}


## Adds a mini boss's headgear to a head. `head_size` is the head's width and
## height; `depth` is its front-to-back size. The head faces -Z.
static func add_headgear(head: Node3D, kind: String, head_size: float, depth: float) -> void:
	var h := head_size
	var d := depth
	var top := h * 0.5
	match kind:
		"crown":
			var gold := Color(0.9, 0.72, 0.2)
			add_box(head, Vector3(h * 0.9, h * 0.18, d * 0.9), gold, Vector3(0, top + h * 0.09, 0))
			for x in [-0.33, 0.0, 0.33]:
				add_box(head, Vector3(h * 0.16, h * 0.22, d * 0.2), gold, Vector3(h * x, top + h * 0.29, -d * 0.35))
		"horns":
			var bone := Color(0.9, 0.86, 0.74)
			for side in [-1.0, 1.0]:
				add_box(head, Vector3(h * 0.14, h * 0.45, d * 0.25), bone,
						Vector3(h * 0.42 * side, top + h * 0.12, 0), -0.5 * side)
		"bucket":
			var metal := Color(0.5, 0.52, 0.55)
			add_box(head, Vector3(h * 1.05, h * 0.45, d * 1.05), metal, Vector3(0, top + h * 0.12, 0))
			add_box(head, Vector3(h * 1.2, h * 0.06, d * 1.2), metal.darkened(0.25), Vector3(0, top - h * 0.08, 0))
		"antlers":
			var wood := Color(0.42, 0.28, 0.16)
			for side in [-1.0, 1.0]:
				add_box(head, Vector3(h * 0.08, h * 0.55, d * 0.15), wood,
						Vector3(h * 0.3 * side, top + h * 0.25, 0), -0.35 * side)
				add_box(head, Vector3(h * 0.3, h * 0.07, d * 0.15), wood, Vector3(h * 0.48 * side, top + h * 0.38, 0))
		"hood":
			var cloth := Color(0.16, 0.14, 0.16)
			add_box(head, Vector3(h * 1.12, h * 0.12, d * 1.1), cloth, Vector3(0, top + h * 0.04, 0))
			for side in [-1.0, 1.0]:
				add_box(head, Vector3(h * 0.1, h * 1.0, d * 1.05), cloth, Vector3(h * 0.55 * side, 0, 0))
			add_box(head, Vector3(h * 1.12, h * 1.05, d * 0.1), cloth, Vector3(0, 0, d * 0.55))


## Adds a plain coloured box to `parent` (tilt turns it around the Z axis).
static func add_box(parent: Node3D, size: Vector3, color: Color, at: Vector3, tilt := 0.0) -> void:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.8
	var box := BoxMesh.new()
	box.size = size
	box.material = material
	var mesh := MeshInstance3D.new()
	mesh.mesh = box
	mesh.transform = Transform3D(Basis(Vector3.BACK, tilt), at)
	parent.add_child(mesh)
