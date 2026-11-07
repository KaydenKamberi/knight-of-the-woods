extends CanvasLayer
## Heads-up display.
##
## - Health bar, knife count and world-speed readout in the top-left corner (E-3).
## - Crosshair in the middle, where knives are aimed, and a shift-lock indicator.
## - "Press E" prompt when a knife is in reach (PC), or the Grab button (touch).
## - Touch controls on phones and tablets, and a short controls hint on PC
##   (K-1). The last kind of input used wins: touching the screen switches to
##   touch controls, and typing or clicking a real mouse switches back.
## - Wave counter, dummies left, break countdown, a "Wave X" banner and the
##   mini boss's health bar (M4), fed by the wave manager.
## - Game-over screen with a Restart button when the knight falls, and the
##   "Final battle coming soon" screen after wave 19.

signal input_mode_changed(touch: bool)
## Forwarded from the touch controls, in screen pixels.
signal look_dragged(relative: Vector2)

const TouchControls := preload("res://scripts/touch_controls.gd")

## Show the "World time 5%" readout (handy while tuning the time mechanic).
@export var show_world_time := true

var touch_mode := false

var _pickup_prompt := ""
var _last_health := -1
var _flash_tween: Tween
var _banner_tween: Tween

@onready var _touch_controls: TouchControls = $TouchControls
@onready var _pc_hint: Control = $PcHint
@onready var _health_bar: ProgressBar = $Status/HealthBar
@onready var _knife_label: Label = $Status/KnifeLabel
@onready var _world_time_label: Label = $Status/WorldTimeLabel
@onready var _crosshair: Control = $Crosshair
@onready var _shift_lock_label: Label = $Status/ShiftLockLabel
@onready var _pickup_label: Label = $PickupPrompt
@onready var _damage_flash: ColorRect = $DamageFlash
@onready var _game_over: Control = $GameOver
@onready var _restart_button: Button = $GameOver/Center/RestartButton
@onready var _end_title: Label = $GameOver/Center/Title
@onready var _end_subtitle: Label = $GameOver/Center/Subtitle
@onready var _wave_label: Label = $WaveInfo/WaveLabel
@onready var _enemies_label: Label = $WaveInfo/EnemiesLabel
@onready var _countdown_label: Label = $WaveInfo/CountdownLabel
@onready var _boss_name_label: Label = $WaveInfo/BossName
@onready var _boss_bar: ProgressBar = $WaveInfo/BossBar
@onready var _banner: Label = $Banner


func _ready() -> void:
	_touch_controls.look_dragged.connect(func(relative: Vector2) -> void: look_dragged.emit(relative))
	_restart_button.pressed.connect(_on_restart_pressed)
	_set_touch_mode(DisplayServer.is_touchscreen_available())


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if not touch_mode:
			_set_touch_mode(true)
	elif touch_mode:
		var real_mouse_click: bool = event is InputEventMouseButton \
				and event.device != InputEvent.DEVICE_ID_EMULATION
		if event is InputEventKey or real_mouse_click:
			_set_touch_mode(false)


func _process(_delta: float) -> void:
	_pc_hint.visible = not touch_mode and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED
	_pickup_label.visible = not touch_mode and not _pickup_prompt.is_empty()
	_world_time_label.visible = show_world_time
	if show_world_time:
		_world_time_label.text = "World time %d%%" % roundi(WorldTime.speed * 100.0)


# --- Called by the knight (connected in forest.tscn) ---------------------------

func set_health(health: int, max_health: int) -> void:
	_health_bar.max_value = max_health
	_health_bar.value = health
	if _last_health >= 0 and health < _last_health:
		_flash_damage()
	_last_health = health


func set_knives(count: int, max_count: int) -> void:
	_knife_label.text = "Knives %d / %d" % [count, max_count]
	_touch_controls.throw_enabled = count > 0


func set_shift_lock(enabled: bool) -> void:
	_touch_controls.lock_on = enabled
	_shift_lock_label.visible = enabled


func set_pickup_prompt(prompt: String) -> void:
	_pickup_prompt = prompt
	_pickup_label.text = "[E]  " + prompt
	_touch_controls.grab_visible = not prompt.is_empty()


## Freezes the game and shows the game-over screen.
func show_game_over() -> void:
	_show_end_screen("You have fallen", "The dummies got the better of you.")


# --- Called by the wave manager (connected in forest.tscn) ------------------------

func on_wave_started(wave: int, last_wave: int) -> void:
	_wave_label.text = "Wave %d / %d" % [wave, last_wave]
	_show_banner("Wave %d" % wave)


func on_dummies_left_changed(count: int) -> void:
	if count > 0:
		_enemies_label.text = "Dummies left: %d" % count
	else:
		_enemies_label.text = "The mini boss is coming..."


func on_break_time_changed(seconds_left: float, next_wave: int) -> void:
	_countdown_label.visible = seconds_left >= 0.0
	if seconds_left >= 0.0:
		_countdown_label.text = "Wave %d starts in %d" % [next_wave, ceili(seconds_left)]
		_enemies_label.text = "Break: grab your knives"


func on_mini_boss_appeared(boss_name: String) -> void:
	_enemies_label.text = "Mini boss!"
	_boss_name_label.text = boss_name
	_boss_name_label.visible = true
	_boss_bar.visible = true
	_show_banner("%s appears!" % boss_name)


func on_mini_boss_health_changed(health: int, max_health: int) -> void:
	_boss_bar.max_value = max_health
	_boss_bar.value = health


func on_wave_cleared(wave: int) -> void:
	_boss_name_label.visible = false
	_boss_bar.visible = false
	_show_banner("Wave %d cleared!" % wave)


func show_final_battle_placeholder() -> void:
	_show_end_screen("Final battle coming soon",
			"You beat all 19 waves! The battle at the castle gates is on its way.")


# -----------------------------------------------------------------------------

func _show_end_screen(title: String, subtitle: String) -> void:
	_end_title.text = title
	_end_subtitle.text = subtitle
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_touch_controls.visible = false
	_pc_hint.visible = false
	_pickup_label.visible = false
	_crosshair.visible = false
	_game_over.visible = true
	_restart_button.grab_focus()


# -----------------------------------------------------------------------------

func _on_restart_pressed() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()


## Shows big text in the middle of the screen for a couple of seconds.
func _show_banner(text: String) -> void:
	_banner.text = text
	if _banner_tween:
		_banner_tween.kill()
	_banner.modulate.a = 0.0
	_banner_tween = create_tween().set_ignore_time_scale(true)
	_banner_tween.tween_property(_banner, "modulate:a", 1.0, 0.2)
	_banner_tween.tween_interval(1.8)
	_banner_tween.tween_property(_banner, "modulate:a", 0.0, 0.5)


func _flash_damage() -> void:
	if _flash_tween:
		_flash_tween.kill()
	_damage_flash.modulate.a = 1.0
	_flash_tween = create_tween().set_ignore_time_scale(true)
	_flash_tween.tween_property(_damage_flash, "modulate:a", 0.0, 0.4)


func _set_touch_mode(enabled: bool) -> void:
	touch_mode = enabled
	_touch_controls.visible = enabled and not _game_over.visible
	input_mode_changed.emit(enabled)
