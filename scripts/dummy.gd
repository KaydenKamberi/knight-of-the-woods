extends CharacterBody3D
## A floppy straw training dummy that has come to life (PRD E-1, E-2, E-3).
##
## It walks straight at the nearest target (the knight, or a soldier from his
## army) and swings at it when close. A hit
## knocks it into ragdoll physics: it flops to the ground, then pulls itself
## back together and keeps coming. When its health runs out it goes fully
## ragdoll and falls apart into pieces.
##
## The body is a set of boxes built in code. While walking, the boxes hang off
## a tree of pivot nodes that the walk animation swings. For the ragdoll, each
## box moves into its own RigidBody3D, joined to its neighbours by PinJoint3Ds.
## Walking, attacking, timers and the ragdoll physics all run on world time.
##
## Mini bosses (M4) use this same script, set up by configure_mini_boss(): they
## are bigger, tougher, wear headgear, and only flinch when hit until their
## health runs out, then fall apart like any dummy.
##
## Crafted weapons (M5.5) can also freeze a dummy solid (hammer slam), freeze
## its head (Cryo dagger) so the next dagger hit shatters it, or slow it (Cryo
## armour). A defeated dummy drops loot.

## Sent once, when the dummy's health reaches zero.
signal defeated
signal health_changed(health: int, max_health: int)

enum State { WALKING, ATTACKING, RAGDOLL, REASSEMBLING, DEFEATED }

## Physics layer values (see Project Settings > Layer Names > 3D Physics).
const WORLD_LAYER := 1
const DEBRIS_LAYER := 16
const MiniBosses := preload("res://scripts/mini_bosses.gd")
const Config := preload("res://scripts/game_config.gd")
const LootDrops := preload("res://scripts/loot_drops.gd")
const ICE_COLOR := Color(0.6, 0.85, 1.0)

@export var max_health := Config.DUMMY_HEALTH
@export var walk_speed := 2.2
@export var turn_speed := 6.0

@export_group("Attack")
## How close the dummy has to be to swing at the knight, in metres.
@export var attack_range := 1.4
@export var attack_damage := Config.DUMMY_DAMAGE
## Seconds of wind-up before a swing lands. In slow motion that's plenty of time to react.
@export var attack_windup := 0.6
## Seconds after a swing before the dummy walks again.
@export var attack_cooldown := 1.0

@export_group("Look")
## Scales the whole body. Mini bosses are about 1.5 to 1.9.
@export var size_scale := 1.0
@export var cloth_color := Color(0.74, 0.62, 0.42)
## "", "crown", "horns", "bucket", "antlers" or "hood".
@export var headgear := ""

@export_group("Ragdoll")
## When off (mini bosses), hits only make it flinch until its health runs out.
@export var ragdoll_on_hit := true
## Seconds a hit dummy lies on the ground before getting back up.
@export var ragdoll_time := 2.0
## Seconds it takes to pull itself back together.
@export var reassemble_time := 0.45
## Seconds after defeat before its joints break and it falls apart.
@export var fall_apart_delay := 0.3
## Seconds (world time) the pieces lie around before they shrink away.
@export var debris_lifetime := 10.0

var health := 0
var state := State.WALKING
var is_mini_boss := false
var boss_name := ""

## What it's walking at: the knight or a soldier (anything in the "dummy_targets" group).
var _target = null
var _retarget_left := 0.0
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
## One entry per body part: its spec plus "pivot", "mesh", "rest" and "body".
var _parts: Array[Dictionary] = []
var _pivots := {}
var _state_time := 0.0
var _swung := false
var _fell_apart := false
var _walk_cycle := 0.0
var _stuck_time := 0.0
var _detour_time := 0.0
var _detour_side := 1.0
var _reassemble_tween: Tween
var _flinch_tween: Tween
var _stagger_left := 0.0
var _frozen_left := 0.0
var _slow_left := 0.0
var _slow_factor := 1.0
var _head_ice: MeshInstance3D
## The cloth materials and their normal colours, so freezing can tint them icy and back.
var _body_materials := {}

