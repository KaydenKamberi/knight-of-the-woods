extends CharacterBody3D
## A forest animal: a bear, wolf, deer or bunny (PRD H-1 to H-6).
##
## Wild, it ambles around its patch of forest and is peaceful. Hit a bear or a
## wolf and it fights back, chasing the knight for a while; deer and bunnies
## run away. A wild animal that's killed drops meat. Walk up with the right food
## and press E / Grab to tame it (meat for bears and wolves, berries for deer and
## bunnies). The Animals node (animals.gd) keeps track of who is tamed.
##
## Tamed, it wears a green collar, follows the knight and attacks enemies near
## him. Enemies attack it too. A tamed animal that falls comes back next to the
## knight when the wave ends (H-5), and it fights in the wave 20 battle (H-6).
##
## Everything runs on world time. Far from the knight, wild animals think less
## often (F-4). The model is low-poly boxes built in code, facing -Z.

signal health_changed
## Sent when a tamed animal falls (it comes back at the end of the wave).
signal fell(animal: Node)
## Sent when a wild animal is killed (it's gone for good; the forest gets a new one later).
signal killed(animal: Node)

const Config := preload("res://scripts/game_config.gd")
const Art := preload("res://scripts/art.gd")
const Fx := preload("res://scripts/fx.gd")
const LootDrops := preload("res://scripts/loot_drops.gd")
const WORLD_LAYER := 1
const BOUNDARY_LAYER := 4
const DUMMY_LAYER := 8
const ALLY_LAYER := 32
## Wild animals stay this far inside the edge of the map.
const ROAM_RADIUS := 30.0

## "bear", "wolf", "deer" or "bunny". Set before adding the animal to the scene.
var kind := "wolf"
var tamed := false
var health := 0
var max_health := 0
## Used by the knight's melee to judge reach, like an enemy's size.
var size_scale := 1.0

var _stats := {}
var _down := false
var _gone := false
var _home := Vector3.ZERO
var _wander_to := Vector3.ZERO
var _wander_left := 0.0
var _angry_left := 0.0
var _scared_left := 0.0
var _scared_from := Vector3.ZERO
var _target = null
var _knight = null
var _think_left := 0.0
var _cooldown_left := 0.0
var _windup_left := -1.0
var _slow_left := 0.0
var _slow_factor := 1.0
var _knockback := Vector3.ZERO
var _walk_cycle := 0.0
var _slot := 0
## True while it's down in the bunker with the knight (enemies can't target it there).
var _in_bunker := false
var _far := false
var _skipped_delta := 0.0
var _skipped_frames := 0
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

var _model: Node3D
var _legs: Array[Node3D] = []
var _collar: Node3D
var _collision: CollisionShape3D
var _materials := {}


func _ready() -> void:
	_stats = Config.ANIMALS[kind]
	max_health = _stats["health"]
	health = max_health
	_home = global_position
	_wander_to = global_position
	_knight = get_tree().get_first_node_in_group("player")
	_build_model()
	_set_wild_layers()
	add_to_group("wild_animals")
	add_to_group("interactables")
	Graphics.register_shadow_caster(self, false)
	_think_left = randf() * 0.5
	_wander_left = randf_range(1.0, 4.0)


func is_alive() -> bool:
	return not _down and not _gone


func display_name() -> String:
	return _stats["name"]


func health_text() -> String:
	if _down:
		return "%s (resting)" % display_name()
	return "%s %d/%d" % [display_name(), health, max_health]


# --- Taming (used by animals.gd) -------------------------------------------------

## Joins the knight. `slot` (0 or 1) decides which side of him it walks on.
func become_tamed(slot: int) -> void:
	tamed = true
	_slot = slot
	_angry_left = 0.0
	_scared_left = 0.0
	_target = null
	remove_from_group("wild_animals")
	remove_from_group("interactables")
	add_to_group("companions")
	add_to_group("dummy_targets")
	_in_bunker = false
	collision_layer = ALLY_LAYER
	collision_mask = WORLD_LAYER | BOUNDARY_LAYER | DUMMY_LAYER | ALLY_LAYER
	_collar.visible = true
	health = max_health
	health_changed.emit()
	Fx.dust(global_position, true)


