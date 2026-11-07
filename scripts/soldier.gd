extends CharacterBody3D
## A soldier from the knight's army (PRD A-1, A-3, A-6).
##
## Three roles, all in bright blue tabards with gold trim so they read as
## friendly at a glance:
## - archer: green hood and a bow. Keeps its distance and shoots arrows.
## - spear: steel cap and a long spear. Closes in, with a long reach.
## - sword: steel cap, sword and a round shield. Closes in.
##
## Soldiers only ever attack dummies; their arrows can't hit the knight or each
## other. Dummies attack them, and a soldier who dies is gone for the rest of the
## run (the Army node removes it from the roster). Far from the knight, a soldier
## thinks less often and skips its walk animation, to save work (F-4).
## Everything runs on world time.

## Sent when the soldier falls. The Army node removes it from the roster.
signal died(soldier: Node)

const Config := preload("res://scripts/game_config.gd")
const ARROW_SCENE := preload("res://scenes/arrow.tscn")
## How close a soldier with nothing to fight stays to the knight.
const FOLLOW_DISTANCE := 4.0

## "archer", "spear" or "sword". Set before adding the soldier to the scene.
var role := "sword"
## This soldier's entry in the army roster.
var record := {}
var health := 0

var _stats := {}
var _target = null
var _knight = null
var _think_left := 0.0
var _cooldown_left := 0.0
var _windup_left := -1.0
var _far := false
var _dead := false
var _leaving := false
var _walk_cycle := 0.0
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

var _model: Node3D
var _left_leg: Node3D
var _right_leg: Node3D
var _left_arm: Node3D
var _right_arm: Node3D
var _materials: Array[StandardMaterial3D] = []


## Call before adding the soldier to the scene.
func setup(soldier_role: String, roster_record: Dictionary) -> void:
	role = soldier_role
	record = roster_record


func _ready() -> void:
	add_to_group("soldiers")
	add_to_group("dummy_targets")
	_stats = Config.SOLDIER_STATS[role]
	health = Config.SOLDIER_HEALTH
	_knight = get_tree().get_first_node_in_group("player")
	_build_model()
	# Start the first decision at a random moment so a group doesn't think in lockstep.
	_think_left = randf() * Config.SOLDIER_THINK_NEAR


func is_alive() -> bool:
	return not _dead and not _leaving


## Called by dummies when their swing lands.
func take_damage(amount: int, _from: Vector3, _attacker = null) -> void:
	if not is_alive():
		return
	health -= amount
	_flash()
	if health <= 0:
		_die()


## The wave is over: walk off back to the army (no death, so the soldier stays on the roster).
func return_to_army() -> void:
	if not is_alive():
		return
	_leaving = true
	remove_from_group("dummy_targets")
	var fade := create_tween()
	fade.tween_interval(0.5)
	fade.tween_property(_model, "scale", Vector3.ONE * 0.01, 0.5)
	fade.tween_callback(queue_free)


func _physics_process(delta: float) -> void:
	if _dead or _leaving:
		return
	_think_left -= delta
	if _think_left <= 0.0:
		_think()
	_cooldown_left = maxf(_cooldown_left - delta, 0.0)

	var desired := Vector3.ZERO
	if _windup_left >= 0.0:
		# Winding up an attack: stand still, then let it go.
		_windup_left -= delta
		if _windup_left < 0.0:
			_release_attack()
	elif _is_good_target(_target):
		var to_target: Vector3 = _target.global_position - global_position
		to_target.y = 0.0
		var distance := to_target.length()
		var toward := to_target / maxf(distance, 0.001)
		_face(toward)
		var attack_range: float = _stats["range"]
		if role == "archer":
			if distance < _stats["keep_min"]:
				desired = -toward
			elif distance > _stats["keep_max"]:
				desired = toward
			if distance <= attack_range and _cooldown_left == 0.0:
				_start_attack()
		elif distance > attack_range * 0.85:
			desired = toward
		elif _cooldown_left == 0.0:
			_start_attack()
	elif _knight != null:
		# Nothing to fight: stay near the knight.
		var to_knight: Vector3 = _knight.global_position - global_position
		to_knight.y = 0.0
		if to_knight.length() > FOLLOW_DISTANCE:
			desired = to_knight.normalized()
			_face(desired)

	velocity.x = desired.x * Config.SOLDIER_SPEED
	velocity.z = desired.z * Config.SOLDIER_SPEED
	if is_on_floor():
		velocity.y = 0.0
	else:
		velocity.y -= _gravity * delta
	move_and_slide()
	if not _far:
		_animate(delta)


