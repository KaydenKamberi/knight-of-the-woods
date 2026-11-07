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
## The big boss of wave 20 (M6) uses this script too, set up by
## configure_big_boss(): much bigger, glowing eyes, goes only for the knight,
## and has two attacks with wind-up warnings: a heavy two-armed swing, and a
## ground stomp that knocks everyone nearby back (a red ring grows on the ground
## before it lands). It never staggers, and the Cryo dagger can't shatter its head.
##
## Regular enemies (Update 2, D-1) come in four looks: bandits, archers,
## swordsmen and horseback riders, set by `look` before the enemy is added. They
## all fight exactly like the version 1 dummies. Riders sit on a horse that stays
## put while the rider is knocked off, and trots away when the rider is beaten.
## Bandits steal (D-2 to D-5): the first time one touches the knight it takes 5
## random materials, shows "Stolen!", gets a sack and a THIEF marker, and runs
## for the nearest edge of the map. Killing it drops everything it took;
## reaching the edge means the materials are gone for good. One theft each.
##
## Crafted weapons (M5.5) can also freeze a dummy solid (hammer slam), freeze
## its head (Cryo dagger) so the next dagger hit shatters it, or slow it (Cryo
## armour). A defeated dummy drops loot.

## Sent once, when the dummy's health reaches zero (or a bandit gets away).
signal defeated
signal health_changed(health: int, max_health: int)

enum State { WALKING, ATTACKING, STOMPING, RAGDOLL, REASSEMBLING, DEFEATED }

## Physics layer values (see Project Settings > Layer Names > 3D Physics).
const WORLD_LAYER := 1
const DEBRIS_LAYER := 16
const MiniBosses := preload("res://scripts/mini_bosses.gd")
const Config := preload("res://scripts/game_config.gd")
const LootDrops := preload("res://scripts/loot_drops.gd")
const Effects := preload("res://scripts/effects.gd")
const Art := preload("res://scripts/art.gd")
const Fx := preload("res://scripts/fx.gd")

## Every defeated dummy whose pieces are still lying around, oldest first. When
## there are more than the graphics setting allows, the oldest are cleared.
static var _fallen: Array = []
const ICE_COLOR := Color(0.6, 0.85, 1.0)
## How far a rider sits above where a dummy on foot would stand.
const RIDER_LIFT := 0.55

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
## "" (a plain training dummy, as mini bosses are), or one of the regular enemy
## looks: "bandit", "archer", "swordsman" or "rider" (D-1).
@export var look := ""
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
var is_big_boss := false
var boss_name := ""
## The wave a mini boss belongs to (grenades take 1 / (wave × 2) of its health, G-3).
var boss_wave := 0
## True if this was a bandit that reached the edge of the map with its loot (D-4).
var escaped := false

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
var _stomp_cooldown_left := 0.0
var _stomp_ring: MeshInstance3D
var _frost: Node3D
# F-4: far from the knight, the dummy only thinks every few physics frames.
var _far_check_left := 0.0
var _is_far := false
var _skipped_delta := 0.0
var _skipped_frames := 0
var _cleared := false
## The cloth materials and their normal colours, so freezing can tint them icy and back.
var _body_materials := {}
# Riders: the horse and its leg pivots.
var _horse: Node3D
var _horse_legs: Array[Node3D] = []
# Bandits: what was stolen, and whether it's running away with it.
var _stolen := {}
var _has_stolen := false
var _fleeing := false
var _thief_marker: Label3D

@onready var _body: Node3D = $Body
@onready var _collision: CollisionShape3D = $Collision
## Holds the ragdoll's rigid bodies and joints. It's top level, so moving the dummy doesn't drag them.
@onready var _ragdoll_root: Node3D = $Ragdoll


func _ready() -> void:
	if not is_boss() and Config.ENEMY_LOOK_COLORS.has(look):
		cloth_color = Config.ENEMY_LOOK_COLORS[look]
	health = max_health
	add_to_group("dummies")
	_fit_collision_to_size()
	_build_body()
	# Bosses keep their shadow on Medium; regular dummies only cast one on High.
	Graphics.register_shadow_caster(self, is_boss())