@onready var _body: Node3D = $Body
@onready var _collision: CollisionShape3D = $Collision
## Holds the ragdoll's rigid bodies and joints. It's top level, so moving the dummy doesn't drag them.
@onready var _ragdoll_root: Node3D = $Ragdoll


func _ready() -> void:
	health = max_health
	add_to_group("dummies")
	_fit_collision_to_size()
	_build_body()


## Turns this dummy into the given wave's mini boss. Call before adding it to the scene.
func configure_mini_boss(info: Dictionary) -> void:
	is_mini_boss = true
	boss_name = info["name"]
	size_scale = info["size"]
	cloth_color = info["color"]
	headgear = info["headgear"]
	max_health = info["health"]
	attack_damage = info["damage"]
	walk_speed = info["walk_speed"]
	attack_range *= size_scale
	attack_windup = 0.7
	ragdoll_on_hit = false


func _physics_process(delta: float) -> void:
	_slow_left = maxf(_slow_left - delta, 0.0)
	if _frozen_left > 0.0:
		# Frozen solid: no walking or swinging until it thaws.
		_frozen_left -= delta
		if _frozen_left <= 0.0:
			_set_ice_tint(false)
		if state == State.WALKING or state == State.ATTACKING:
			return
	# A slowed dummy does everything at a fraction of its speed (Cryo armour, R-10).
	var action_delta := delta * (_slow_factor if _slow_left > 0.0 else 1.0)
	_state_time += action_delta
	match state:
		State.WALKING:
			_walk(action_delta)
		State.ATTACKING:
			_attack(action_delta)
		State.RAGDOLL:
			if _state_time >= ragdoll_time:
				_reassemble()
		State.DEFEATED:
			if not _fell_apart and _state_time >= fall_apart_delay:
				_fall_apart()


func is_alive() -> bool:
	return state != State.DEFEATED


## Called by a melee hit or a blast (soldiers, the knight's weapons, explosions).
## `from` is where the hit came from. With knockdown off (Cryo armour's
## reflected damage), a regular dummy only flinches instead of going ragdoll.
func take_hit(damage: int, from: Vector3, push := 3.0, knockdown := true) -> void:
	var aim := global_position + Vector3.UP * 1.2 * size_scale
	var direction := aim - from
	direction.y = 0.0
	direction = direction.normalized() if direction.length_squared() > 0.0001 else -_body.global_basis.z
	_apply_hit(_find_part("torso"), damage, direction, push, knockdown)


## Share of health left, from 1.0 (full) to 0.0.
func health_fraction() -> float:
	return float(health) / maxf(max_health, 1)


## Freezes the dummy solid for `seconds` of world time (hammer slam, R-6).
func freeze(seconds: float) -> void:
	if state == State.DEFEATED or state == State.RAGDOLL:
		return
	_frozen_left = maxf(_frozen_left, seconds)
	_set_ice_tint(true)


## Slows the dummy to `factor` of its speed for `seconds` (Cryo armour, R-10).
func apply_slow(factor: float, seconds: float) -> void:
	_slow_factor = factor
	_slow_left = maxf(_slow_left, seconds)


func has_frozen_head() -> bool:
	return is_instance_valid(_head_ice)


## Encases the head in ice (Cryo dagger, R-8). The next dagger hit shatters it.
func freeze_head() -> void:
	if state == State.DEFEATED or has_frozen_head():
		return
	var head: Node3D = _find_part("head")["mesh"]
	var ice := BoxMesh.new()
	ice.size = Vector3.ONE * 0.38 * size_scale
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(ICE_COLOR, 0.55)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.emission_enabled = true
	material.emission = ICE_COLOR * 0.4
	ice.material = material
	_head_ice = MeshInstance3D.new()
	_head_ice.mesh = ice
	head.add_child(_head_ice)


