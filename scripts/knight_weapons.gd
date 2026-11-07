extends Node
## The knight's weapons and hotbar (PRD R-6, R-8, R-9, R-12, R-15 to R-17).
##
## Slot 1 is always the throwing knives. Crafted weapons join the hotbar in
## the order they're made. Switch with 1-9 or the mouse wheel (the Weapon button
## cycles on touch). Attack (left click / Attack button) does whatever the
## equipped weapon does:
## - knives: throw one (W-3)
## - spear, sword, axe: melee swing; the spear reaches far, the sword is fast,
##   the axe is slow and hits everyone in front of the knight
## - bow: shoot an arrow (unlimited)
## - Cryo dagger: a slash freezes the head; the next dagger hit shatters it (R-8)
## - Cryo hammer: a heavy swing; right click / Slam is a big icy ground slam
##   once per wave (R-6); F / Spin hits everyone around the knight, with a
##   cooldown (R-9, R-16)
## - Ultra blaster: lob an exploding round; 3 shots, then it breaks (R-12)
## - dagger and bat: quick melee swings; the bat knocks enemies back hard
## - grenades: throw one in an arc; it's used up (G-3)
##
## Damage and timings come from game_config.gd. Cooldowns run on world time,
## and every attack gives world time a short bump (T-2).

## Sent when the hotbar's contents or selection change.
signal hotbar_changed

const Config := preload("res://scripts/game_config.gd")
const WeaponModels := preload("res://scripts/weapon_models.gd")
const Effects := preload("res://scripts/effects.gd")
const Fx := preload("res://scripts/fx.gd")
const ARROW_SCENE := preload("res://scenes/arrow.tscn")
const Pool := preload("res://scripts/pool.gd")
const BLASTER_ROUND := preload("res://scripts/blaster_round.gd")
const GRENADE := preload("res://scripts/grenade.gd")
const ICE := Color(0.55, 0.85, 1.0)
## A melee target has to be within this angle of where the knight is aiming (as a dot product).
const MELEE_ARC := 0.35
## Render layer value of the knight's meshes (hidden in first person).
const KNIGHT_LAYER_VALUE := 2

var selected := 0
var slam_ready := true

var _knight = null
var _inventory = null
var _hand: Node3D
var _held: Node3D
var _held_id := ""
var _cooldown_left := 0.0
var _spin_cooldown_left := 0.0


func _ready() -> void:
	_knight = get_parent()
	# The hand sits at the end of the knight's right arm.
	_hand = Node3D.new()
	_hand.name = "Hand"
	_hand.position = Vector3(0.0, -0.64, 0.0)
	_knight.get_node("Model/RightArm").add_child(_hand)
	_connect_signals.call_deferred()


func _physics_process(delta: float) -> void:
	_cooldown_left = maxf(_cooldown_left - delta, 0.0)
	_spin_cooldown_left = maxf(_spin_cooldown_left - delta, 0.0)


func slots() -> Array[String]:
	var list: Array[String] = ["knife"]
	if _inventory != null:
		list.append_array(_inventory.weapons)
	return list


func equipped() -> String:
	var list := slots()
	return list[clampi(selected, 0, list.size() - 1)]


func select_slot(index: int) -> void:
	if index < 0 or index >= slots().size():
		return
	selected = index
	refresh()


func cycle(step: int) -> void:
	selected = posmod(selected + step, slots().size())
	refresh()


## The HUD's hotbar: one entry per slot with its key, name, a detail line and whether it's selected.
func hotbar_info() -> Array[Dictionary]:
	var info: Array[Dictionary] = []
	var list := slots()
	for i in list.size():
		var id := list[i]
		var detail := ""
		match id:
			"knife":
				detail = "%d / %d" % [_knight.knives, _knight.max_knives]
			"ultra_blaster":
				detail = "%d shots" % _inventory.blaster_shots
			"grenade":
				detail = "%d left" % _inventory.grenades
			"cryo_hammer":
				var spin := "ready" if _spin_cooldown_left == 0.0 else "%ds" % ceili(_spin_cooldown_left)
				detail = "spin %s · slam %s" % [spin, "ready" if slam_ready else "used"]
		# Keys 1 to 9 pick the first nine slots; the mouse wheel reaches the rest.
		info.append({"key": i + 1 if i < 9 else 0, "name": Config.WEAPONS[id]["name"], "detail": detail, "selected": i == selected})
	return info


## Called when a wave starts: the hammer's ground slam is ready again (R-6).
func on_wave_started(_wave: int, _last_wave: int) -> void:
	slam_ready = true


# --- Attacks -----------------------------------------------------------------

func attack() -> void:
	if _cooldown_left > 0.0:
		return
	var id := equipped()
	var stats: Dictionary = Config.WEAPONS[id]
	match stats["kind"]:
		"throw":
			if _knight.knives <= 0:
				return
			_knight.throw_knife()
		"melee":
			_melee(id, stats)
		"bow":
			_shoot_arrow(stats)
		"blaster":
			_fire_blaster()
		"grenade":
			_throw_grenade()
	_cooldown_left = stats["cooldown"]


