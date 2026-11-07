extends Node
## The knight's army (PRD A-1 to A-5).
##
## Holds the roster: ARMY_SIZE soldiers (in game_config.gd), split evenly
## between archers, spearmen and sword fighters. While they're not fighting they
## stand around in the castle courtyard, so the castle feels lived in.
##
## - Waves 1 to 19: the first time the knight drops to half health, RESCUE_COUNT
##   soldiers run out of the castle gate to help (or appear near him if he's far
##   from the castle, so they arrive in time). Once per wave. When the wave is
##   cleared, survivors go back to the courtyard.
## - Wave 20 (the final battle): every soldier still alive marches out of the
##   gate and joins the fight (A-4).
## - A soldier who dies is removed from the roster for the rest of the run (A-3).

## Sent whenever the roster changes. counts maps each role to how many are left.
signal army_changed(total: int, in_field: int, counts: Dictionary)
signal rescue_arrived(count: int)
signal soldier_fell(role: String)
signal army_marched_out(count: int)

const Config := preload("res://scripts/game_config.gd")
const Castle := preload("res://scripts/castle.gd")
const SOLDIER_SCENE := preload("res://scenes/soldier.tscn")
const ROLES := ["archer", "spear", "sword"]

## Every soldier still alive this run: {"id": int, "role": String, "in_field": bool}.
var roster: Array[Dictionary] = []

var _in_field: Array = []
## Roster id -> the idle soldier standing in the courtyard for it.
var _idle := {}
var _rescued_this_wave := false
var _wave_running := false


func _ready() -> void:
	add_to_group("army")
	for i in Config.ARMY_SIZE:
		roster.append({"id": i, "role": ROLES[i % ROLES.size()], "in_field": false})
	_announce.call_deferred()
	_refresh_idle.call_deferred()


## True while a wave is being fought (rescues only happen then).
func is_wave_running() -> bool:
	return _wave_running


## True once this wave's rescue has been sent (or the whole army is already out).
func has_rescued_this_wave() -> bool:
	return _rescued_this_wave


## The soldiers fighting right now (for the victory cheer).
func field_soldiers() -> Array:
	return _in_field.filter(func(soldier) -> bool: return is_instance_valid(soldier) and soldier.is_alive())


# --- Connected in forest.tscn ------------------------------------------------------

func on_knight_health_changed(health: int, max_health: int) -> void:
	if not _wave_running or _rescued_this_wave or health <= 0:
		return
	if health <= max_health * Config.RESCUE_HEALTH_FRACTION:
		_send_rescue()


func on_wave_started(wave: int, last_wave: int) -> void:
	_wave_running = true
	_rescued_this_wave = false
	if wave >= last_wave:
		_march_out_everyone()


## The wave is over: survivors head back to the courtyard.
func on_wave_cleared(_wave: int) -> void:
	_wave_running = false
	for soldier in _in_field:
		if is_instance_valid(soldier) and soldier.is_alive():
			soldier.return_to_army()
	_in_field.clear()
	for record in roster:
		record["in_field"] = false
	_refresh_idle()
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
	# Out of the gate if the knight is near the castle, otherwise right by him.
	var gate := Castle.gate_outside()
	var from_gate := knight.global_position.distance_to(gate) <= Config.RESCUE_FROM_GATE_RANGE
	for i in count:
		var record: Dictionary = turns[i][1]
		var spot := gate + Vector3((i - (count - 1) * 0.5) * 1.3, 0.0, 0.0) if from_gate \
				else _spawn_spot(knight.global_position, i, count)
		_deploy(record, spot)
	_refresh_idle()
	rescue_arrived.emit(count)
	_announce()


## Wave 20: every soldier still alive marches out of the gate in rows of five.
func _march_out_everyone() -> void:
	_rescued_this_wave = true
	var gate := Castle.gate_outside()
	var index := 0
	for record in roster:
		if record["in_field"]:
			continue
		var row := index / 5
		var column := index % 5
		_deploy(record, gate + Vector3((column - 2) * 1.3, 0.0, -row * 1.3))
		index += 1
	_refresh_idle()
	army_marched_out.emit(index)
	_announce()