## Shatters a frozen head: a regular dummy is defeated outright; a mini boss
## takes DAGGER_SHATTER_BOSS_DAMAGE instead (R-8).
func shatter_head(from: Vector3) -> void:
	if not has_frozen_head():
		return
	_head_ice.queue_free()
	_head_ice = null
	if is_mini_boss:
		take_hit(Config.DAGGER_SHATTER_BOSS_DAMAGE, from)
		return
	(_find_part("head")["mesh"] as Node3D).visible = false
	shatter(from)


## Defeats the dummy on the spot (a frozen head shattering, or the hammer slam).
func shatter(from: Vector3) -> void:
	if state != State.DEFEATED:
		take_hit(health, from, 5.0)


## Called by a knife or arrow that hits this dummy (or one of its ragdoll pieces).
## Returns the body part the projectile should stick into.
func take_projectile_hit(collider: Object, point: Vector3, direction: Vector3, damage: int, push: float) -> Node3D:
	var part := _part_hit_by(collider, point)
	_apply_hit(part, damage, direction, push)
	return part["mesh"]


func _apply_hit(part: Dictionary, damage: int, direction: Vector3, push: float, knockdown := true) -> void:
	if state != State.DEFEATED:
		health = maxi(health - damage, 0)
		health_changed.emit(health, max_health)
		if health == 0:
			if state != State.RAGDOLL:
				_go_ragdoll()
			_start(State.DEFEATED)
			remove_from_group("dummies")
			_set_ice_tint(false)
			LootDrops.drop_from(self, is_mini_boss)
			defeated.emit()
		elif not ragdoll_on_hit or not knockdown:
			_flinch()
		elif state == State.RAGDOLL:
			_state_time = 0.0  # Knocked down again: stay down a little longer.
		else:
			_go_ragdoll()
	var body: RigidBody3D = part["body"]
	if body != null:
		body.linear_velocity += direction * push + Vector3.UP


# --- Walking and attacking ---------------------------------------------------

func _walk(delta: float) -> void:
	_update_target(delta)
	var has_target: bool = _target != null
	var to_target := Vector3.ZERO
	if has_target:
		to_target = _target.global_position - global_position
		to_target.y = 0.0
	var distance := to_target.length()

	var direction := Vector3.ZERO
	_stagger_left = maxf(_stagger_left - delta, 0.0)
	if has_target and distance > attack_range * 0.8 and _stagger_left == 0.0:
		direction = to_target / distance
		if _detour_time > 0.0:
			# Stuck on a tree or rock: walk off to one side for a moment.
			_detour_time -= delta
			direction = direction.rotated(Vector3.UP, _detour_side * 1.2)
	var speed := walk_speed * (_slow_factor if _slow_left > 0.0 else 1.0)
	velocity.x = direction.x * speed
	velocity.z = direction.z * speed
	_apply_gravity(delta)
	var before := global_position
	move_and_slide()

	if direction != Vector3.ZERO:
		var moved_speed := (global_position - before).length() / maxf(delta, 0.0001)
		_stuck_time = _stuck_time + delta if moved_speed < speed * 0.3 else 0.0
		if _stuck_time > 0.5:
			_stuck_time = 0.0
			_detour_time = 1.0
			_detour_side = -1.0 if randf() < 0.5 else 1.0

	_turn_towards(to_target if has_target else direction, delta)
	_animate_walk(delta, Vector2(velocity.x, velocity.z).length() / walk_speed)
	if has_target and distance <= attack_range:
		_start(State.ATTACKING)


