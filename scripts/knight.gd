extends CharacterBody3D
## The player's knight.
##
## Walks with WASD or the touch joystick, looks around with the mouse or by
## dragging on the right half of the screen, and switches between a camera
## behind the knight and a view from inside the helmet (PRD C-1 to C-3).

## Sent whenever the view changes. true means first person (inside the helmet).
signal view_changed(first_person: bool)

## The render layer the knight's own meshes are on (see Project Settings >
## Layer Names > 3D Render). The first-person camera hides this layer so the
## inside of the helmet doesn't block the view.
const KNIGHT_RENDER_LAYER := 2

@export var walk_speed := 5.0
## How quickly the knight speeds up and slows down, in metres per second per second.
@export var acceleration := 30.0
## How quickly the knight turns to face the way he's walking (third person).
@export var turn_speed := 12.0

@export_group("Camera")
## Radians turned per pixel of mouse movement.
@export var mouse_sensitivity := 0.0025
## Radians turned per pixel dragged on a touch screen.
@export var touch_sensitivity := 0.005
@export var third_person_distance := 4.0
@export var third_person_height := 1.7
## Eye height inside the helmet, lined up with the eye slit on the model.
@export var first_person_height := 1.66
## How far down and up the camera can tilt, in degrees.
@export var third_person_pitch_limits := Vector2(-70.0, 35.0)
@export var first_person_pitch_limits := Vector2(-85.0, 85.0)
## How long the camera takes to glide between views, in seconds.
@export var switch_time := 0.15

var first_person := false

var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var _pitch := deg_to_rad(-15.0)
var _touch_mode := false
var _walk_cycle := 0.0
var _view_tween: Tween

@onready var _model: Node3D = $Model
@onready var _left_leg: Node3D = $Model/LeftLeg
@onready var _right_leg: Node3D = $Model/RightLeg
@onready var _left_arm: Node3D = $Model/LeftArm
@onready var _right_arm: Node3D = $Model/RightArm
@onready var _yaw: Node3D = $CameraYaw
@onready var _pitch_pivot: Node3D = $CameraYaw/CameraPitch
@onready var _arm: SpringArm3D = $CameraYaw/CameraPitch/SpringArm3D
@onready var _camera: Camera3D = $CameraYaw/CameraPitch/SpringArm3D/Camera3D
@onready var _eye_slit: CanvasItem = $HelmetView/EyeSlit


func _ready() -> void:
	_arm.spring_length = third_person_distance
	_pitch_pivot.position.y = third_person_height
	_pitch_pivot.rotation.x = _pitch
	_set_helmet_view(false)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("switch_camera"):
		toggle_view()
	elif event.is_action_pressed("pause"):
		# Esc frees the mouse. The pause menu itself comes in a later milestone.
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif event is InputEventMouseButton and event.pressed:
		# Clicking the game window captures the mouse for looking around.
		# Taps on a touch screen also arrive as "emulated" mouse clicks; ignore those.
		if not _touch_mode and event.device != InputEvent.DEVICE_ID_EMULATION:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	elif event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		add_look_input(event.screen_relative * mouse_sensitivity)


func _physics_process(delta: float) -> void:
	# Movement is relative to where the camera is facing.
	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction := _yaw.global_basis * Vector3(input.x, 0.0, input.y)
	var target := direction * walk_speed

	velocity.x = move_toward(velocity.x, target.x, acceleration * delta)
	velocity.z = move_toward(velocity.z, target.z, acceleration * delta)
	if is_on_floor():
		velocity.y = 0.0
	else:
		velocity.y -= _gravity * delta
	move_and_slide()

	_update_facing(direction, delta)
	_animate_walk(delta)


## Turns the camera. x is left/right, y is up/down, both in radians.
func add_look_input(amount: Vector2) -> void:
	_yaw.rotation.y -= amount.x
	_set_pitch(_pitch - amount.y)


## Drag distance from the touch controls, in screen pixels.
func add_touch_look(relative: Vector2) -> void:
	add_look_input(relative * touch_sensitivity)


## Called by the HUD when the player switches between touch and mouse/keyboard.
func set_touch_mode(enabled: bool) -> void:
	_touch_mode = enabled
	if enabled and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


## Switches between third person (behind the knight) and first person (inside the helmet).
func toggle_view() -> void:
	first_person = not first_person
	if _view_tween:
		_view_tween.kill()
	_view_tween = create_tween().set_parallel().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	if first_person:
		# Glide into the helmet, then hide the knight's own model and show the eye slit.
		_view_tween.tween_property(_arm, "spring_length", 0.0, switch_time)
		_view_tween.tween_property(_pitch_pivot, "position:y", first_person_height, switch_time)
		_view_tween.chain().tween_callback(_set_helmet_view.bind(true))
	else:
		_set_helmet_view(false)
		_set_pitch(_pitch)
		_view_tween.tween_property(_arm, "spring_length", third_person_distance, switch_time)
		_view_tween.tween_property(_pitch_pivot, "position:y", third_person_height, switch_time)

	view_changed.emit(first_person)


func _set_pitch(value: float) -> void:
	var limits := first_person_pitch_limits if first_person else third_person_pitch_limits
	_pitch = clampf(value, deg_to_rad(limits.x), deg_to_rad(limits.y))
	_pitch_pivot.rotation.x = _pitch


func _set_helmet_view(enabled: bool) -> void:
	var knight_bit := 1 << (KNIGHT_RENDER_LAYER - 1)
	if enabled:
		_camera.cull_mask &= ~knight_bit
	else:
		_camera.cull_mask |= knight_bit
	_eye_slit.visible = enabled


func _update_facing(direction: Vector3, delta: float) -> void:
	if first_person:
		# In first person the body always faces where the player looks.
		_model.rotation.y = _yaw.rotation.y
	elif direction.length_squared() > 0.01:
		# The model faces -Z, so this angle turns -Z towards the walking direction.
		var target_angle := atan2(-direction.x, -direction.z)
		_model.rotation.y = lerp_angle(_model.rotation.y, target_angle, turn_speed * delta)


func _animate_walk(delta: float) -> void:
	# A simple swing of the arms and legs, scaled by how fast the knight is walking.
	var speed := Vector2(velocity.x, velocity.z).length()
	var amount := clampf(speed / walk_speed, 0.0, 1.0)
	_walk_cycle = fmod(_walk_cycle + delta * 9.0 * amount, TAU)
	var swing := sin(_walk_cycle) * 0.6 * amount
	_left_leg.rotation.x = swing
	_right_leg.rotation.x = -swing
	_left_arm.rotation.x = -swing * 0.7
	_right_arm.rotation.x = swing * 0.7