## Turns this dummy into the given wave's mini boss. Call before adding it to the scene.
func configure_mini_boss(info: Dictionary) -> void:
	is_mini_boss = true
	boss_name = info["name"]
	boss_wave = info.get("wave", 1)
	size_scale = info["size"]
	cloth_color = info["color"]
	headgear = info["headgear"]
	max_health = info["health"]
	attack_damage = info["damage"]
	walk_speed = info["walk_speed"]
	attack_range *= size_scale
	attack_windup = 0.7
	ragdoll_on_hit = false


## Turns this dummy into the big boss of wave 20. Call before adding it to the scene.
func configure_big_boss(info: Dictionary) -> void:
	configure_mini_boss(info)
	is_big_boss = true
	attack_windup = Config.BIG_BOSS_SWING_WINDUP
	_stomp_cooldown_left = Config.BIG_BOSS_STOMP_COOLDOWN * 0.5


## Mini bosses and the big boss: they flinch instead of going ragdoll, and the
## hammer slam and dagger never shatter them outright.
func is_boss() -> bool:
	return is_mini_boss or is_big_boss


func _physics_process(delta: float) -> void:
	# F-4: a walking dummy far from the knight thinks every FAR_AI_FRAME_SKIP frames,
	# catching up on the time it skipped (so it still follows world time). It keeps
	# moving every frame so it doesn't stutter.
	_far_check_left -= delta
	if _far_check_left <= 0.0:
		_far_check_left = 0.5
		_is_far = _far_from_knight()
	if _is_far and state == State.WALKING and _frozen_left <= 0.0:
		_skipped_delta += delta
		_skipped_frames += 1
		if _skipped_frames < Config.FAR_AI_FRAME_SKIP:
			move_and_slide()
			return
		delta = _skipped_delta
		_skipped_delta = 0.0
		_skipped_frames = 0
	_slow_left = maxf(_slow_left - delta, 0.0)
	if _frozen_left > 0.0:
		# Frozen solid: no walking or swinging until it thaws.
		_frozen_left -= delta
		if _frozen_left <= 0.0:
			_set_ice_tint(false)
			_stop_frost()
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
		State.STOMPING:
			_stomp(action_delta)
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
	if not is_instance_valid(_frost):
		_frost = Fx.frost_on(_body, size_scale)


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
	Fx.ice_shatter(_head_ice.global_position, size_scale)
	_head_ice.queue_free()
	_head_ice = null
	if is_big_boss:
		take_hit(Config.BIG_BOSS_HEAD_SHATTER_DAMAGE, from)
		return
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
		# Sparks where it was hit, and a short white flash.
		var mesh: Node3D = part["mesh"]
		Fx.hit_sparks(mesh.global_position - direction * 0.2 * size_scale)
		Art.flash(_body_materials.keys(), self)
		health = maxi(health - damage, 0)
		health_changed.emit(health, max_health)
		if health == 0:
			if state != State.RAGDOLL:
				_go_ragdoll()
			_start(State.DEFEATED)
			remove_from_group("dummies")
			_set_ice_tint(false)
			_stop_frost()
			LootDrops.drop_from(self, is_mini_boss)
			if not _stolen.is_empty():
				# D-3: a killed thief drops everything it stole.
				LootDrops.drop_items(self, _stolen)
				_stolen.clear()
			if is_instance_valid(_thief_marker):
				_thief_marker.queue_free()
			_send_horse_away()
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
	if _fleeing:
		_flee(delta)
		return
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
	_stomp_cooldown_left = maxf(_stomp_cooldown_left - delta, 0.0)
	if has_target and distance <= attack_range:
		# D-2: a bandit that touches the knight steals instead of swinging.
		if look == "bandit" and not _has_stolen and _target.is_in_group("player") and _steal():
			return
		_start(State.ATTACKING)
	elif is_big_boss and has_target and _stomp_cooldown_left == 0.0 \
			and distance <= Config.BIG_BOSS_STOMP_RADIUS * 0.8:
		_start_stomp()


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
## The big boss just rocks; it never stops.
func _flinch() -> void:
	if _flinch_tween:
		_flinch_tween.kill()
	if not is_big_boss:
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
	if is_big_boss:
		# The big boss only ever goes for the knight.
		var knight = get_tree().get_first_node_in_group("player")
		if _is_good_target(knight):
			_target = knight
		return
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
	for material in _body_materials:
		var normal: Color = _body_materials[material]
		Art.set_color(material, normal.lerp(ICE_COLOR, 0.65) if frozen else normal)