## Picks the nearest dummy to fight. Far from the knight this happens less often.
func _think() -> void:
	if _knight != null:
		_far = global_position.distance_to(_knight.global_position) > Config.SOLDIER_FAR_DISTANCE
	_think_left = Config.SOLDIER_THINK_FAR if _far else Config.SOLDIER_THINK_NEAR
	_target = null
	var nearest_distance := INF
	var dummies: Array = get_tree().get_nodes_in_group("dummies")
	for dummy in dummies:
		if not dummy.is_alive():
			continue
		var distance: float = global_position.distance_squared_to(dummy.global_position)
		if distance < nearest_distance:
			_target = dummy
			nearest_distance = distance


func _is_good_target(candidate) -> bool:
	return is_instance_valid(candidate) and candidate.is_alive()


func _start_attack() -> void:
	_windup_left = _stats["windup"]
	_cooldown_left = _stats["cooldown"]
	_right_arm.rotation.x = 2.4


func _release_attack() -> void:
	_right_arm.rotation.x = 0.4
	if not _is_good_target(_target):
		return
	if role == "archer":
		_shoot_arrow()
		return
	var reach: float = _stats["range"] + 0.6
	var target_spot: Vector3 = _target.global_position
	if global_position.distance_to(target_spot) <= reach:
		_target.take_hit(_stats["damage"], global_position)


func _shoot_arrow() -> void:
	var start := global_position + Vector3(0.0, 1.3, 0.0) - _model.global_basis.z * 0.4
	var aim: Vector3 = _target.global_position + Vector3(0.0, 1.1, 0.0)
	# Aim a little high so the arrow's drop carries it onto the target.
	var flight_time := start.distance_to(aim) / Config.ARROW_SPEED
	aim.y += 0.5 * 6.0 * flight_time * flight_time
	var arrow = ARROW_SCENE.instantiate()
	get_tree().current_scene.add_child(arrow)
	arrow.launch(start, aim - start, _stats["damage"])