func set_slot(slot: int) -> void:
	_slot = slot


## Let go (H-3): it's wild again and wanders off from where it is.
func release() -> void:
	tamed = false
	_target = null
	remove_from_group("companions")
	remove_from_group("dummy_targets")
	_collar.visible = false
	_in_bunker = false
	if _down:
		_revive_at(global_position)
	add_to_group("wild_animals")
	add_to_group("interactables")
	_set_wild_layers()
	_home = global_position
	_wander_left = 0.0


## H-5: a fallen tamed animal comes back next to the knight (or a living one is
## healed). `underground` is whether the knight is in the bunker.
func revive_near(spot: Vector3, underground := false) -> void:
	if _down:
		_in_bunker = underground
		_revive_at(spot + _follow_offset())
	health = max_health
	health_changed.emit()


## The knight went through a bunker entrance: come along. Down in the bunker,
## enemies outside can't target it, just like the knight.
func follow_through(spot: Vector3, underground: bool) -> void:
	if not tamed or _down:
		return
	global_position = spot + _follow_offset()
	velocity = Vector3.ZERO
	_in_bunker = underground
	if underground:
		remove_from_group("dummy_targets")
	else:
		add_to_group("dummy_targets")


# --- Used by the knight's E / Grab while wild -----------------------------------------

func can_be_picked_up() -> bool:
	return not tamed and is_alive() and _angry_left <= 0.0


func pickup_point() -> Vector3:
	return global_position + Vector3.UP * 0.5


func pickup_range() -> float:
	return Config.TAME_RANGE


func pickup_prompt() -> String:
	var food: String = _stats["food"]
	var inventory = get_tree().get_first_node_in_group("inventory")
	var have: int = 0 if inventory == null else inventory.materials.get(food, 0)
	var food_name := String(Config.MATERIAL_NAMES[food]).to_lower()
	if have <= 0:
		return "%s eats %s (you have none)" % [display_name(), food_name]
	return "Tame the %s (1 %s)" % [display_name().to_lower(), food_name]


func pickup_button() -> String:
	return "TAME"


func interact() -> void:
	var animals = get_tree().get_first_node_in_group("animals")
	if animals != null:
		animals.try_tame(self)


# --- Getting hurt ---------------------------------------------------------------

## Hit by an enemy (tamed animals only; enemies never go for wild ones).
func take_damage(amount: int, _from: Vector3, _attacker = null) -> void:
	_hurt(amount)


## Hit by the knight's melee (wild animals only).
func take_hit(damage: int, from: Vector3, push := 3.0, _knockdown := true) -> void:
	var away := global_position - from
	away.y = 0.0
	if away.length_squared() > 0.0001:
		_knockback = away.normalized() * push
	_hurt(damage)
	if is_alive() and not tamed:
		_provoke(from)


## Hit by a knife, arrow or musket ball (wild animals only). Returns what it sticks in.
func take_projectile_hit(_collider: Object, point: Vector3, direction: Vector3, damage: int, push: float) -> Node3D:
	take_hit(damage, point - direction, push)
	return _model


## Cryo armour hits a wild attacker back and slows it (R-10).
func apply_slow(factor: float, seconds: float) -> void:
	_slow_factor = factor
	_slow_left = maxf(_slow_left, seconds)


func apply_knockback(push: Vector3) -> void:
	_knockback = Vector3(push.x, 0.0, push.z)


func _hurt(amount: int) -> void:
	if not is_alive():
		return
	health = maxi(health - amount, 0)
	Art.flash(_materials.values(), self)
	Fx.hit_sparks(global_position + Vector3.UP * 0.6)
	health_changed.emit()
	if health == 0:
		if tamed:
			_fall()
		else:
			_die()


## H-1: bears and wolves fight back; deer and bunnies run.
func _provoke(from: Vector3) -> void:
	if kind == "bear" or kind == "wolf":
		_angry_left = Config.ANIMAL_ANGRY_TIME
	else:
		_scared_left = 4.0
		_scared_from = from


