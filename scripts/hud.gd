extends CanvasLayer
## Heads-up display.
##
## - Health bar, knife count and world-speed readout in the top-left corner (E-3).
## - Crosshair in the middle, where knives are aimed.
## - "Press E" prompt when a knife is in reach (PC), or the Grab button (touch).
## - Touch controls on phones and tablets, and a short controls hint on PC
##   (K-1). The last kind of input used wins: touching the screen switches to
##   touch controls, and typing or clicking a real mouse switches back.
## - Game-over screen with a Restart button when the knight falls.

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

@onready var _touch_controls: TouchControls = $TouchControls
@onready var _pc_hint: Control = $PcHint
@onready var _health_bar: ProgressBar = $Status/HealthBar
@onready var _knife_label: Label = $Status/KnifeLabel
@onready var _world_time_label: Label = $Status/WorldTimeLabel
@onready var _crosshair: Control = $Crosshair
@onready var _pickup_label: Label = $PickupPrompt
@onready var _damage_flash: ColorRect = $DamageFlash
@onready var _game_over: Control = $GameOver
@onready var _restart_button: Button = $GameOver/Center/RestartButton


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


func set_pickup_prompt(prompt: String) -> void:
	_pickup_prompt = prompt
	_pickup_label.text = "[E]  " + prompt
	_touch_controls.grab_visible = not prompt.is_empty()


## Freezes the game and shows the game-over screen.
func show_game_over() -> void:
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