func _attack(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, 20.0 * delta)
	velocity.z = move_toward(velocity.z, 0.0, 20.0 * delta)
	_apply_gravity(delta)
	move_and_slide()

	if not _is_good_target(_target):
		_target = null
	var to_target := Vector3.ZERO
	if _target != null:
		to_target = _target.global_position - global_position
		to_target.y = 0.0
	_turn_towards(to_target, delta)
	_animate_walk(delta, 0.0)

	# Raise both arms during the wind-up, then bring them down hard.
	var arms_up := 2.4
	if not _swung:
		_set_arm_angle(lerpf(0.0, arms_up, clampf(_state_time / attack_windup, 0.0, 1.0)))
		if _state_time >= attack_windup:
			_swung = true
			if _target != null and to_target.length() <= attack_range + 0.4:
				_target.take_damage(attack_damage, global_position, self)
	else:
		_set_arm_angle(lerpf(arms_up, 0.3, clampf((_state_time - attack_windup) / 0.15, 0.0, 1.0)))
		if _state_time >= attack_windup + attack_cooldown:
			_start(State.WALKING)


## A mini boss rocks back and stops for a moment instead of going ragdoll.
func _flinch() -> void:
	if _flinch_tween:
		_flinch_tween.kill()
	_stagger_left = 0.3
	_flinch_tween = create_tween()
	_flinch_tween.tween_property(_body, "rotation:x", 0.3, 0.08)
	_flinch_tween.tween_property(_body, "rotation:x", 0.0, 0.25)


## Picks the nearest knight or soldier every half second (or sooner if the current one falls).
func _update_target(delta: float) -> void:
	_retarget_left -= delta
	if _retarget_left > 0.0 and _is_good_target(_target):
		return
	_retarget_left = 0.5
	_target = null
	var nearest_distance := INF
	var targets: Array = get_tree().get_nodes_in_group("dummy_targets")
	for candidate in targets:
		if not candidate.is_alive():
			continue
		var distance: float = global_position.distance_squared_to(candidate.global_position)
		if distance < nearest_distance:
			_target = candidate
			nearest_distance = distance


func _set_ice_tint(frozen: bool) -> void:
	for material: StandardMaterial3D in _body_materials:
		var normal: Color = _body_materials[material]
		material.albedo_color = normal.lerp(ICE_COLOR, 0.65) if frozen else normal


func _is_good_target(candidate) -> bool:
	return is_instance_valid(candidate) and candidate.is_alive()


func _start(new_state: State) -> void:
	state = new_state
	_state_time = 0.0
	_swung = false


func _apply_gravity(delta: float) -> void:
	if is_on_floor():
		velocity.y = 0.0
	else:
		velocity.y -= _gravity * delta


func _turn_towards(direction: Vector3, delta: float) -> void:
	if direction.length_squared() < 0.001:
		return
	# The body faces -Z, so this angle turns -Z towards the direction.
	var target_angle := atan2(-direction.x, -direction.z)
	_body.rotation.y = lerp_angle(_body.rotation.y, target_angle, turn_speed * delta)


func _animate_walk(delta: float, amount: float) -> void:
	amount = clampf(amount, 0.0, 1.0)
	_walk_cycle = fmod(_walk_cycle + delta * 7.0 * amount, TAU)
	var swing := sin(_walk_cycle) * 0.55 * amount
	# Positive X rotation swings a hanging limb forward.
	_pivots["thigh_l"].rotation.x = swing
	_pivots["thigh_r"].rotation.x = -swing
	_pivots["shin_l"].rotation.x = -0.5 * amount * (0.5 + 0.5 * sin(_walk_cycle + 1.6))
	_pivots["shin_r"].rotation.x = -0.5 * amount * (0.5 + 0.5 * sin(_walk_cycle + 1.6 + PI))
	if state == State.WALKING:
		_pivots["upper_arm_l"].rotation.x = -swing * 0.8
		_pivots["upper_arm_r"].rotation.x = swing * 0.8
	# A floppy wobble of the head and body.
	_pivots["head"].rotation.z = sin(_walk_cycle * 0.5) * 0.18 * amount
	_pivots["torso"].rotation.z = sin(_walk_cycle) * 0.05 * amount


