extends Node
## Runs all 20 waves (PRD V-1 to V-7, R-3, R-4, W-5).
##
## Waves 1 to 19: wave n sends 2 × n dummies in from spawn points out in the
## forest, far from the castle (V-1). When they're all down, that wave's mini
## boss appears (V-2). Beating it ends the wave. After waves 1 to 14 there's a
## break to collect knives and craft: 30 seconds after wave 1, growing to 60
## seconds after wave 14 (R-3). From wave 15 on, waves run back to back (R-4).
##
## Wave 20, the final battle (V-4): 40 dummies, 10 of the earlier mini bosses
## (picked at random, each with the health it had in its own wave) and the big
## boss. They come in FINAL_WAVE_GROUPS groups so nothing lags; the big boss
## comes with the last. When every one of them is down, the game is won (V-5).
##
## Crafting and smelting are open before wave 1 and during breaks, but never
## from wave 15 on. Waves, spawns and breaks run on world time.
##
## For testing: set Start Wave in the Inspector. In debug builds (running from
## the editor), F2 skips to the next wave and F3 ends a break, brings the mini
## boss out, or (in wave 20) sends the next group. The DebugKeys node's F6
## jumps straight to wave 20.

signal wave_started(wave: int, last_wave: int)
signal dummies_left_changed(count: int)
## Seconds left before `next_wave` starts, or -1 when no break is running.
signal break_time_changed(seconds_left: float, next_wave: int)
signal mini_boss_appeared(boss_name: String)
signal mini_boss_health_changed(health: int, max_health: int)
signal wave_cleared(wave: int)
## Sent when every enemy of wave 20 is down: the game is won.
signal all_waves_cleared
## Crafting and smelting are open before wave 1 and during breaks up to wave 14 (R-3, R-5).
signal crafting_available_changed(available: bool)
signal big_boss_appeared(boss_name: String)
signal big_boss_health_changed(health: int, max_health: int)

enum Phase { BREAK, DUMMIES, MINI_BOSS_COMING, MINI_BOSS, FINAL_BATTLE, DONE }

const DUMMY_SCENE := preload("res://scenes/dummy.tscn")
const MiniBosses := preload("res://scripts/mini_bosses.gd")
const Config := preload("res://scripts/game_config.gd")

## The first wave to play. Set it higher to test later waves.
@export_range(1, 20) var start_wave := 1
@export var last_wave := Config.LAST_WAVE
## Wave n has this many dummies times n (V-1).
@export var dummies_per_wave := Config.DUMMIES_PER_WAVE

@export_group("Breaks")
## Seconds before wave 1 (or Start Wave) begins, to grab a knife.
@export var first_break := Config.FIRST_BREAK
## Break after wave 1, in seconds.
@export var shortest_break := Config.SHORTEST_BREAK
## Break after last_break_wave, in seconds. Breaks in between grow evenly.
@export var longest_break := Config.LONGEST_BREAK
## The last wave with a break after it (R-4: none from wave 15 on).
@export var last_break_wave := Config.LAST_BREAK_WAVE
## Breaks count down in world time, so standing still stretches them out.
## Turn this off to count breaks in real seconds instead.
@export var breaks_use_world_time := true

@export_group("Spawning")
## How far from the middle of the forest dummies walk in from, in metres.
@export var spawn_radius := 30.0
@export var spawn_point_count := 16
## Spawn points closer than this to the knight aren't used.
@export var min_distance_from_knight := 12.0
## Seconds (world time) between dummies walking in, so big waves arrive as a stream.
@export var spawn_interval := 0.4
## Seconds (world time) between the last dummy falling and the mini boss appearing.
@export var mini_boss_delay := 1.5

var wave := 0
var phase := Phase.BREAK
## Debug shortcut F7 turns this on so the crafting menu opens at any time.
var debug_crafting_anytime := false

