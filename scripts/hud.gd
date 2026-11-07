extends CanvasLayer
## Heads-up display.
##
## Shows the touch controls on phones and tablets and a short controls hint on
## PC (PRD K-1), plus a small readout of the current world speed (handy while
## tuning the time mechanic). The last kind of input used wins: touching the screen switches
## to touch controls, and typing or clicking a real mouse switches back.

signal input_mode_changed(touch: bool)
## Forwarded from the touch controls, in screen pixels.
signal look_dragged(relative: Vector2)

## Show the "World time 5%" readout in the top-left corner.
@export var show_world_time := true

var touch_mode := false

@onready var _touch_controls: Control = $TouchControls
@onready var _pc_hint: Control = $PcHint
@onready var _world_time_label: Label = $WorldTimeLabel


func _ready() -> void:
	_touch_controls.look_dragged.connect(func(relative: Vector2) -> void: look_dragged.emit(relative))
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
	_world_time_label.visible = show_world_time
	if show_world_time:
		_world_time_label.text = "World time %d%%" % roundi(WorldTime.speed * 100.0)


func _set_touch_mode(enabled: bool) -> void:
	touch_mode = enabled
	_touch_controls.visible = enabled
	input_mode_changed.emit(enabled)