func _stop_frost() -> void:
	if is_instance_valid(_frost):
		_frost.queue_free()
	_frost = null


## True when the knight is far enough away for the simpler AI (never for the big boss).
func _far_from_knight() -> bool:
	if is_big_boss:
		return false
	var knight := get_tree().get_first_node_in_group("player") as Node3D
	return knight != null and global_position.distance_to(knight.global_position) > Config.FAR_AI_DISTANCE


## Only the living, and only those enemies may go for (not the knight while
## he's down in the secret bunker, which takes him out of "dummy_targets").
func _is_good_target(candidate) -> bool:
	return is_instance_valid(candidate) and candidate.is_alive() and candidate.is_in_group("dummy_targets")


# --- The big boss's ground stomp ------------------------------------------------

func _start_stomp() -> void:
	_start(State.STOMPING)
	velocity = Vector3.ZERO
	# The warning: a red ring on the ground, growing to the stomp's full size.
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.9, 0.1, 0.05, 0.35)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var disc := CylinderMesh.new()
	disc.top_radius = Config.BIG_BOSS_STOMP_RADIUS
	disc.bottom_radius = Config.BIG_BOSS_STOMP_RADIUS
	disc.height = 0.02
	disc.radial_segments = 24
	disc.rings = 0
	disc.material = material
	_stomp_ring = MeshInstance3D.new()
	_stomp_ring.mesh = disc
	_stomp_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	get_tree().current_scene.add_child(_stomp_ring)
	_stomp_ring.global_position = Vector3(global_position.x, 0.03, global_position.z)
	_stomp_ring.scale = Vector3(0.2, 1.0, 0.2)
	var grow := _stomp_ring.create_tween()
	grow.tween_property(_stomp_ring, "scale", Vector3.ONE, Config.BIG_BOSS_STOMP_WINDUP)


func _stomp(delta: float) -> void:
	_apply_gravity(delta)
	move_and_slide()
	var windup := Config.BIG_BOSS_STOMP_WINDUP
	if _state_time < windup:
		# Wind-up: lift a leg high and lean back.
		var lift := clampf(_state_time / windup, 0.0, 1.0)
		_pivots["thigh_r"].rotation.x = lift * 1.4
		_pivots["shin_r"].rotation.x = -lift * 1.2
		_body.rotation.x = lift * 0.15
		return
	if not _swung:
		_swung = true
		_pivots["thigh_r"].rotation.x = 0.0
		_pivots["shin_r"].rotation.x = 0.0
		_body.rotation.x = 0.0
		_land_stomp()
	if _state_time >= windup + 0.6:
		_stomp_cooldown_left = Config.BIG_BOSS_STOMP_COOLDOWN
		_start(State.WALKING)


## The stomp lands: everyone in the ring is hurt and knocked away.
func _land_stomp() -> void:
	if is_instance_valid(_stomp_ring):
		_stomp_ring.queue_free()
	var center := global_position
	Effects.burst(center + Vector3.UP * 0.3, Config.BIG_BOSS_STOMP_RADIUS, Color(0.6, 0.5, 0.4), get_tree().current_scene)
	var targets: Array = get_tree().get_nodes_in_group("dummy_targets")
	for target in targets:
		if not target.is_alive():
			continue
		var away: Vector3 = target.global_position - center
		away.y = 0.0
		if away.length() > Config.BIG_BOSS_STOMP_RADIUS:
			continue
		target.take_damage(Config.BIG_BOSS_STOMP_DAMAGE, center, self)
		if target.has_method("apply_knockback"):
			var push := away.normalized() if away.length_squared() > 0.01 else Vector3.FORWARD
			target.apply_knockback(push * Config.BIG_BOSS_STOMP_KNOCKBACK)


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
	if is_instance_valid(_horse):
		# A rider sits still in the saddle while the horse's legs do the walking.
		for side in ["_l", "_r"]:
			_pivots["thigh" + side].rotation.x = 1.3
			_pivots["shin" + side].rotation.x = -1.3
		for i in _horse_legs.size():
			var phase := 0.0 if i == 0 or i == 3 else PI
			_horse_legs[i].rotation.x = sin(_walk_cycle + phase) * 0.6 * amount
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
	if is_instance_valid(_stomp_ring):
		_stomp_ring.queue_free()
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
	# A rider climbs back onto its horse, which stayed where it was.
	if not is_instance_valid(_horse):
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
	# How long the pieces stay, and how many fallen dummies at once, come from the
	# graphics setting. The timer runs on world time and stops while paused.
	var lifetime: float = Graphics.setting("debris_lifetime", debris_lifetime)
	get_tree().create_timer(lifetime, false).timeout.connect(_clear_debris)
	_fallen = _fallen.filter(func(other) -> bool: return is_instance_valid(other) and not other._cleared)
	_fallen.append(self)
	var keep: int = Graphics.setting("ragdolls_kept", 20)
	while _fallen.size() > keep:
		var oldest = _fallen.pop_front()
		if is_instance_valid(oldest):
			oldest._clear_debris()