func _deploy(record: Dictionary, spot: Vector3) -> void:
	record["in_field"] = true
	var soldier = SOLDIER_SCENE.instantiate()
	soldier.setup(record["role"], record)
	soldier.position = spot
	soldier.died.connect(_on_soldier_died)
	get_tree().current_scene.add_child(soldier)
	_in_field.append(soldier)


func _on_soldier_died(soldier: Node) -> void:
	roster.erase(soldier.record)
	_in_field.erase(soldier)
	soldier_fell.emit(soldier.role)
	_announce()


## Makes the courtyard match the roster: one idle soldier for every soldier at home.
func _refresh_idle() -> void:
	var at_home := {}
	for record in roster:
		if not record["in_field"] and at_home.size() < Config.IDLE_SOLDIERS_SHOWN:
			at_home[record["id"]] = record
	for id in _idle.keys():
		if not at_home.has(id):
			if is_instance_valid(_idle[id]):
				_idle[id].queue_free()
			_idle.erase(id)
	var spots := _courtyard_spots()
	var index := 0
	for id in at_home:
		if not _idle.has(id) and index < spots.size():
			var record: Dictionary = at_home[id]
			var soldier = SOLDIER_SCENE.instantiate()
			soldier.idle = true
			soldier.setup(record["role"], record)
			soldier.position = spots[(id * 7) % spots.size()]
			get_tree().current_scene.add_child(soldier)
			# Mostly facing the gate, each turned a little differently.
			soldier.face(Vector3(sin(id * 1.7) * 0.4, 0.0, -1.0))
			_idle[id] = soldier
		index += 1


## Standing spots in the courtyard, in a loose grid that keeps clear of the gate
## lane, the knight's starting spot and the furnace corner.
func _courtyard_spots() -> Array[Vector3]:
	var spots: Array[Vector3] = []
	var furnace := Vector2(Config.FURNACE_OFFSET.x, Config.FURNACE_OFFSET.z)
	for x in [-6.0, -4.6, -3.2, -1.9, 1.9, 3.2, 4.6, 6.0]:
		for z in [-5.6, -4.0, -2.4, -0.8, 0.8, 2.4, 4.0, 5.6]:
			if Vector2(x, z).distance_to(furnace) < 2.6:
				continue
			spots.append(Config.CASTLE_CENTER + Vector3(x, 0.0, z))
	return spots


## A clear spot around the knight, spread evenly between the rescuers.
func _spawn_spot(center: Vector3, index: int, count: int) -> Vector3:
	var base_angle := randf() * TAU
	# current_scene is only typed as Node, so cast it to reach the 3D world.
	var space: PhysicsDirectSpaceState3D = (get_tree().current_scene as Node3D).get_world_3d().direct_space_state
	var probe := SphereShape3D.new()
	probe.radius = 0.5
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = probe
	query.collision_mask = 1 | 4  # trees, rocks, castle walls and the edge wall
	for attempt in 8:
		var angle := base_angle + TAU * index / count + attempt * 0.45
		var spot := center + Vector3(cos(angle), 0.0, sin(angle)) * Config.RESCUE_SPAWN_DISTANCE
		spot.y = 0.0
		query.transform = Transform3D(Basis.IDENTITY, spot + Vector3.UP)
		if space.intersect_shape(query, 1).is_empty() and not Castle.is_inside(spot):
			return spot
	return Vector3(center.x, 0.0, center.z) + Vector3(randf_range(-2, 2), 0.0, randf_range(-2, 2))


func _announce() -> void:
	var counts := {"archer": 0, "spear": 0, "sword": 0}
	for record in roster:
		counts[record["role"]] += 1
	army_changed.emit(roster.size(), _in_field.size(), counts)