## A tamed animal falls: it lies down and fades, and waits for the wave to end.
func _fall() -> void:
	_down = true
	_windup_left = -1.0
	remove_from_group("dummy_targets")
	_collision.set_deferred("disabled", true)
	var topple := create_tween()
	topple.tween_property(_model, "rotation:z", PI * 0.5, 0.4)
	topple.tween_interval(1.2)
	topple.tween_property(_model, "scale", Vector3.ONE * 0.01, 0.5)
	topple.tween_callback(hide)
	fell.emit(self)


func _revive_at(spot: Vector3) -> void:
	_down = false
	global_position = spot
	velocity = Vector3.ZERO
	visible = true
	_model.rotation = Vector3.ZERO
	_model.scale = Vector3.ONE
	_collision.disabled = false
	if tamed and not _in_bunker:
		add_to_group("dummy_targets")
	Fx.dust(spot, true)


## A wild animal is killed: it drops meat and is gone.
func _die() -> void:
	_gone = true
	remove_from_group("wild_animals")
	remove_from_group("interactables")
	_collision.set_deferred("disabled", true)
	LootDrops.drop_items(self, {"meat": 1})
	killed.emit(self)
	var topple := create_tween()
	topple.tween_property(_model, "rotation:z", PI * 0.5, 0.4)
	topple.tween_interval(1.5)
	topple.tween_property(_model, "scale", Vector3.ONE * 0.01, 0.6)
	topple.tween_callback(queue_free)


# --- Thinking and moving -------------------------------------------------------------

func _physics_process(delta: float) -> void:
	if not is_alive():
		return
	# F-4: a wild animal far from the knight thinks every few frames.
	if not tamed and _far:
		_skipped_delta += delta
		_skipped_frames += 1
		if _skipped_frames < Config.FAR_AI_FRAME_SKIP:
			return
		delta = _skipped_delta
		_skipped_delta = 0.0
		_skipped_frames = 0
	_slow_left = maxf(_slow_left - delta, 0.0)
	var action_delta := delta * (_slow_factor if _slow_left > 0.0 else 1.0)
	_cooldown_left = maxf(_cooldown_left - action_delta, 0.0)
	_angry_left = maxf(_angry_left - delta, 0.0)
	_scared_left = maxf(_scared_left - delta, 0.0)
	_think_left -= delta
	if _think_left <= 0.0:
		_think()

	var desired := Vector3.ZERO
	var speed: float = _stats["speed"]
	if _windup_left >= 0.0:
		_windup_left -= action_delta
		_model.rotation.x = -0.25
		if _windup_left < 0.0:
			_release_attack()
	elif _is_fighting():
		var to_target: Vector3 = _target.global_position - global_position
		to_target.y = 0.0
		var distance := to_target.length()
		var reach: float = _stats["range"]
		if distance > reach * 0.85:
			desired = to_target / maxf(distance, 0.001)
			if kind == "deer" and distance < Config.DEER_CHARGE_DISTANCE:
				speed *= Config.DEER_CHARGE_SPEED
		elif _cooldown_left == 0.0:
			_windup_left = _stats["windup"]
			_cooldown_left = _stats["cooldown"]
		_face(to_target)
	elif tamed:
		desired = _follow_direction()
	elif _scared_left > 0.0:
		desired = global_position - _scared_from
		desired.y = 0.0
		desired = desired.normalized()
	else:
		desired = _wander(delta)
		speed = Config.WILD_WANDER_SPEED
	if _windup_left < 0.0:
		_model.rotation.x = lerpf(_model.rotation.x, 0.0, 10.0 * delta)
	if desired != Vector3.ZERO:
		_face(desired)

	speed *= _slow_factor if _slow_left > 0.0 else 1.0
	velocity.x = desired.x * speed + _knockback.x
	velocity.z = desired.z * speed + _knockback.z
	_knockback = _knockback.move_toward(Vector3.ZERO, 25.0 * delta)
	if is_on_floor():
		velocity.y = 0.0
	else:
		velocity.y -= _gravity * delta
	move_and_slide()
	_animate(delta, speed)


func _think() -> void:
	_think_left = 0.25 if tamed else 0.5
	if _knight != null:
		_far = global_position.distance_to(_knight.global_position) > Config.FAR_AI_DISTANCE
	_target = null
	if tamed:
		_target = _nearest_enemy()
	elif _angry_left > 0.0 and _knight != null and _knight.is_alive() and not _knight.in_bunker:
		_target = _knight


