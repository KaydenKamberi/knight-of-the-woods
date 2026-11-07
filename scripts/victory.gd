extends Node
## The ending (PRD V-5): runs when every enemy of wave 20 is down.
##
## 1. Time slows right down for a moment as the last of them falls.
## 2. The surviving soldiers line up in front of the castle gate and cheer,
##    while the camera pans from the battle over to the castle (3 to 4 seconds).
## 3. The victory screen: "The castle is safe!", with stats, Play Again and Quit.
##
## Timings live in game_config.gd. The pan and the waits run in real time.

const Config := preload("res://scripts/game_config.gd")
const Castle := preload("res://scripts/castle.gd")

var _running := false


## Connected to the wave manager's all_waves_cleared signal.
func start() -> void:
	if _running:
		return
	_running = true
	var knight = get_tree().get_first_node_in_group("player")
	var hud = get_tree().get_first_node_in_group("hud")
	if knight != null:
		knight.start_cutscene()
	if hud != null:
		hud.hide_for_cutscene()

	# 1. A moment of slow motion as the boss falls.
	WorldTime.set_override(Config.VICTORY_SLOW_SPEED, Config.VICTORY_SLOW_TIME)
	await get_tree().create_timer(Config.VICTORY_SLOW_TIME, true, false, true).timeout
	# Then normal speed for the rest, so the cheering doesn't crawl.
	WorldTime.set_override(1.0)

	# 2. Soldiers line up and cheer while the camera pans over to the castle.
	_line_up_soldiers()
	if knight != null:
		var camera := Camera3D.new()
		camera.name = "VictoryCamera"
		camera.fov = 70.0
		get_tree().current_scene.add_child(camera)
		camera.global_transform = knight.camera().global_transform
		camera.make_current()
		var pan := camera.create_tween().set_ignore_time_scale(true)
		pan.tween_property(camera, "global_transform", _castle_view(), Config.VICTORY_PAN_TIME) \
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		await pan.finished
	await get_tree().create_timer(0.6, true, false, true).timeout

	# 3. The victory screen.
	var waves = get_tree().get_first_node_in_group("wave_manager")
	var army = get_tree().get_first_node_in_group("army")
	var stats: Dictionary = waves.stats() if waves != null else {}
	var survivors: int = army.roster.size() if army != null else 0
	if hud != null:
		hud.show_victory(stats, survivors, Config.ARMY_SIZE)


## The survivors stand in rows in front of the gate, facing the camera.
func _line_up_soldiers() -> void:
	var army = get_tree().get_first_node_in_group("army")
	if army == null:
		return
	var soldiers: Array = army.field_soldiers()
	var gate := Castle.gate_outside()
	var per_row := 8
	for i in soldiers.size():
		var row := i / per_row
		var in_row := mini(per_row, soldiers.size() - row * per_row)
		var column := i % per_row
		var spot := gate + Vector3((column - (in_row - 1) * 0.5) * 1.2, 0.0, -0.5 - row * 1.3)
		soldiers[i].cheer_at(spot)


## Out in front of the castle, a little above the soldiers, looking at the gate.
func _castle_view() -> Transform3D:
	var gate := Castle.gate_outside()
	var eye := gate + Vector3(0.0, 6.0, -14.0)
	var target := Config.CASTLE_CENTER + Vector3(0.0, 2.5, -4.0)
	return Transform3D(Basis.looking_at(target - eye, Vector3.UP), eye)