## Shrinks the pieces away, then removes the dummy (and any knives stuck in it).
func _clear_debris() -> void:
	if _cleared:
		return
	_cleared = true
	var shrink := create_tween().set_parallel()
	for part in _parts:
		shrink.tween_property(part["mesh"], "scale", Vector3.ONE * 0.01, 0.6)
	shrink.chain().tween_callback(queue_free)


func _fit_collision_to_size() -> void:
	# The capsule shape is shared by every dummy, so give this one its own copy.
	var capsule := (_collision.shape as CapsuleShape3D).duplicate() as CapsuleShape3D
	# A rider on its horse is taller and wider.
	var rider_grow := 1.4 if look == "rider" else 1.0
	capsule.radius *= size_scale * rider_grow
	capsule.height *= size_scale * rider_grow
	_collision.shape = capsule
	_collision.position.y *= size_scale * rider_grow


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
	if look == "rider":
		# Sitting on a horse: everything is lifted, with the legs either side of it.
		for spec in specs:
			var lift := Vector3(0, RIDER_LIFT, 0)
			spec["joint"] += lift
			spec["center"] += lift
			if String(spec["name"]).begins_with("thigh") or String(spec["name"]).begins_with("shin"):
				var joint: Vector3 = spec["joint"]
				var center: Vector3 = spec["center"]
				spec["joint"] = Vector3(joint.x * 2.6, joint.y, joint.z)
				spec["center"] = Vector3(center.x * 2.6, center.y, center.z)
	for spec in specs:
		spec["joint"] *= size_scale
		spec["center"] *= size_scale
		spec["size"] *= size_scale
	return specs


func _build_body() -> void:
	# Each dummy has its own body materials, so it can flash white or turn icy alone.
	var materials := {
		"cloth": _body_material(cloth_color),
		"limb": _body_material(cloth_color.darkened(0.14)),
		"head": _body_material(cloth_color.lightened(0.1)),
	}
	for key in materials:
		_body_materials[materials[key]] = Art.get_color(materials[key])
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
	if look.is_empty():
		_add_disc(torso, 0.13 * k, red, Vector3(0, 0.04, -0.133) * k)
		_add_disc(torso, 0.085 * k, white, Vector3(0, 0.04, -0.136) * k)
		_add_disc(torso, 0.04 * k, red, Vector3(0, 0.04, -0.139) * k)

	var head: Node3D = _find_part("head")["mesh"]
	for x in [-0.07, 0.07]:
		# Each eye is an X made of two crossed stitches.
		for tilt in [PI / 4.0, -PI / 4.0]:
			_add_box(head, Vector3(0.09, 0.016, 0.01) * k, stitch, Vector3(x, 0.03, -0.152) * k, tilt)
	_add_box(head, Vector3(0.13, 0.014, 0.01) * k, stitch, Vector3(0, -0.07, -0.152) * k)
	if not look.is_empty():
		_add_look_details(head, torso)
	elif headgear.is_empty():
		for i in 3:
			var x := (i - 1) * 0.07
			_add_box(head, Vector3(0.04, 0.12, 0.04) * k, straw, Vector3(x, 0.18, 0) * k, x * 2.5)
	else:
		MiniBosses.add_headgear(head, headgear, 0.3 * k, 0.3 * k)
	if is_big_boss:
		# Glowing red eyes behind the stitches.
		var glow := Art.material(Color(1.0, 0.2, 0.1), {"emission": Color(1.0, 0.15, 0.05), "energy": 3.0})
		for x in [-0.07, 0.07]:
			_add_box(head, Vector3(0.06, 0.05, 0.01) * k, glow, Vector3(x, 0.03, -0.151) * k)

	var pelvis: Node3D = _find_part("pelvis")["mesh"]
	_add_box(pelvis, Vector3(0.38, 0.05, 0.26) * k, stitch, Vector3(0, 0.08, 0) * k)


