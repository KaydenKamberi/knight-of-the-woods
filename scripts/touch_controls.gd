extends Control
## On-screen controls for phones and tablets (PRD K-1, C-3).
##
## - Left half of the screen: a joystick that appears under your thumb.
##   It presses the same move_* actions as WASD, so the knight script
##   doesn't need to know where the input came from.
## - Right half of the screen: drag to look around.
## - Camera icon (top right): switches between third and first person.
## - Throw button (bottom right): throws a knife at the crosshair (W-3).
##   It's dimmed while the knight has no knives.
## - Grab button (next to Throw): only appears when a knife is in reach (W-2).
##
## Each finger is tracked separately, so you can walk and look at the same time.

## Sent while a finger drags on the right half, in screen pixels.
signal look_dragged(relative: Vector2)

const MOVE_ACTIONS := ["move_left", "move_right", "move_forward", "move_back"]

@export var joystick_radius := 90.0
@export var knob_radius := 38.0
## Where the joystick rests when nobody is touching it, measured from the bottom-left corner.
@export var joystick_home := Vector2(170.0, 170.0)
@export var camera_button_size := 84.0
## Gap between the camera icon and the top-right corner.
@export var camera_button_margin := Vector2(32.0, 32.0)
@export var throw_button_radius := 62.0
## Middle of the Throw button, measured from the bottom-right corner.
@export var throw_button_home := Vector2(130.0, 140.0)
@export var grab_button_radius := 48.0
## Middle of the Grab button, measured from the bottom-right corner.
@export var grab_button_home := Vector2(265.0, 95.0)

## Set by the HUD: dims the Throw button when there's nothing to throw.
var throw_enabled := false:
	set(value):
		throw_enabled = value
		queue_redraw()
## Set by the HUD: shows the Grab button while a knife is in reach.
var grab_visible := false:
	set(value):
		grab_visible = value
		queue_redraw()

var _stick_finger := -1
var _stick_center := Vector2.ZERO
var _stick_vector := Vector2.ZERO
var _look_finger := -1


func _ready() -> void:
	resized.connect(queue_redraw)
	visibility_changed.connect(_on_visibility_changed)


func _input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	if event is InputEventScreenTouch:
		if event.pressed:
			_on_finger_down(event.index, event.position)
		else:
			_on_finger_up(event.index)
	elif event is InputEventScreenDrag:
		if event.index == _stick_finger:
			_move_stick(event.position)
		elif event.index == _look_finger:
			look_dragged.emit(event.relative)


func _exit_tree() -> void:
	# Restarting the game reloads the scene. Make sure no movement stays "held".
	_apply_move(Vector2.ZERO)


func _on_finger_down(finger: int, at: Vector2) -> void:
	if _camera_button_rect().has_point(at):
		_tap_action(&"switch_camera")
	elif at.distance_to(_throw_button_center()) <= throw_button_radius:
		_tap_action(&"throw")
	elif grab_visible and at.distance_to(_grab_button_center()) <= grab_button_radius:
		_tap_action(&"interact")
	elif at.x < size.x * 0.5:
		if _stick_finger == -1:
			_stick_finger = finger
			# Keep the whole joystick on screen even if the thumb lands near an edge.
			var edge := Vector2.ONE * joystick_radius
			_stick_center = at.clamp(edge, (size - edge).max(edge))
			_move_stick(at)
	elif _look_finger == -1:
		_look_finger = finger


func _on_finger_up(finger: int) -> void:
	if finger == _stick_finger:
		_release_stick()
	elif finger == _look_finger:
		_look_finger = -1


func _move_stick(at: Vector2) -> void:
	_stick_vector = (at - _stick_center).limit_length(joystick_radius) / joystick_radius
	_apply_move(_stick_vector)
	queue_redraw()


func _release_stick() -> void:
	_stick_finger = -1
	_stick_vector = Vector2.ZERO
	_apply_move(Vector2.ZERO)
	queue_redraw()


## Presses the move actions with the joystick's strength (0 to 1 on each side).
func _apply_move(stick: Vector2) -> void:
	var strengths := [-stick.x, stick.x, -stick.y, stick.y]
	for i in MOVE_ACTIONS.size():
		if strengths[i] > 0.0:
			Input.action_press(MOVE_ACTIONS[i], strengths[i])
		else:
			Input.action_release(MOVE_ACTIONS[i])