func _is_fighting() -> bool:
	return is_instance_valid(_target) and _target.is_alive()


## Tamed: the nearest enemy close to the knight, or null.
func _nearest_enemy():
	if _knight == null:
		return null
	var best = null
	var best_distance := INF
	var enemies: Array = get_tree().get_nodes_in_group("dummies")
	for enemy in enemies:
		if not enemy.is_alive():
			continue
		if enemy.global_position.distance_to(_knight.global_position) > Config.ANIMAL_GUARD_RANGE:
			continue
		var distance: float = global_position.distance_squared_to(enemy.global_position)
		if distance < best_distance:
			best = enemy
			best_distance = distance
	return best


func _release_attack() -> void:
	_model.rotation.x = 0.2
	if not _is_fighting():
		return
	var reach: float = _stats["range"] + 0.6
	if global_position.distance_to(_target.global_position) > reach:
		return
	var damage: int = _stats["damage"]
	if tamed:
		_target.take_hit(damage, global_position, 3.0)
	else:
		_target.take_damage(maxi(roundi(damage * Config.WILD_DAMAGE_SHARE), 1), global_position, self)


## Tamed: walk back to the knight's side when he gets too far away.
func _follow_direction() -> Vector3:
	if _knight == null:
		return Vector3.ZERO
	var spot: Vector3 = _knight.global_position + _follow_offset()
	var to_spot := spot - global_position
	to_spot.y = 0.0
	if to_spot.length() < 1.0:
		return Vector3.ZERO
	if global_position.distance_to(_knight.global_position) < Config.ANIMAL_FOLLOW_DISTANCE and to_spot.length() < 2.5:
		return Vector3.ZERO
	return to_spot.normalized()


## Where by the knight this animal walks: one on each side, a little behind.
func _follow_offset() -> Vector3:
	return Vector3(1.6 if _slot == 0 else -1.6, 0.0, 1.2)


## Wild: amble to a nearby spot, rest a while, pick another.
func _wander(delta: float) -> Vector3:
	_wander_left -= delta
	if _wander_left <= 0.0:
		_wander_left = randf_range(3.0, 7.0)
		var angle := randf() * TAU
		var spot := _home + Vector3(cos(angle), 0.0, sin(angle)) * randf_range(1.0, 6.0)
		if Vector2(spot.x, spot.z).length() > ROAM_RADIUS:
			spot = _home
		_wander_to = spot
	var to_spot := _wander_to - global_position
	to_spot.y = 0.0
	if to_spot.length() < 0.4 or _wander_left < 1.5:
		return Vector3.ZERO
	return to_spot.normalized()


func _face(direction: Vector3) -> void:
	if direction.length_squared() < 0.001:
		return
	_model.rotation.y = lerp_angle(_model.rotation.y, atan2(-direction.x, -direction.z), 0.3)


func _animate(delta: float, speed: float) -> void:
	var moving := Vector2(velocity.x, velocity.z).length()
	var amount := clampf(moving / maxf(speed, 0.1), 0.0, 1.0)
	_walk_cycle = fmod(_walk_cycle + delta * (8.0 + speed) * amount, TAU)
	if kind == "bunny":
		# Bunnies hop.
		_model.position.y = absf(sin(_walk_cycle)) * 0.18 * amount
		return
	for i in _legs.size():
		var phase := 0.0 if i == 0 or i == 3 else PI
		_legs[i].rotation.x = sin(_walk_cycle + phase) * 0.6 * amount


func _set_wild_layers() -> void:
	# Wild animals are on the enemies' layer, so the knight's knives, arrows and
	# musket balls can hit them; tamed ones are allies, which those fly through.
	collision_layer = DUMMY_LAYER
	collision_mask = WORLD_LAYER | BOUNDARY_LAYER | DUMMY_LAYER | ALLY_LAYER


# --- The model ---------------------------------------------------------------------------

