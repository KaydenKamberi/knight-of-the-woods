extends Node3D
## The forest's animals and the knight's tamed companions (PRD H-1 to H-6).
##
## At the start it scatters wild bears, wolves, deer and bunnies around the
## forest (WILD_ANIMALS in game_config.gd), away from the castle and the
## clearing. Taming one uses 1 of its food (H-2). The knight can keep 2 at a
## time (H-3): taming a third asks which one to let go. When a wave is cleared,
## fallen companions come back next to the knight, living ones heal (H-5), and
## the forest is topped back up with wild animals.
##
## A new game starts with no tamed animals (the scene reloads).

signal companions_changed(text: String)

const Config := preload("res://scripts/game_config.gd")
const ANIMAL := preload("res://scripts/animal.gd")
const Castle := preload("res://scripts/castle.gd")

var tamed: Array = []
var _rng := RandomNumberGenerator.new()
var _pending = null


func _ready() -> void:
	add_to_group("animals")
	_rng.randomize()
	_start.call_deferred()


func _start() -> void:
	_top_up_wild()
	var waves = get_tree().get_first_node_in_group("wave_manager")
	if waves != null:
		waves.wave_cleared.connect(_on_wave_cleared)
	_announce()


## E / Grab on a wild animal (H-2, H-3).
func try_tame(animal) -> void:
	var inventory = get_tree().get_first_node_in_group("inventory")
	var hud = get_tree().get_first_node_in_group("hud")
	if inventory == null or not is_instance_valid(animal) or animal.tamed:
		return
	var food: String = Config.ANIMALS[animal.kind]["food"]
	if inventory.materials.get(food, 0) <= 0:
		if hud != null:
			hud.show_toast(animal.pickup_prompt())
		return
	if tamed.size() >= Config.MAX_TAMED:
		# H-3: ask which one to let go first.
		_pending = animal
		if hud != null:
			var names: Array[String] = []
			for companion in tamed:
				names.append(companion.display_name())
			hud.ask_release(names, animal.display_name(), _on_release_chosen)
		return
	_tame(animal)


func _on_release_chosen(index: int) -> void:
	var animal = _pending
	_pending = null
	if index < 0 or index >= tamed.size() or not is_instance_valid(animal) or not animal.is_alive():
		return
	var old = tamed[index]
	tamed.remove_at(index)
	old.release()
	var hud = get_tree().get_first_node_in_group("hud")
	if hud != null:
		hud.show_toast("The %s goes back to the forest." % String(old.display_name()).to_lower())
	_tame(animal)


func _tame(animal) -> void:
	var inventory = get_tree().get_first_node_in_group("inventory")
	var food: String = Config.ANIMALS[animal.kind]["food"]
	if inventory == null or not inventory.spend(food, 1):
		return
	WorldTime.bump()
	tamed.append(animal)
	for i in tamed.size():
		tamed[i].set_slot(i)
	animal.become_tamed(tamed.size() - 1)
	if not animal.health_changed.is_connected(_announce):
		animal.health_changed.connect(_announce)
	var hud = get_tree().get_first_node_in_group("hud")
	if hud != null:
		hud.show_toast("The %s is on your side!" % String(animal.display_name()).to_lower())
	_announce()


func _on_wave_cleared(_wave: int) -> void:
	var knight = get_tree().get_first_node_in_group("player")
	for animal in tamed:
		if is_instance_valid(animal) and knight != null:
			animal.revive_near(knight.global_position, knight.in_bunker)
	_top_up_wild()
	_announce()


## Brings each kind of wild animal back up to its number in WILD_ANIMALS.
func _top_up_wild() -> void:
	var counts := {}
	for animal in get_tree().get_nodes_in_group("wild_animals"):
		counts[animal.kind] = counts.get(animal.kind, 0) + 1
	for kind in Config.WILD_ANIMALS:
		for i in Config.WILD_ANIMALS[kind] - counts.get(kind, 0):
			_spawn_wild(kind)


func _spawn_wild(kind: String) -> void:
	var animal = ANIMAL.new()
	animal.kind = kind
	animal.name = "%s_%d" % [kind.capitalize(), _rng.randi() % 100000]
	animal.position = _random_spot()
	animal.rotation.y = _rng.randf() * TAU
	add_child(animal)


## Somewhere in the forest, away from the clearing, the castle and the knight.
func _random_spot() -> Vector3:
	var knight := get_tree().get_first_node_in_group("player") as Node3D
	for attempt in 30:
		var angle := _rng.randf() * TAU
		var distance := _rng.randf_range(11.0, 28.0)
		var spot := Vector3(cos(angle), 0.0, sin(angle)) * distance
		if Castle.is_inside(spot) or spot.distance_to(Config.CASTLE_CENTER) < Config.CASTLE_SPAWN_KEEP_OUT:
			continue
		if knight != null and spot.distance_to(knight.global_position) < 8.0:
			continue
		return spot
	return Vector3(-20.0, 0.0, -10.0)


## Tells the HUD who's with the knight and how they're doing.
func _announce() -> void:
	var parts: Array[String] = []
	for animal in tamed:
		if is_instance_valid(animal):
			parts.append(animal.health_text())
	companions_changed.emit("  ·  ".join(parts))
