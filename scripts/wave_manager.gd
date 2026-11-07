extends Node
## Runs waves 1 to 19 (PRD V-1, V-2, V-3, V-6, V-7, R-3, R-4, W-5).
##
## Wave n sends 2 × n dummies in from spawn points around the forest edge
## (V-1). When they're all down, that wave's mini boss appears (V-2). Beating
## it ends the wave. After waves 1 to 14 there's a break to collect knives:
## 30 seconds after wave 1, growing to 60 seconds after wave 14 (R-3). From
## wave 15 on, waves run back to back (R-4). After the wave 19 mini boss, the
## final battle placeholder appears. Waves, spawns and breaks run on world time.
##
## For testing: set Start Wave in the Inspector to begin at a later wave. In
## debug builds (running from the editor), F2 skips to the next wave and F3
## ends a break or clears the current dummies so the mini boss comes out.

signal wave_started(wave: int, last_wave: int)
signal dummies_left_changed(count: int)
## Seconds left before `next_wave` starts, or -1 when no break is running.
signal break_time_changed(seconds_left: float, next_wave: int)
signal mini_boss_appeared(boss_name: String)
signal mini_boss_health_changed(health: int, max_health: int)
signal wave_cleared(wave: int)
signal all_waves_cleared

enum Phase { BREAK, DUMMIES, MINI_BOSS_COMING, MINI_BOSS, DONE }

const DUMMY_SCENE := preload("res://scenes/dummy.tscn")
const MiniBosses := preload("res://scripts/mini_bosses.gd")

## The first wave to play. Set it higher to test later waves.
@export_range(1, 19) var start_wave := 1
@export var last_wave := 19
## Wave n has this many dummies times n (V-1).
@export var dummies_per_wave := 2

@export_group("Breaks")
## Seconds before wave 1 (or Start Wave) begins, to grab a knife.
@export var first_break := 10.0
## Break after wave 1, in seconds.
@export var shortest_break := 30.0
## Break after last_break_wave, in seconds. Breaks in between grow evenly.
@export var longest_break := 60.0
## The last wave with a break after it (R-4: none from wave 15 on).
@export var last_break_wave := 14
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

var _break_left := 0.0
var _to_spawn := 0
var _spawn_timer := 0.0
var _dummies_left := 0
var _boss_delay_left := 0.0
var _spawn_points: Array[Vector3] = []
var _rng := RandomNumberGenerator.new()

## Holds every dummy and mini boss, alive or in pieces.
@onready var _enemies: Node3D = $Enemies


func _ready() -> void:
	_rng.randomize()
	for i in spawn_point_count:
		var angle := TAU * i / spawn_point_count
		_spawn_points.append(Vector3(cos(angle), 0.0, sin(angle)) * spawn_radius)
	wave = clampi(start_wave, 1, last_wave) - 1
	# Wait a frame so the posters and the HUD exist before we talk to them.
	_start_break.call_deferred(first_break)


func _process(delta: float) -> void:
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
	dummy.position = _pick_spawn_point()
	dummy.defeated.connect(_on_dummy_defeated)
	_enemies.add_child(dummy)


func _on_dummy_defeated() -> void:
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
	boss.health_changed.connect(
			func(health: int, max_health: int) -> void: mini_boss_health_changed.emit(health, max_health))
	_enemies.add_child(boss)
	phase = Phase.MINI_BOSS
	mini_boss_appeared.emit(info["name"])
	mini_boss_health_changed.emit(info["health"], info["health"])


func _on_mini_boss_defeated() -> void:
	wave_cleared.emit(wave)
	if wave >= last_wave:
		phase = Phase.DONE
		# A moment to watch the last mini boss fall apart.
		get_tree().create_timer(2.5, false).timeout.connect(func() -> void: all_waves_cleared.emit())
	else:
		_start_break(break_after(wave))


## How long the break after `finished_wave` lasts, in seconds (R-3, R-4).
func break_after(finished_wave: int) -> float:
	if finished_wave > last_break_wave:
		return 0.0
	var progress := float(finished_wave - 1) / maxf(last_break_wave - 1, 1)
	return lerpf(shortest_break, longest_break, progress)


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
	for enemy in _enemies.get_children():
		enemy.queue_free()
	if phase != Phase.BREAK:
		wave_cleared.emit(wave)
	if wave >= last_wave:
		phase = Phase.DONE
		all_waves_cleared.emit()
	else:
		_start_wave(wave + 1)


## F3: ends a break now, or removes this wave's dummies so the mini boss comes out.
func _debug_hurry_up() -> void:
	if phase == Phase.BREAK:
		_break_left = 0.0
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