## Sends a press and release of an input action, exactly as if its key was tapped.
func _tap_action(action_name: StringName) -> void:
	for pressed in [true, false]:
		var action := InputEventAction.new()
		action.action = action_name
		action.pressed = pressed
		Input.parse_input_event(action)


func _on_visibility_changed() -> void:
	# Hiding the controls mid-touch must not leave the knight walking.
	if not visible:
		if _stick_finger != -1:
			_release_stick()
		_look_finger = -1


func _throw_button_center() -> Vector2:
	return size - throw_button_home


func _grab_button_center() -> Vector2:
	return size - grab_button_home


func _camera_button_rect() -> Rect2:
	var corner := Vector2(size.x - camera_button_margin.x - camera_button_size, camera_button_margin.y)
	return Rect2(corner, Vector2.ONE * camera_button_size)


func _draw() -> void:
	# Joystick: a faint ring with a knob that follows the thumb.
	var center := _stick_center
	if _stick_finger == -1:
		center = Vector2(joystick_home.x, size.y - joystick_home.y)
	var idle_alpha := 1.0 if _stick_finger != -1 else 0.6
	draw_circle(center, joystick_radius, Color(1, 1, 1, 0.10 * idle_alpha))
	draw_arc(center, joystick_radius, 0.0, TAU, 48, Color(1, 1, 1, 0.35 * idle_alpha), 3.0, true)
	draw_circle(center + _stick_vector * joystick_radius, knob_radius, Color(1, 1, 1, 0.45 * idle_alpha))

	# Camera icon: a round button with a simple camera drawn on it.
	var rect := _camera_button_rect()
	var c := rect.get_center()
	var s := camera_button_size / 84.0
	draw_circle(c, camera_button_size * 0.5, Color(0, 0, 0, 0.35))
	draw_arc(c, camera_button_size * 0.5, 0.0, TAU, 48, Color(1, 1, 1, 0.5), 2.0, true)
	var icon := Color(1, 1, 1, 0.9)
	draw_rect(Rect2(c + Vector2(-22, -12) * s, Vector2(44, 30) * s), icon)
	draw_rect(Rect2(c + Vector2(-8, -18) * s, Vector2(16, 7) * s), icon)
	draw_circle(c + Vector2(0, 3) * s, 9.0 * s, Color(0.1, 0.1, 0.12, 0.95))
	draw_circle(c + Vector2(0, 3) * s, 5.0 * s, Color(1, 1, 1, 0.5))

	# Throw button, with a knife drawn on it.
	var throw_center := _throw_button_center()
	var throw_alpha := 1.0 if throw_enabled else 0.35
	_draw_round_button(throw_center, throw_button_radius, "THROW", throw_alpha)
	var k := throw_button_radius / 62.0
	var blade := PackedVector2Array([
		throw_center + Vector2(-4, -6) * k, throw_center + Vector2(4, -6) * k,
		throw_center + Vector2(0, -34) * k,
	])
	draw_colored_polygon(blade, Color(1, 1, 1, 0.9 * throw_alpha))
	draw_rect(Rect2(throw_center + Vector2(-11, -7) * k, Vector2(22, 4) * k), Color(1, 1, 1, 0.9 * throw_alpha))
	draw_rect(Rect2(throw_center + Vector2(-3, -3) * k, Vector2(6, 12) * k), Color(1, 1, 1, 0.9 * throw_alpha))

	if grab_visible:
		_draw_round_button(_grab_button_center(), grab_button_radius, "GRAB", 1.0)


func _draw_round_button(center: Vector2, radius: float, label: String, alpha: float) -> void:
	draw_circle(center, radius, Color(0, 0, 0, 0.35 * alpha))
	draw_arc(center, radius, 0.0, TAU, 48, Color(1, 1, 1, 0.55 * alpha), 2.5, true)
	var font := get_theme_default_font()
	var font_size := 18
	var width := radius * 2.0
	var baseline := center + Vector2(-radius, radius * 0.55)
	draw_string(font, baseline, label, HORIZONTAL_ALIGNMENT_CENTER, width, font_size, Color(1, 1, 1, 0.95 * alpha))