func _set_arm_angle(angle: float) -> void:
	_pivots["upper_arm_l"].rotation.x = angle
	_pivots["upper_arm_r"].rotation.x = angle


func _reset_pose() -> void:
	for pivot: Node3D in _pivots.values():
		pivot.rotation = Vector3.ZERO


# --- Ragdoll -------------------------------------------------------------------

func _go_ragdoll() -> void:
	if _reassemble_tween:
		_reassemble_tween.kill()
	if _flinch_tween:
		_flinch_tween.kill()
	_start(State.RAGDOLL)
	_frozen_left = 0.0
	_set_ice_tint(false)
	_collision.set_deferred("disabled", true)

	# Move every box into its own rigid body, right where it is now.
	for part in _parts:
		var body := RigidBody3D.new()
		body.name = String(part["name"]).to_pascal_case()
		body.collision_layer = DEBRIS_LAYER
		body.collision_mask = WORLD_LAYER | DEBRIS_LAYER
		body.mass = part["mass"] * pow(size_scale, 3.0)
		body.angular_damp = 1.5
		# Lets a knife find this dummy when it hits a loose piece.
		body.set_meta("dummy", self)
		body.set_meta("part_name", part["name"])
		var shape := BoxShape3D.new()
		shape.size = part["size"]
		var collision := CollisionShape3D.new()
		collision.shape = shape
		body.add_child(collision)
		_ragdoll_root.add_child(body)
		var mesh: MeshInstance3D = part["mesh"]
		body.global_transform = mesh.global_transform
		mesh.reparent(body, true)
		body.linear_velocity = Vector3(velocity.x, 0.0, velocity.z)
		part["body"] = body

	# Pin each piece to its parent where the two meet.
	for part in _parts:
		if String(part["parent"]).is_empty():
			continue
		var pin := PinJoint3D.new()
		_ragdoll_root.add_child(pin)
		pin.global_position = (part["pivot"] as Node3D).global_position
		pin.node_a = pin.get_path_to(_find_part(part["parent"])["body"])
		pin.node_b = pin.get_path_to(part["body"])

	_reset_pose()


## Gets back up: every piece flies back to its place on the body.
func _reassemble() -> void:
	_start(State.REASSEMBLING)
	var pelvis: RigidBody3D = _parts[0]["body"]
	var spot := pelvis.global_position
	spot.y = global_position.y
	global_position = spot
	if _is_good_target(_target):
		var to_target: Vector3 = _target.global_position - global_position
		_body.rotation.y = atan2(-to_target.x, -to_target.z)

	_reassemble_tween = create_tween().set_parallel()
	for part in _parts:
		var mesh: MeshInstance3D = part["mesh"]
		mesh.reparent(part["pivot"], true)
		_reassemble_tween.tween_property(mesh, "transform", part["rest"], reassemble_time) \
				.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		part["body"] = null
	for child in _ragdoll_root.get_children():
		child.queue_free()
	_collision.disabled = false
	_reassemble_tween.chain().tween_callback(_start.bind(State.WALKING))


## Breaks every joint so the defeated dummy falls apart.
func _fall_apart() -> void:
	_fell_apart = true
	for child in _ragdoll_root.get_children():
		if child is Joint3D:
			child.queue_free()
	for part in _parts:
		var body: RigidBody3D = part["body"]
		if body != null:
			body.linear_velocity += Vector3(randf_range(-1.5, 1.5), randf_range(0.5, 2.0), randf_range(-1.5, 1.5))
			body.angular_velocity += Vector3(randf_range(-4, 4), randf_range(-4, 4), randf_range(-4, 4))
	set_physics_process(false)
	# The timer runs on world time and stops while the game is paused.
	get_tree().create_timer(debris_lifetime, false).timeout.connect(_clear_debris)


## Shrinks the pieces away, then removes the dummy (and any knives stuck in it).
func _clear_debris() -> void:
	var shrink := create_tween().set_parallel()
	for part in _parts:
		shrink.tween_property(part["mesh"], "scale", Vector3.ONE * 0.01, 0.6)
	shrink.chain().tween_callback(queue_free)