## The clothes and gear that make each regular enemy look (D-1). Everything
## hangs off a body part, so it falls with the ragdoll.
func _add_look_details(head: Node3D, torso: Node3D) -> void:
	var k := size_scale
	var steel := _material(Color(0.62, 0.65, 0.7))
	var leather := _material(Color(0.36, 0.24, 0.14))
	var pelvis: Node3D = _find_part("pelvis")["mesh"]
	match look:
		"bandit":
			# A dark hood and a red bandana over the mouth, with a knife at the belt.
			var hood := _material(cloth_color.darkened(0.25))
			_add_piece(head, Vector3(0.34, 0.12, 0.34) * k, hood, Vector3(0, 0.17, 0.01) * k)
			_add_piece(head, Vector3(0.34, 0.3, 0.06) * k, hood, Vector3(0, 0.0, 0.17) * k)
			for x in [-0.17, 0.17]:
				_add_piece(head, Vector3(0.04, 0.3, 0.32) * k, hood, Vector3(x, 0.0, 0.0) * k)
			_add_piece(head, Vector3(0.32, 0.11, 0.03) * k, _material(Color(0.72, 0.15, 0.12)), Vector3(0, -0.08, -0.155) * k)
			_add_piece(pelvis, Vector3(0.04, 0.2, 0.04) * k, steel, Vector3(0.2, -0.04, -0.1) * k, Vector3(0, 0, 0.3))
		"archer":
			# A pointed green cap with a red feather, a quiver of arrows and a bow on the back.
			var cap := _material(cloth_color.darkened(0.2))
			_add_piece(head, Vector3(0.33, 0.1, 0.33) * k, cap, Vector3(0, 0.18, 0) * k)
			_add_piece(head, Vector3(0.18, 0.14, 0.24) * k, cap, Vector3(0, 0.26, 0.03) * k, Vector3(0.4, 0, 0))
			_add_piece(head, Vector3(0.02, 0.18, 0.05) * k, _material(Color(0.8, 0.2, 0.15)), Vector3(0.14, 0.27, 0.06) * k, Vector3(0, 0, -0.5))
			_add_piece(torso, Vector3(0.12, 0.42, 0.12) * k, leather, Vector3(0.1, 0.05, 0.19) * k, Vector3(0, 0, -0.25))
			for x in [0.06, 0.11, 0.16]:
				_add_piece(torso, Vector3(0.03, 0.08, 0.03) * k, _material(Color(0.92, 0.9, 0.84)), Vector3(x + 0.04, 0.3, 0.19) * k)
			_add_piece(torso, Vector3(0.03, 0.75, 0.03) * k, leather, Vector3(-0.05, 0.0, 0.16) * k, Vector3(0, 0, 0.6))
		"swordsman":
			# A steel kettle hat, shoulder plates and a sword at the hip.
			_add_piece(head, Vector3(0.44, 0.03, 0.44) * k, steel, Vector3(0, 0.13, 0) * k)
			_add_piece(head, Vector3(0.3, 0.12, 0.3) * k, steel, Vector3(0, 0.2, 0) * k)
			for side in ["_l", "_r"]:
				var arm: Node3D = _find_part("upper_arm" + side)["mesh"]
				_add_piece(arm, Vector3(0.17, 0.1, 0.17) * k, steel, Vector3(0, 0.12, 0) * k)
			_add_piece(torso, Vector3(0.08, 0.5, 0.02) * k, _material(Color(0.9, 0.85, 0.75)), Vector3(0, 0, -0.135) * k)
			_add_piece(pelvis, Vector3(0.05, 0.55, 0.06) * k, leather, Vector3(-0.22, -0.2, -0.04) * k, Vector3(0, 0, -0.2))
			_add_piece(pelvis, Vector3(0.16, 0.03, 0.04) * k, steel, Vector3(-0.17, 0.08, -0.04) * k, Vector3(0, 0, -0.2))
		"rider":
			# A steel helmet with a plume, and the horse.
			_add_piece(head, Vector3(0.32, 0.12, 0.32) * k, steel, Vector3(0, 0.17, 0) * k)
			_add_piece(head, Vector3(0.05, 0.2, 0.22) * k, _material(Color(0.85, 0.2, 0.18)), Vector3(0, 0.3, 0.04) * k)
			_build_horse()