var _break_left := 0.0
var _to_spawn := 0
var _spawn_timer := 0.0
var _dummies_left := 0
var _boss_delay_left := 0.0
var _spawn_points: Array[Vector3] = []
var _rng := RandomNumberGenerator.new()
var _crafting_was_available := false
## The regular enemies' looks (D-1), shuffled and dealt out in turn so every wave mixes them.
var _looks: Array = []
# Wave 20: the groups still to come (each a list of "dummy", "big" or a mini boss's wave
# number), what's queued to walk in now, how many are left, and how long since the last group.
var _final_groups: Array = []
var _final_queue: Array = []
var _final_left := 0
var _final_alive := 0
var _group_wait := 0.0
# For the victory screen.
var _time_played := 0.0
var _enemies_defeated := 0
var _mini_bosses_defeated := 0

## Holds every dummy and mini boss, alive or in pieces.
@onready var _enemies: Node3D = $Enemies


func _ready() -> void:
	add_to_group("wave_manager")
	_rng.randomize()
	for i in spawn_point_count:
		var angle := TAU * i / spawn_point_count
		var point := Vector3(cos(angle), 0.0, sin(angle)) * spawn_radius
		# Enemies come from the forest, never from in or around the castle.
		if point.distance_to(Config.CASTLE_CENTER) >= Config.CASTLE_SPAWN_KEEP_OUT:
			_spawn_points.append(point)
	wave = clampi(start_wave, 1, last_wave) - 1
	# Wait a frame so the posters and the HUD exist before we talk to them.
	_start_break.call_deferred(first_break)


func _process(delta: float) -> void:
	_time_played += WorldTime.real_delta
	match phase:
		Phase.BREAK:
			_break_left -= delta if breaks_use_world_time else WorldTime.real_delta
			break_time_changed.emit(maxf(_break_left, 0.0), wave + 1)
			if _break_left <= 0.0:
				_start_wave(wave + 1)
		Phase.DUMMIES:
			if _to_spawn > 0:
				_spawn_timer -= delta
				if _spawn_timer <= 0.0:
					_spawn_timer = spawn_interval
					_spawn_dummy()
		Phase.MINI_BOSS_COMING:
			_boss_delay_left -= delta
			if _boss_delay_left <= 0.0:
				_spawn_mini_boss()
		Phase.FINAL_BATTLE:
			_run_final_battle(delta)
	var crafting := can_craft()
	if crafting != _crafting_was_available:
		_crafting_was_available = crafting
		crafting_available_changed.emit(crafting)


## True when crafting and smelting are open: before wave 1 and during breaks,
## but not during a wave and never from wave 15 on.
func can_craft() -> bool:
	if debug_crafting_anytime:
		return true
	return phase == Phase.BREAK and wave <= last_break_wave


## Why crafting and smelting are closed right now ("" if they're open).
func workshop_closed_reason() -> String:
	if can_craft():
		return ""
	if wave > last_break_wave:
		return "No smelting from wave %d on" % (last_break_wave + 1)
	return "You can only smelt during breaks"


## Numbers for the victory screen.
func stats() -> Dictionary:
	return {"time": _time_played, "enemies": _enemies_defeated, "mini_bosses": _mini_bosses_defeated}


func _unhandled_input(event: InputEvent) -> void:
	if not OS.is_debug_build():
		return
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	if key.keycode == KEY_F2:
		_debug_skip_wave()
	elif key.keycode == KEY_F3:
		_debug_hurry_up()


# --- Waves ----------------------------------------------------------------------

## Starts a break before the next wave. A break of 0 starts the next wave right away.
func _start_break(seconds: float) -> void:
	_show_mini_boss_on_posters(wave + 1)
	if seconds <= 0.0:
		_start_wave(wave + 1)
		return
	phase = Phase.BREAK
	_break_left = seconds
	break_time_changed.emit(seconds, wave + 1)


func _start_wave(number: int) -> void:
	if number >= last_wave:
		_start_final_battle()
		return
	wave = number
	phase = Phase.DUMMIES
	_to_spawn = dummies_per_wave * wave
	_dummies_left = _to_spawn
	_spawn_timer = 0.0
	_show_mini_boss_on_posters(wave)
	break_time_changed.emit(-1.0, wave)
	wave_started.emit(wave, last_wave)
	dummies_left_changed.emit(_dummies_left)