func _build_model() -> void:
	_model = Node3D.new()
	_model.name = "Model"
	add_child(_model)
	var shape := BoxShape3D.new()
	match kind:
		"bear":
			_build_bear()
			shape.size = Vector3(0.8, 1.2, 1.5)
		"wolf":
			_build_wolf()
			shape.size = Vector3(0.45, 0.9, 1.2)
		"deer":
			_build_deer()
			shape.size = Vector3(0.45, 1.5, 1.1)
		_:
			_build_bunny()
			shape.size = Vector3(0.3, 0.45, 0.45)
			size_scale = 0.6
	_collision = CollisionShape3D.new()
	_collision.shape = shape
	_collision.position.y = shape.size.y * 0.5
	add_child(_collision)
	_build_collar()


func _build_bear() -> void:
	var fur := Color(0.42, 0.28, 0.18)
	_part(_model, Vector3(0.75, 0.7, 1.25), fur, Vector3(0, 0.78, 0))
	_part(_model, Vector3(0.5, 0.46, 0.46), fur, Vector3(0, 1.02, -0.76))
	_part(_model, Vector3(0.26, 0.2, 0.22), fur.lightened(0.3), Vector3(0, 0.92, -1.04))
	_part(_model, Vector3(0.1, 0.07, 0.05), Color(0.08, 0.06, 0.05), Vector3(0, 0.98, -1.15))
	for x in [-0.17, 0.17]:
		_part(_model, Vector3(0.13, 0.13, 0.08), fur.darkened(0.15), Vector3(x, 1.28, -0.72))
		_part(_model, Vector3(0.05, 0.05, 0.02), Color(0.05, 0.04, 0.04), Vector3(x * 0.7, 1.1, -0.995))
	_add_legs(fur.darkened(0.1), Vector3(0.24, 0.5, 0.26), 0.25, 0.42, 0.52)


func _build_wolf() -> void:
	var fur := Color(0.56, 0.57, 0.6)
	_part(_model, Vector3(0.36, 0.38, 0.95), fur, Vector3(0, 0.64, 0))
	_part(_model, Vector3(0.3, 0.12, 0.85), fur.lightened(0.25), Vector3(0, 0.47, 0))
	_part(_model, Vector3(0.3, 0.28, 0.32), fur, Vector3(0, 0.84, -0.6))
	_part(_model, Vector3(0.15, 0.13, 0.22), fur.lightened(0.15), Vector3(0, 0.78, -0.82))
	_part(_model, Vector3(0.06, 0.05, 0.04), Color(0.08, 0.06, 0.05), Vector3(0, 0.82, -0.94))
	for x in [-0.09, 0.09]:
		_part(_model, Vector3(0.08, 0.15, 0.05), fur.darkened(0.2), Vector3(x, 1.03, -0.56))
		_part(_model, Vector3(0.04, 0.04, 0.02), Color(0.9, 0.75, 0.2), Vector3(x * 0.8, 0.9, -0.765))
	_part(_model, Vector3(0.1, 0.1, 0.46), fur.darkened(0.1), Vector3(0, 0.74, 0.64), Vector3(0.5, 0, 0))
	_add_legs(fur.darkened(0.08), Vector3(0.1, 0.46, 0.1), 0.13, 0.35, 0.46)


func _build_deer() -> void:
	var coat := Color(0.66, 0.47, 0.3)
	_part(_model, Vector3(0.38, 0.42, 0.95), coat, Vector3(0, 0.98, 0))
	_part(_model, Vector3(0.16, 0.48, 0.18), coat, Vector3(0, 1.33, -0.46), Vector3(-0.45, 0, 0))
	_part(_model, Vector3(0.2, 0.22, 0.36), coat, Vector3(0, 1.58, -0.62))
	_part(_model, Vector3(0.06, 0.05, 0.04), Color(0.08, 0.06, 0.05), Vector3(0, 1.56, -0.81))
	_part(_model, Vector3(0.12, 0.12, 0.06), Color(0.95, 0.93, 0.88), Vector3(0, 1.05, 0.5))
	var antler := Color(0.85, 0.78, 0.62)
	for side in [-1.0, 1.0]:
		_part(_model, Vector3(0.04, 0.3, 0.04), antler, Vector3(0.08 * side, 1.8, -0.58), Vector3(0, 0, -0.35 * side))
		_part(_model, Vector3(0.04, 0.16, 0.04), antler, Vector3(0.15 * side, 1.86, -0.66), Vector3(0.6, 0, -0.6 * side))
		_part(_model, Vector3(0.09, 0.12, 0.04), coat.darkened(0.15), Vector3(0.12 * side, 1.7, -0.54), Vector3(0, 0, -0.8 * side))
	_add_legs(coat.darkened(0.12), Vector3(0.09, 0.78, 0.09), 0.13, 0.35, 0.78)