## A rider's horse, under its own pivot on the body. Low-poly boxes facing -Z.
func _build_horse() -> void:
	var k := size_scale
	var coat := _body_material(Config.HORSE_COLOR)
	var dark := _body_material(Config.HORSE_COLOR.darkened(0.45))
	for material in [coat, dark]:
		_body_materials[material] = Art.get_color(material)
	var saddle := _material(Color(0.36, 0.2, 0.12))
	_horse = Node3D.new()
	_horse.name = "Horse"
	_body.add_child(_horse)
	_add_piece(_horse, Vector3(0.5, 0.5, 1.3) * k, coat, Vector3(0, 1.05, 0) * k)
	_add_piece(_horse, Vector3(0.54, 0.08, 0.5) * k, saddle, Vector3(0, 1.33, 0.02) * k)
	_add_piece(_horse, Vector3(0.24, 0.6, 0.28) * k, coat, Vector3(0, 1.42, -0.62) * k, Vector3(-0.5, 0, 0))
	_add_piece(_horse, Vector3(0.22, 0.24, 0.48) * k, coat, Vector3(0, 1.68, -0.88) * k, Vector3(0.25, 0, 0))
	_add_piece(_horse, Vector3(0.06, 0.5, 0.12) * k, dark, Vector3(0, 1.5, -0.5) * k, Vector3(-0.5, 0, 0))
	for x in [-0.07, 0.07]:
		_add_piece(_horse, Vector3(0.05, 0.1, 0.04) * k, coat, Vector3(x, 1.84, -0.74) * k)
	_add_piece(_horse, Vector3(0.08, 0.45, 0.08) * k, dark, Vector3(0, 0.95, 0.72) * k, Vector3(0.45, 0, 0))
	for corner in [Vector3(-0.17, 0, -0.5), Vector3(0.17, 0, -0.5), Vector3(-0.17, 0, 0.5), Vector3(0.17, 0, 0.5)]:
		var leg := Node3D.new()
		leg.position = (corner + Vector3(0, 0.85, 0)) * k
		_horse.add_child(leg)
		_add_piece(leg, Vector3(0.13, 0.78, 0.13) * k, coat, Vector3(0, -0.39, 0) * k)
		_add_piece(leg, Vector3(0.15, 0.08, 0.16) * k, dark, Vector3(0, -0.8, 0) * k)
		_horse_legs.append(leg)


## The rider is beaten: its horse trots off and disappears.
func _send_horse_away() -> void:
	if not is_instance_valid(_horse):
		return
	var horse := _horse
	_horse = null
	Fx.dust(horse.global_position, true)
	var away := horse.create_tween()
	away.tween_interval(0.6)
	away.tween_property(horse, "scale", Vector3.ONE * 0.01, 0.6)
	away.tween_callback(horse.queue_free)


# --- Bandits (D-2 to D-5) ------------------------------------------------------------

## Takes materials from the knight and runs. False if he had nothing to steal.
func _steal() -> bool:
	var inventory = get_tree().get_first_node_in_group("inventory")
	if inventory == null:
		return false
	var taken: Dictionary = inventory.steal(Config.BANDIT_STEAL_AMOUNT)
	if taken.is_empty():
		return false
	_stolen = taken
	_has_stolen = true
	_fleeing = true
	WorldTime.bump()
	# A sack on its back, and a THIEF marker that shows through trees.
	var torso: Node3D = _find_part("torso")["mesh"]
	var sack := SphereMesh.new()
	sack.radius = 0.2 * size_scale
	sack.height = 0.36 * size_scale
	sack.radial_segments = 6
	sack.rings = 3
	sack.material = _material(Color(0.62, 0.5, 0.32))
	var sack_mesh := MeshInstance3D.new()
	sack_mesh.mesh = sack
	sack_mesh.position = Vector3(0, 0.08, 0.24) * size_scale
	torso.add_child(sack_mesh)
	_thief_marker = Label3D.new()
	_thief_marker.text = "THIEF"
	_thief_marker.font_size = 40
	_thief_marker.outline_size = 10
	_thief_marker.modulate = Color(1.0, 0.3, 0.2)
	_thief_marker.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_thief_marker.no_depth_test = true
	_thief_marker.fixed_size = true
	_thief_marker.pixel_size = 0.0012
	_thief_marker.position = Vector3.UP * 2.3 * size_scale
	add_child(_thief_marker)
	var parts: Array[String] = []
	for id in taken:
		parts.append("%d %s" % [taken[id], String(Config.MATERIAL_NAMES[id]).to_lower()])
	var hud = get_tree().get_first_node_in_group("hud")
	if hud != null:
		hud.show_alert("Stolen! A bandit took %s" % ", ".join(parts))
	return true