func _die() -> void:
	_dead = true
	remove_from_group("dummy_targets")
	remove_from_group("soldiers")
	died.emit(self)
	# Topple over, then sink away.
	var fall := create_tween()
	fall.tween_property(_model, "rotation:x", PI * 0.5, 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	fall.tween_interval(2.5)
	fall.tween_property(_model, "position:y", -1.0, 1.0)
	fall.tween_callback(queue_free)


func _face(direction: Vector3) -> void:
	if direction.length_squared() < 0.001:
		return
	_model.rotation.y = atan2(-direction.x, -direction.z)


func _animate(delta: float) -> void:
	var speed := Vector2(velocity.x, velocity.z).length()
	var amount := clampf(speed / Config.SOLDIER_SPEED, 0.0, 1.0)
	_walk_cycle = fmod(_walk_cycle + delta * 10.0 * amount, TAU)
	var swing := sin(_walk_cycle) * 0.6 * amount
	_left_leg.rotation.x = swing
	_right_leg.rotation.x = -swing
	_left_arm.rotation.x = -swing * 0.6
	if _windup_left < 0.0:
		# Ease the attacking arm back down after a swing.
		_right_arm.rotation.x = lerpf(_right_arm.rotation.x, swing * 0.6, 8.0 * delta)


## A quick red flash when hit.
func _flash() -> void:
	for material in _materials:
		material.emission_enabled = true
		material.emission = Color(0.8, 0.1, 0.1)
	var clear := create_tween()
	clear.tween_interval(0.12)
	clear.tween_callback(func() -> void:
		for material in _materials:
			material.emission_enabled = false)


# --- Building the model (low-poly boxes, facing -Z) --------------------------------

func _build_model() -> void:
	var blue := Color(0.16, 0.36, 0.82)
	var gold := Color(0.92, 0.74, 0.25)
	var steel := Color(0.68, 0.7, 0.74)
	var skin := Color(0.86, 0.68, 0.52)
	var leather := Color(0.36, 0.24, 0.14)
	var dark := Color(0.2, 0.22, 0.28)

	_model = Node3D.new()
	_model.name = "Model"
	add_child(_model)
	_left_leg = _pivot(_model, Vector3(-0.1, 0.78, 0))
	_right_leg = _pivot(_model, Vector3(0.1, 0.78, 0))
	for leg in [_left_leg, _right_leg]:
		_box(leg, Vector3(0.15, 0.72, 0.17), dark, Vector3(0, -0.38, 0))
		_box(leg, Vector3(0.17, 0.1, 0.24), leather, Vector3(0, -0.73, -0.03))
	_box(_model, Vector3(0.46, 0.56, 0.26), blue, Vector3(0, 1.06, 0))
	_box(_model, Vector3(0.48, 0.07, 0.28), gold, Vector3(0, 0.8, 0))
	_box(_model, Vector3(0.06, 0.4, 0.02), gold, Vector3(0, 1.08, -0.14))
	_box(_model, Vector3(0.24, 0.24, 0.24), skin, Vector3(0, 1.48, 0))
	_left_arm = _pivot(_model, Vector3(-0.3, 1.3, 0))
	_right_arm = _pivot(_model, Vector3(0.3, 1.3, 0))
	for arm in [_left_arm, _right_arm]:
		_box(arm, Vector3(0.13, 0.5, 0.14), blue.darkened(0.15), Vector3(0, -0.25, 0))
		_box(arm, Vector3(0.14, 0.1, 0.15), skin, Vector3(0, -0.53, 0))

	match role:
		"archer":
			var hood := Color(0.18, 0.5, 0.34)
			_box(_model, Vector3(0.28, 0.12, 0.28), hood, Vector3(0, 1.62, 0.01))
			_box(_model, Vector3(0.28, 0.22, 0.06), hood, Vector3(0, 1.48, 0.13))
			# A bow held in the left hand: three slats in a shallow curve.
			_box(_left_arm, Vector3(0.03, 0.5, 0.03), leather, Vector3(0, -0.55, -0.12))
			_box(_left_arm, Vector3(0.03, 0.3, 0.03), leather, Vector3(0, -0.2, -0.05), 0.0, 0.5)
			_box(_left_arm, Vector3(0.03, 0.3, 0.03), leather, Vector3(0, -0.9, -0.05), 0.0, -0.5)
			_box(_model, Vector3(0.12, 0.42, 0.12), leather, Vector3(0.12, 1.15, 0.18))
		"spear":
			_box(_model, Vector3(0.27, 0.1, 0.27), steel, Vector3(0, 1.64, 0))
			# Long shaft pointing forward from the right hand, with a steel tip.
			_box(_right_arm, Vector3(0.04, 0.04, 1.9), leather, Vector3(0, -0.55, -0.55))
			_box(_right_arm, Vector3(0.07, 0.03, 0.22), steel, Vector3(0, -0.55, -1.6))
		_:
			_box(_model, Vector3(0.27, 0.1, 0.27), steel, Vector3(0, 1.64, 0))
			_box(_right_arm, Vector3(0.05, 0.03, 0.7), steel, Vector3(0, -0.55, -0.4))
			_box(_right_arm, Vector3(0.16, 0.03, 0.04), gold, Vector3(0, -0.55, -0.05))
			# Round shield on the left arm, blue with a gold boss.
			var shield := CylinderMesh.new()
			shield.top_radius = 0.24
			shield.bottom_radius = 0.24
			shield.height = 0.04
			shield.radial_segments = 8
			shield.rings = 0
			shield.material = _material(blue)
			var shield_mesh := MeshInstance3D.new()
			shield_mesh.mesh = shield
			shield_mesh.transform = Transform3D(Basis(Vector3.FORWARD, PI / 2.0), Vector3(-0.1, -0.3, 0))
			_left_arm.add_child(shield_mesh)
			_box(_left_arm, Vector3(0.04, 0.1, 0.1), gold, Vector3(-0.13, -0.3, 0))


func _pivot(parent: Node3D, at: Vector3) -> Node3D:
	var pivot := Node3D.new()
	pivot.position = at
	parent.add_child(pivot)
	return pivot


func _box(parent: Node3D, size: Vector3, color: Color, at: Vector3, tilt_z := 0.0, tilt_x := 0.0) -> void:
	var box := BoxMesh.new()
	box.size = size
	box.material = _material(color)
	var mesh := MeshInstance3D.new()
	mesh.mesh = box
	mesh.transform = Transform3D(Basis.from_euler(Vector3(tilt_x, 0.0, tilt_z)), at)
	parent.add_child(mesh)


func _material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.9
	_materials.append(material)
	return material