func _build_bunny() -> void:
	var fur := Color(0.86, 0.84, 0.8)
	_part(_model, Vector3(0.26, 0.26, 0.36), fur, Vector3(0, 0.2, 0))
	_part(_model, Vector3(0.2, 0.2, 0.2), fur, Vector3(0, 0.34, -0.18))
	for x in [-0.05, 0.05]:
		_part(_model, Vector3(0.06, 0.22, 0.04), fur, Vector3(x, 0.53, -0.16), Vector3(0.15, 0, x * 2.0))
		_part(_model, Vector3(0.03, 0.12, 0.01), Color(0.95, 0.7, 0.72), Vector3(x, 0.53, -0.18), Vector3(0.15, 0, x * 2.0))
		_part(_model, Vector3(0.03, 0.03, 0.02), Color(0.08, 0.06, 0.05), Vector3(x * 1.5, 0.37, -0.285))
		_part(_model, Vector3(0.07, 0.06, 0.16), fur.darkened(0.08), Vector3(x * 1.8, 0.04, 0.04))
	_part(_model, Vector3(0.1, 0.1, 0.08), Color.WHITE, Vector3(0, 0.24, 0.2))


## Four legs on pivots at the hips and shoulders, so they can swing.
func _add_legs(color: Color, size: Vector3, side: float, front_back: float, hip_height: float) -> void:
	for corner in [Vector3(-side, 0, -front_back), Vector3(side, 0, -front_back),
			Vector3(-side, 0, front_back), Vector3(side, 0, front_back)]:
		var leg := Node3D.new()
		leg.position = corner + Vector3(0, hip_height, 0)
		_model.add_child(leg)
		_part(leg, size, color, Vector3(0, -size.y * 0.5, 0))
		_legs.append(leg)


## A green-and-gold collar (the knight's colours), shown once tamed.
func _build_collar() -> void:
	_collar = Node3D.new()
	_collar.name = "Collar"
	_collar.visible = false
	_model.add_child(_collar)
	var green: Color = Config.PALETTE["knight_green"]
	var gold: Color = Config.PALETTE["knight_gold"]
	match kind:
		"bear":
			_part(_collar, Vector3(0.54, 0.1, 0.12), green, Vector3(0, 0.98, -0.52))
			_part(_collar, Vector3(0.1, 0.1, 0.04), gold, Vector3(0, 0.88, -0.6))
		"wolf":
			_part(_collar, Vector3(0.32, 0.08, 0.1), green, Vector3(0, 0.76, -0.43))
			_part(_collar, Vector3(0.07, 0.07, 0.03), gold, Vector3(0, 0.69, -0.49))
		"deer":
			_part(_collar, Vector3(0.2, 0.08, 0.2), green, Vector3(0, 1.38, -0.5))
			_part(_collar, Vector3(0.07, 0.07, 0.03), gold, Vector3(0, 1.32, -0.61))
		_:
			_part(_collar, Vector3(0.18, 0.05, 0.12), green, Vector3(0, 0.25, -0.12))
			_part(_collar, Vector3(0.05, 0.05, 0.02), gold, Vector3(0, 0.22, -0.19))


func _part(parent: Node3D, size: Vector3, color: Color, at: Vector3, turn := Vector3.ZERO) -> void:
	var key := color.to_html()
	if not _materials.has(key):
		_materials[key] = Art.material(color, {"rim": true, "unique": true})
	var box := BoxMesh.new()
	box.size = size
	box.material = _materials[key]
	var mesh := MeshInstance3D.new()
	mesh.mesh = box
	mesh.transform = Transform3D(Basis.from_euler(turn), at)
	if size.length() < 0.15:
		mesh.visibility_range_end = Config.LOD_DETAIL_DISTANCE
	parent.add_child(mesh)
