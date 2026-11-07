extends Node
## The knight's army (PRD A-1, A-2, A-3, A-5).
##
## Holds the roster: ARMY_SIZE soldiers (in game_config.gd), split evenly
## between archers, spearmen and sword fighters. The first time the knight
## drops to half health during a wave, RESCUE_COUNT soldiers from the roster run
## in to help. That happens once per wave. When the wave is cleared, survivors
## go back to the roster. A soldier who dies is removed from the roster for the
## rest of the run.

## Sent whenever the roster changes. counts maps each role to how many are left.
signal army_changed(total: int, in_field: int, counts: Dictionary)
signal rescue_arrived(count: int)
signal soldier_fell(role: String)

const Config := preload("res://scripts/game_config.gd")
const SOLDIER_SCENE := preload("res://scenes/soldier.tscn")
const ROLES := ["archer", "spear", "sword"]

## Every soldier still alive this run: {"id": int, "role": String, "in_field": bool}.
var roster: Array[Dictionary] = []

var _in_field: Array = []
var _rescued_this_wave := false
var _wave_running := false


func _ready() -> void:
	add_to_group("army")
	for i in Config.ARMY_SIZE:
		roster.append({"id": i, "role": ROLES[i % ROLES.size()], "in_field": false})
	_announce.call_deferred()


# --- Connected in forest.tscn ------------------------------------------------------

func on_knight_health_changed(health: int, max_health: int) -> void:
	if not _wave_running or _rescued_this_wave or health <= 0:
		return
	if health <= max_health * Config.RESCUE_HEALTH_FRACTION:
		_send_rescue()


## True while a wave is being fought (rescues only happen then).
func is_wave_running() -> bool:
	return _wave_running


## True once this wave's rescue has been sent.
func has_rescued_this_wave() -> bool:
	return _rescued_this_wave


func on_wave_started(_wave: int, _last_wave: int) -> void:
	_wave_running = true
	_rescued_this_wave = false


## The wave is over: survivors head back to the roster.
func on_wave_cleared(_wave: int) -> void:
	_wave_running = false
	for soldier in _in_field:
		if is_instance_valid(soldier) and soldier.is_alive():
			soldier.return_to_army()
	_in_field.clear()
	for record in roster:
		record["in_field"] = false
	_announce()


# -------------------------------------------------------------------------------

func _send_rescue() -> void:
	var knight := get_tree().get_first_node_in_group("player") as Node3D
	if knight == null:
		return
	var available: Array = roster.filter(func(record: Dictionary) -> bool: return not record["in_field"])
	if available.is_empty():
		return
	_rescued_this_wave = true
	# Mix the roles: number each soldier within its role, then take the 1st of
	# each role, then the 2nd of each, and so on.
	available.shuffle()
	var per_role := {}
	var turns: Array = []
	for record in available:
		var turn: int = per_role.get(record["role"], 0)
		per_role[record["role"]] = turn + 1
		turns.append([turn, record])
	turns.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	var count := mini(Config.RESCUE_COUNT, turns.size())
	for i in count:
		var record: Dictionary = turns[i][1]
		record["in_field"] = true
		var soldier = SOLDIER_SCENE.instantiate()
		soldier.setup(record["role"], record)
		soldier.position = _spawn_spot(knight.global_position, i, count)
		soldier.died.connect(_on_soldier_died)
		get_tree().current_scene.add_child(soldier)
		_in_field.append(soldier)
	rescue_arrived.emit(count)
	_announce()


func _on_soldier_died(soldier: Node) -> void:
	roster.erase(soldier.record)
	_in_field.erase(soldier)
	soldier_fell.emit(soldier.role)
	_announce()


## A clear spot around the knight, spread evenly between the rescuers.
func _spawn_spot(center: Vector3, index: int, count: int) -> Vector3:
	var base_angle := randf() * TAU
	# current_scene is only typed as Node, so cast it to reach the 3D world.
	var space: PhysicsDirectSpaceState3D = (get_tree().current_scene as Node3D).get_world_3d().direct_space_state
	var probe := SphereShape3D.new()
	probe.radius = 0.5
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = probe
	query.collision_mask = 1 | 4  # trees, rocks and the edge wall
	for attempt in 8:
		var angle := base_angle + TAU * index / count + attempt * 0.45
		var spot := center + Vector3(cos(angle), 0.0, sin(angle)) * Config.RESCUE_SPAWN_DISTANCE
		spot.y = 0.0
		query.transform = Transform3D(Basis.IDENTITY, spot + Vector3.UP)
		if space.intersect_shape(query, 1).is_empty():
			return spot
	return Vector3(center.x, 0.0, center.z) + Vector3(randf_range(-2, 2), 0.0, randf_range(-2, 2))


func _announce() -> void:
	var counts := {"archer": 0, "spear": 0, "sword": 0}
	for record in roster:
		counts[record["role"]] += 1
	army_changed.emit(roster.size(), _in_field.size(), counts)