func _spawn_dummy() -> void:
	_to_spawn -= 1
	var dummy = DUMMY_SCENE.instantiate()
	dummy.look = _next_look()
	dummy.position = _pick_spawn_point()
	dummy.defeated.connect(_on_dummy_defeated.bind(dummy))
	_enemies.add_child(dummy)


## The next regular enemy look: bandit, archer, swordsman or rider (D-1).
func _next_look() -> String:
	if _looks.is_empty():
		_looks = Config.ENEMY_LOOKS.duplicate()
		_looks.shuffle()
	return _looks.pop_back()


func _on_dummy_defeated(dummy) -> void:
	# A bandit that got away still counts towards clearing the wave, but not as defeated.
	if not dummy.escaped:
		_enemies_defeated += 1
	_dummies_left -= 1
	dummies_left_changed.emit(_dummies_left)
	if _dummies_left <= 0 and phase == Phase.DUMMIES:
		phase = Phase.MINI_BOSS_COMING
		_boss_delay_left = mini_boss_delay


func _spawn_mini_boss() -> void:
	var info := MiniBosses.info(wave)
	var boss = DUMMY_SCENE.instantiate()
	boss.configure_mini_boss(info)
	boss.position = _pick_spawn_point()
	boss.defeated.connect(_on_mini_boss_defeated)
	boss.health_changed.connect(_on_mini_boss_health_changed)
	_enemies.add_child(boss)
	phase = Phase.MINI_BOSS
	mini_boss_appeared.emit(info["name"])
	mini_boss_health_changed.emit(info["health"], info["health"])


func _on_mini_boss_health_changed(health: int, max_health: int) -> void:
	mini_boss_health_changed.emit(health, max_health)


func _on_mini_boss_defeated() -> void:
	_enemies_defeated += 1
	_mini_bosses_defeated += 1
	wave_cleared.emit(wave)
	_start_break(break_after(wave))


## How long the break after `finished_wave` lasts, in seconds (R-3, R-4).
func break_after(finished_wave: int) -> float:
	if finished_wave > last_break_wave:
		return 0.0
	var progress := float(finished_wave - 1) / maxf(last_break_wave - 1, 1)
	return lerpf(shortest_break, longest_break, progress)


# --- Wave 20, the final battle ---------------------------------------------------

func _start_final_battle() -> void:
	wave = last_wave
	phase = Phase.FINAL_BATTLE
	_final_groups = _plan_final_groups()
	_final_queue.clear()
	_final_left = 0
	for group in _final_groups:
		_final_left += group.size()
	_final_alive = 0
	_show_mini_boss_on_posters(wave)
	break_time_changed.emit(-1.0, wave)
	wave_started.emit(wave, last_wave)
	dummies_left_changed.emit(_final_left)
	_send_next_group()


## Splits wave 20 into groups: the dummies evenly, the returning mini bosses
## (weakest first) spread across the groups, and the big boss in the last group.
func _plan_final_groups() -> Array:
	var group_count := maxi(Config.FINAL_WAVE_GROUPS, 1)
	var groups: Array = []
	for i in group_count:
		groups.append([])
	var dummy_count := dummies_per_wave * last_wave
	for i in dummy_count:
		groups[i * group_count / dummy_count].append("dummy")
	var waves: Array = range(1, last_wave)
	waves.shuffle()
	waves = waves.slice(0, mini(Config.FINAL_MINI_BOSS_COUNT, waves.size()))
	waves.sort()
	for i in waves.size():
		groups[i * group_count / waves.size()].append(waves[i])
	groups[group_count - 1].append("big")
	return groups


func _send_next_group() -> void:
	if _final_groups.is_empty():
		return
	var group: Array = _final_groups.pop_front()
	group.shuffle()
	_final_queue.append_array(group)
	_group_wait = 0.0
	_spawn_timer = 0.0