## Right click / Slam: a big icy blast around the knight, once per wave (R-6).
func slam() -> void:
	if equipped() != "cryo_hammer" or not slam_ready or _cooldown_left > 0.0:
		return
	slam_ready = false
	_cooldown_left = Config.WEAPONS["cryo_hammer"]["cooldown"]
	_knight.play_swing()
	WorldTime.bump()
	var center: Vector3 = _knight.global_position
	Effects.burst(center, Config.HAMMER_SLAM_RADIUS * 0.6, ICE, get_tree().current_scene)
	Fx.ice_ring(center, Config.HAMMER_SLAM_RADIUS, get_tree().current_scene)
	for enemy in _enemies_within(center, Config.HAMMER_SLAM_RADIUS):
		# Weakened regular dummies shatter outright; everyone else takes the hit and freezes.
		if not enemy.is_boss() and enemy.health_fraction() < Config.HAMMER_SLAM_SHATTER_BELOW:
			enemy.shatter(center)
			continue
		enemy.take_hit(Config.HAMMER_SLAM_DAMAGE, center, 6.0)
		if enemy.is_alive():
			enemy.freeze(Config.HAMMER_SLAM_FREEZE_TIME)
	hotbar_changed.emit()


## F / Spin: hits everyone close around the knight, then needs to cool down (R-9, R-16).
func spin() -> void:
	if equipped() != "cryo_hammer" or _spin_cooldown_left > 0.0:
		return
	_spin_cooldown_left = Config.HAMMER_SPIN_COOLDOWN
	_knight.play_spin()
	WorldTime.bump()
	var center: Vector3 = _knight.global_position
	Effects.burst(center + Vector3.UP * 0.8, Config.HAMMER_SPIN_RADIUS, ICE, get_tree().current_scene)
	for enemy in _enemies_within(center, Config.HAMMER_SPIN_RADIUS):
		enemy.take_hit(Config.HAMMER_SPIN_DAMAGE, center, 4.0)
	hotbar_changed.emit()


func _melee(id: String, stats: Dictionary) -> void:
	var forward: Vector3 = _knight.aim_forward_flat()
	_knight.face_direction(forward)
	_knight.play_swing()
	WorldTime.bump()
	var origin: Vector3 = _knight.global_position
	var reach: float = stats["reach"]
	var damage: int = stats["damage"]

	# Everyone in front of the knight within reach, nearest first.
	var in_reach: Array = []
	for enemy in _enemies_within(origin, reach + 1.5):
		var to_enemy: Vector3 = enemy.global_position - origin
		to_enemy.y = 0.0
		var distance: float = to_enemy.length() - 0.3 * enemy.size_scale
		if distance <= reach and (distance < 0.5 or to_enemy.normalized().dot(forward) >= MELEE_ARC):
			in_reach.append([distance, enemy])
	in_reach.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	if not stats["sweep"] and in_reach.size() > 1:
		in_reach.resize(1)

	for entry in in_reach:
		var enemy = entry[1]
		if id == "cryo_dagger":
			# R-8: a frozen head shatters; otherwise this slash freezes it.
			if enemy.has_frozen_head():
				enemy.shatter_head(origin)
				continue
			enemy.take_hit(damage, origin, 2.0)
			if enemy.is_alive():
				enemy.freeze_head()
		else:
			enemy.take_hit(damage, origin, stats.get("push", 4.0 if id != "sword" else 3.0))


func _shoot_arrow(stats: Dictionary) -> void:
	WorldTime.bump()
	_knight.play_swing()
	var start: Vector3 = _knight.throw_start()
	var arrow = Pool.take("arrow")
	if arrow == null:
		arrow = ARROW_SCENE.instantiate()
	get_tree().current_scene.add_child(arrow)
	arrow.launch(start, _knight.throw_direction(start), stats["damage"])


func _fire_blaster() -> void:
	if _inventory == null or _inventory.blaster_shots <= 0:
		return
	WorldTime.bump()
	_knight.play_swing()
	var start: Vector3 = _knight.throw_start()
	var direction: Vector3 = _knight.throw_direction(start)
	var round_node = BLASTER_ROUND.new()
	get_tree().current_scene.add_child(round_node)
	# Lobbed like a grenade: forward and a little up.
	round_node.launch(start, direction * 20.0 + Vector3.UP * 3.0)
	_inventory.use_blaster_shot()


func _throw_grenade() -> void:
	if _inventory == null or _inventory.grenades <= 0:
		return
	WorldTime.bump()
	_knight.play_swing()
	var start: Vector3 = _knight.throw_start()
	var direction: Vector3 = _knight.throw_direction(start)
	var grenade = GRENADE.new()
	get_tree().current_scene.add_child(grenade)
	# Thrown in an arc: forward and up.
	grenade.launch(start, direction * Config.GRENADE_THROW_SPEED + Vector3.UP * 4.0)
	_inventory.use_grenade()


func _enemies_within(center: Vector3, radius: float) -> Array:
	var found: Array = []
	var enemies: Array = get_tree().get_nodes_in_group("dummies")
	for enemy in enemies:
		if enemy.is_alive() and enemy.global_position.distance_to(center) <= radius:
			found.append(enemy)
	return found


# --- Hotbar and the model in the knight's hand ----------------------------------

func _connect_signals() -> void:
	_inventory = get_tree().get_first_node_in_group("inventory")
	if _inventory != null:
		_inventory.changed.connect(refresh)
	var waves = get_tree().get_first_node_in_group("wave_manager")
	if waves != null:
		waves.wave_started.connect(on_wave_started)
	refresh()


## Updates the model in the knight's hand and the HUD (call when the knife count changes).
func refresh() -> void:
	selected = clampi(selected, 0, slots().size() - 1)
	var id := equipped()
	# Knives only show in the hand while the knight is carrying one.
	var show_id := id
	if id == "knife" and _knight.knives <= 0:
		show_id = ""
	if show_id != _held_id:
		if is_instance_valid(_held):
			_held.queue_free()
		_held = null
		_held_id = show_id
		if not show_id.is_empty():
			_held = WeaponModels.build(show_id, KNIGHT_LAYER_VALUE)
			_hand.add_child(_held)
	hotbar_changed.emit()