func _fit_collision_to_size() -> void:
	# The capsule shape is shared by every dummy, so give this one its own copy.
	var capsule := (_collision.shape as CapsuleShape3D).duplicate() as CapsuleShape3D
	capsule.radius *= size_scale
	capsule.height *= size_scale
	_collision.shape = capsule
	_collision.position.y *= size_scale


func _part_hit_by(collider: Object, point: Vector3) -> Dictionary:
	if collider is RigidBody3D and collider.has_meta("part_name"):
		return _find_part(collider.get_meta("part_name"))
	# Hit the walking dummy's capsule: pick the body part closest to the hit.
	var closest: Dictionary = _parts[0]
	var closest_distance := INF
	for part in _parts:
		var distance := (part["mesh"] as Node3D).global_position.distance_to(point)
		if distance < closest_distance:
			closest = part
			closest_distance = distance
	return closest


func _find_part(part_name: String) -> Dictionary:
	for part in _parts:
		if part["name"] == part_name:
			return part
	return {}


# --- Building the body ---------------------------------------------------------

## The body parts, parents first. "joint" is where a part hangs from its parent,
## "center" is the middle of its box, both measured from the dummy's feet.
func _part_specs() -> Array[Dictionary]:
	var specs: Array[Dictionary] = [
		{"name": "pelvis", "parent": "", "joint": Vector3(0, 0.95, 0), "center": Vector3(0, 0.95, 0),
				"size": Vector3(0.36, 0.2, 0.24), "mass": 6.0, "material": "cloth"},
		{"name": "torso", "parent": "pelvis", "joint": Vector3(0, 1.05, 0), "center": Vector3(0, 1.31, 0),
				"size": Vector3(0.42, 0.52, 0.26), "mass": 8.0, "material": "cloth"},
		{"name": "head", "parent": "torso", "joint": Vector3(0, 1.58, 0), "center": Vector3(0, 1.74, 0),
				"size": Vector3(0.3, 0.3, 0.3), "mass": 3.0, "material": "head"},
	]
	for side in [-1.0, 1.0]:
		var suffix := "_l" if side < 0.0 else "_r"
		specs.append_array([
			{"name": "upper_arm" + suffix, "parent": "torso", "joint": Vector3(0.28 * side, 1.53, 0),
					"center": Vector3(0.28 * side, 1.38, 0), "size": Vector3(0.12, 0.3, 0.12),
					"mass": 1.5, "material": "limb"},
			{"name": "lower_arm" + suffix, "parent": "upper_arm" + suffix, "joint": Vector3(0.28 * side, 1.23, 0),
					"center": Vector3(0.28 * side, 1.07, 0), "size": Vector3(0.11, 0.3, 0.11),
					"mass": 1.2, "material": "limb"},
			{"name": "thigh" + suffix, "parent": "pelvis", "joint": Vector3(0.1 * side, 0.85, 0),
					"center": Vector3(0.1 * side, 0.65, 0), "size": Vector3(0.14, 0.4, 0.14),
					"mass": 2.5, "material": "limb"},
			{"name": "shin" + suffix, "parent": "thigh" + suffix, "joint": Vector3(0.1 * side, 0.45, 0),
					"center": Vector3(0.1 * side, 0.24, 0), "size": Vector3(0.13, 0.42, 0.13),
					"mass": 2.0, "material": "limb"},
		])
	for spec in specs:
		spec["joint"] *= size_scale
		spec["center"] *= size_scale
		spec["size"] *= size_scale
	return specs