func _run_final_battle(delta: float) -> void:
	if not _final_queue.is_empty():
		_spawn_timer -= delta
		if _spawn_timer <= 0.0:
			_spawn_timer = spawn_interval
			_spawn_final_enemy(_final_queue.pop_front())
	elif not _final_groups.is_empty():
		# The next group comes once this one is nearly beaten, or after a while anyway.
		_group_wait += delta
		if _final_alive <= Config.FINAL_NEXT_GROUP_WHEN_ALIVE or _group_wait >= Config.FINAL_GROUP_MAX_WAIT:
			_send_next_group()


func _spawn_final_enemy(kind) -> void:
	var enemy = DUMMY_SCENE.instantiate()
	if kind is String and kind == "big":
		var info := MiniBosses.big_boss_info()
		enemy.configure_big_boss(info)
		enemy.health_changed.connect(_on_big_boss_health_changed)
		big_boss_appeared.emit(info["name"])
		big_boss_health_changed.emit(info["health"], info["health"])
	elif kind is int:
		enemy.configure_mini_boss(MiniBosses.info(kind))
	else:
		enemy.look = _next_look()
	enemy.position = _pick_spawn_point()
	enemy.defeated.connect(_on_final_enemy_defeated.bind(enemy))
	_enemies.add_child(enemy)
	_final_alive += 1


func _on_final_enemy_defeated(enemy) -> void:
	if not enemy.escaped:
		_enemies_defeated += 1
	if enemy.is_mini_boss and not enemy.is_big_boss:
		_mini_bosses_defeated += 1
	_final_alive -= 1
	_final_left -= 1
	dummies_left_changed.emit(_final_left)
	if _final_left <= 0 and phase == Phase.FINAL_BATTLE:
		phase = Phase.DONE
		all_waves_cleared.emit()


func _on_big_boss_health_changed(health: int, max_health: int) -> void:
	big_boss_health_changed.emit(health, max_health)


# ---------------------------------------------------------------------------------

func _pick_spawn_point() -> Vector3:
	var knight := get_tree().get_first_node_in_group("player") as Node3D
	var choices: Array[Vector3] = []
	for point in _spawn_points:
		if knight == null or point.distance_to(knight.global_position) >= min_distance_from_knight:
			choices.append(point)
	if choices.is_empty():
		choices = _spawn_points
	var jitter := Vector3(_rng.randf_range(-1.5, 1.5), 0.0, _rng.randf_range(-1.5, 1.5))
	return choices[_rng.randi() % choices.size()] + jitter


func _show_mini_boss_on_posters(for_wave: int) -> void:
	get_tree().call_group("wanted_posters", "show_mini_boss", MiniBosses.info(for_wave))


# --- Testing shortcuts (debug builds only) ---------------------------------------

## F2: clears the current wave and starts the next one straight away.
func _debug_skip_wave() -> void:
	if phase == Phase.DONE:
		return
	if wave >= last_wave and phase == Phase.FINAL_BATTLE:
		_clear_enemies()
		phase = Phase.DONE
		all_waves_cleared.emit()
		return
	debug_jump_to_wave(wave + 1)


## Clears whatever is happening and starts wave `number` right away (F2, and F6 for wave 20).
func debug_jump_to_wave(number: int) -> void:
	if phase == Phase.DONE:
		return
	_clear_enemies()
	if phase != Phase.BREAK:
		wave_cleared.emit(wave)
	_start_wave(clampi(number, 1, last_wave))


func _clear_enemies() -> void:
	for enemy in _enemies.get_children():
		enemy.queue_free()
	_final_groups.clear()
	_final_queue.clear()


## F3: ends a break now, removes this wave's dummies so the mini boss comes out,
## or in wave 20 sends the next group straight away.
func _debug_hurry_up() -> void:
	if phase == Phase.BREAK:
		_break_left = 0.0
	elif phase == Phase.FINAL_BATTLE:
		_send_next_group()
	elif phase == Phase.DUMMIES:
		var enemies: Array = _enemies.get_children()
		for enemy in enemies:
			if enemy.is_in_group("dummies") and not enemy.is_mini_boss:
				enemy.queue_free()
		_to_spawn = 0
		_dummies_left = 0
		dummies_left_changed.emit(0)
		phase = Phase.MINI_BOSS_COMING
		_boss_delay_left = 0.0
