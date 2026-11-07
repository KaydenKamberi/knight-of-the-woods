extends RefCounted
## Rolls and spawns the loot a defeated dummy or mini boss drops (PRD R-2,
## R-11, R-13). The amounts and chances come from game_config.gd.

const Config := preload("res://scripts/game_config.gd")
const LOOT_SCRIPT := preload("res://scripts/loot.gd")
const Pool := preload("res://scripts/pool.gd")


static func drop_from(enemy: Node3D, is_mini_boss: bool) -> void:
	var drops: Array[String] = []
	if is_mini_boss:
		for i in Config.MINI_BOSS_CRYO_DROPS:
			drops.append("cryo")
		for i in Config.MINI_BOSS_RANDOM_DROPS:
			drops.append(random_material())
		if randf() < Config.ULTRA_DROP_CHANCE:
			drops.append("ultra")
	else:
		for i in randi_range(Config.DUMMY_DROPS_MIN, Config.DUMMY_DROPS_MAX):
			drops.append(random_material())

	_spawn(enemy, drops)


## Drops `items` (e.g. {"wood": 2}) from `enemy`: what a killed bandit stole (D-3).
static func drop_items(enemy: Node3D, items: Dictionary) -> void:
	var drops: Array[String] = []
	for id in items:
		for i in int(items[id]):
			drops.append(id)
	_spawn(enemy, drops)


static func _spawn(enemy: Node3D, drops: Array[String]) -> void:
	var scene_root := enemy.get_tree().current_scene
	var origin := enemy.global_position + Vector3.UP
	for id in drops:
		var loot = Pool.take("loot")
		if loot == null:
			loot = LOOT_SCRIPT.new()
		scene_root.add_child(loot)
		# Pop out of the body in a random direction.
		var angle := randf() * TAU
		var sideways := Vector3(cos(angle), 0.0, sin(angle)) * randf_range(1.0, 2.5)
		loot.setup(id, origin, sideways + Vector3.UP * randf_range(3.0, 5.0))


## A random regular material, weighted by DROP_WEIGHTS (string is the rarest).
static func random_material() -> String:
	var total := 0
	for id in Config.DROP_WEIGHTS:
		total += Config.DROP_WEIGHTS[id]
	var roll := randi_range(1, total)
	for id in Config.DROP_WEIGHTS:
		roll -= Config.DROP_WEIGHTS[id]
		if roll <= 0:
			return id
	return "wood"