func _build_body() -> void:
	var materials := {
		"cloth": _material(cloth_color),
		"limb": _material(cloth_color.darkened(0.14)),
		"head": _material(cloth_color.lightened(0.1)),
	}
	for key in materials:
		_body_materials[materials[key]] = materials[key].albedo_color
	var joints := {}
	for spec in _part_specs():
		var parent_name: String = spec["parent"]
		var parent_pivot: Node3D = _body if parent_name.is_empty() else _pivots[parent_name]
		var parent_joint: Vector3 = Vector3.ZERO if parent_name.is_empty() else joints[parent_name]
		var joint: Vector3 = spec["joint"]
		var center: Vector3 = spec["center"]

		var pivot := Node3D.new()
		pivot.name = String(spec["name"]).to_pascal_case()
		pivot.position = joint - parent_joint
		parent_pivot.add_child(pivot)

		var box := BoxMesh.new()
		box.size = spec["size"]
		box.material = materials[spec["material"]]
		var mesh := MeshInstance3D.new()
		mesh.name = "Mesh"
		mesh.mesh = box
		mesh.position = center - joint
		pivot.add_child(mesh)

		_pivots[spec["name"]] = pivot
		joints[spec["name"]] = joint
		var part := spec.duplicate()
		part["pivot"] = pivot
		part["mesh"] = mesh
		part["rest"] = mesh.transform
		part["body"] = null
		_parts.append(part)

	_add_details()


## The painted target, stitched face and straw hair that make it a training dummy.
func _add_details() -> void:
	var red := _material(Color(0.75, 0.14, 0.12))
	var white := _material(Color(0.92, 0.9, 0.84))
	var stitch := _material(Color(0.2, 0.13, 0.08))
	var straw := _material(Color(0.9, 0.78, 0.36))

	var k := size_scale
	var torso: Node3D = _find_part("torso")["mesh"]
	_add_disc(torso, 0.13 * k, red, Vector3(0, 0.04, -0.133) * k)
	_add_disc(torso, 0.085 * k, white, Vector3(0, 0.04, -0.136) * k)
	_add_disc(torso, 0.04 * k, red, Vector3(0, 0.04, -0.139) * k)

	var head: Node3D = _find_part("head")["mesh"]
	for x in [-0.07, 0.07]:
		# Each eye is an X made of two crossed stitches.
		for tilt in [PI / 4.0, -PI / 4.0]:
			_add_box(head, Vector3(0.09, 0.016, 0.01) * k, stitch, Vector3(x, 0.03, -0.152) * k, tilt)
	_add_box(head, Vector3(0.13, 0.014, 0.01) * k, stitch, Vector3(0, -0.07, -0.152) * k)
	if headgear.is_empty():
		for i in 3:
			var x := (i - 1) * 0.07
			_add_box(head, Vector3(0.04, 0.12, 0.04) * k, straw, Vector3(x, 0.18, 0) * k, x * 2.5)
	else:
		MiniBosses.add_headgear(head, headgear, 0.3 * k, 0.3 * k)

	var pelvis: Node3D = _find_part("pelvis")["mesh"]
	_add_box(pelvis, Vector3(0.38, 0.05, 0.26) * k, stitch, Vector3(0, 0.08, 0) * k)


func _add_box(parent: Node3D, size: Vector3, material: Material, at: Vector3, tilt := 0.0) -> void:
	var box := BoxMesh.new()
	box.size = size
	box.material = material
	var mesh := MeshInstance3D.new()
	mesh.mesh = box
	mesh.transform = Transform3D(Basis(Vector3.BACK, tilt), at)
	parent.add_child(mesh)


## A thin disc facing forward (-Z), for the target on the chest.
func _add_disc(parent: Node3D, radius: float, material: Material, at: Vector3) -> void:
	var disc := CylinderMesh.new()
	disc.top_radius = radius
	disc.bottom_radius = radius
	disc.height = 0.006
	disc.radial_segments = 10
	disc.rings = 0
	disc.material = material
	var mesh := MeshInstance3D.new()
	mesh.mesh = disc
	mesh.transform = Transform3D(Basis(Vector3.RIGHT, PI / 2.0), at)
	parent.add_child(mesh)


func _material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 1.0
	return material