## Runs straight for the nearest edge of the map (away from the middle).
func _flee(delta: float) -> void:
	var out := Vector3(global_position.x, 0.0, global_position.z)
	if out.length() >= Config.BANDIT_ESCAPE_RADIUS:
		_escape()
		return
	var direction := out.normalized() if out.length_squared() > 0.01 else Vector3.FORWARD
	if _detour_time > 0.0:
		_detour_time -= delta
		direction = direction.rotated(Vector3.UP, _detour_side * 1.2)
	var speed := walk_speed * Config.BANDIT_FLEE_SPEED * (_slow_factor if _slow_left > 0.0 else 1.0)
	velocity.x = direction.x * speed
	velocity.z = direction.z * speed
	_apply_gravity(delta)
	var before := global_position
	move_and_slide()
	var moved_speed := (global_position - before).length() / maxf(delta, 0.0001)
	_stuck_time = _stuck_time + delta if moved_speed < speed * 0.3 else 0.0
	if _stuck_time > 0.5:
		_stuck_time = 0.0
		_detour_time = 1.0
		_detour_side = -1.0 if randf() < 0.5 else 1.0
	_turn_towards(direction, delta)
	_animate_walk(delta, 1.0)


## D-4: the thief reached the edge of the map and is gone, with what it stole.
func _escape() -> void:
	escaped = true
	_stolen.clear()
	_start(State.DEFEATED)
	_fell_apart = true
	remove_from_group("dummies")
	set_physics_process(false)
	var hud = get_tree().get_first_node_in_group("hud")
	if hud != null:
		hud.show_toast("A bandit got away with your materials!")
	defeated.emit()
	var vanish := create_tween()
	vanish.tween_property(_body, "scale", Vector3.ONE * 0.01, 0.4)
	vanish.tween_callback(queue_free)


## A small detail box (eyes, straw, belt). Beyond LOD_DETAIL_DISTANCE these are
## hidden, so far-away dummies are simpler (F-2); the big boss keeps every detail.
func _add_box(parent: Node3D, size: Vector3, material: Material, at: Vector3, tilt := 0.0) -> void:
	var box := BoxMesh.new()
	box.size = size
	box.material = material
	var mesh := MeshInstance3D.new()
	mesh.mesh = box
	mesh.transform = Transform3D(Basis(Vector3.BACK, tilt), at)
	_detail_lod(mesh)
	parent.add_child(mesh)


## A piece of clothing or gear: a box turned by `turn` (Euler angles). Small
## pieces disappear far away, like the other details (F-2).
func _add_piece(parent: Node3D, size: Vector3, material: Material, at: Vector3, turn := Vector3.ZERO) -> void:
	var box := BoxMesh.new()
	box.size = size
	box.material = material
	var mesh := MeshInstance3D.new()
	mesh.mesh = box
	mesh.transform = Transform3D(Basis.from_euler(turn), at)
	if size.length() < 0.25 * size_scale:
		_detail_lod(mesh)
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
	_detail_lod(mesh)
	parent.add_child(mesh)


## A shared toon material for small details.
func _material(color: Color) -> Material:
	return Art.material(color)


## A body material of this dummy's own, with the character rim light.
func _body_material(color: Color) -> Material:
	return Art.material(color, {"rim": true, "unique": true})


func _detail_lod(mesh: GeometryInstance3D) -> void:
	if not is_big_boss:
		mesh.visibility_range_end = Config.LOD_DETAIL_DISTANCE * maxf(size_scale, 1.0)
