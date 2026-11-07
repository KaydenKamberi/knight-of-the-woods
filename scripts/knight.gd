extends CharacterBody3D
## The player's knight.
##
## Walks with WASD or the touch joystick, looks around with the mouse or by
## dragging on the right half of the screen, and switches between a camera
## behind the knight and a view from inside the helmet (PRD C-1 to C-3).
##
## Moving and looking around wake up world time (T-2, K-2). Camera look is
## applied the moment input arrives and never scaled by delta, so it stays
## responsive even while the world is slowed (T-4).
##
## The knight pulls throwing knives from wanted posters, carries a few, and
## throws them at the crosshair (W-2 to W-4). Dummies' hits lower his health,
## and at zero he falls and the run ends (E-3).

## Sent whenever the view changes. true means first person (inside the helmet).
signal view_changed(first_person: bool)
signal health_changed(health: int, max_health: int)
signal knives_changed(count: int, max_count: int)
## Sent when a knife comes into or goes out of reach. prompt is "" when there's nothing to grab.
signal pickup_changed(prompt: String)
## Sent once the knight has fallen over at zero health.
signal died

## The render layer the knight's own meshes are on (see Project Settings >
## Layer Names > 3D Render). The first-person camera hides this layer so the
## inside of the helmet doesn't block the view.
const KNIGHT_RENDER_LAYER := 2
## Horizontal speed (metres per second) above which the knight counts as moving for world time.
const STILL_SPEED := 0.2
const KNIFE_SCENE := preload("res://scenes/throwing_knife.tscn")
## Physics layers the aim ray can hit: world (1), dummies (4) and debris (5).
const AIM_MASK := 1 | 8 | 16
## Seconds the throwing arm takes to come down after a throw.
const THROW_ANIMATION_TIME := 0.25

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
## How long the camera takes to glide between views, in real seconds.
@export var switch_time := 0.15

@export_group("Combat")
@export var max_health := 100
## How many knives the knight can carry at once.
@export var max_knives := 3
## How close (in metres) a knife has to be to grab it.
@export var pickup_range := 2.0
## Real seconds world time keeps running after a throw or a grab (T-2).
@export var action_time := 0.3
## How hard a dummy's hit shoves the knight back, in metres per second.
@export var knockback_speed := 4.0
## How far the aim ray reaches, in metres.
@export var aim_distance := 60.0

var first_person := false
var health := 0
var knives := 0

var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var _pitch := deg_to_rad(-15.0)
var _touch_mode := false
var _walk_cycle := 0.0
var _view_tween: Tween
var _dead := false
var _throw_animation_left := 0.0
## The poster or knife currently in reach (untyped: it can be either script).
var _pickup_in_reach = null

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
	add_to_group("player")
	health = max_health
	_arm.spring_length = third_person_distance
	_pitch_pivot.position.y = third_person_height
	_pitch_pivot.rotation.x = _pitch
	_set_helmet_view(false)
	# Wait until the whole scene is ready, so the HUD is there to hear it.
	_announce_status.call_deferred()


func _unhandled_input(event: InputEvent) -> void:
	if _dead:
		return
	if event.is_action_pressed("switch_camera"):
		toggle_view()
	elif event.is_action_pressed("interact"):
		pick_up_knife()
	elif event.is_action_pressed("pause"):
		# Esc frees the mouse. The pause menu itself comes in a later milestone.
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif event is InputEventMouseButton:
		_on_mouse_button(event)
	elif event.is_action_pressed("throw"):
		# The touch Throw button sends the action directly.
		throw_knife()
	elif event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		add_look_input(event.screen_relative * mouse_sensitivity)


func _on_mouse_button(event: InputEventMouseButton) -> void:
	# Taps on a touch screen also arrive as "emulated" mouse clicks; ignore those,
	# or every tap would throw a knife.
	if not event.pressed or _touch_mode or event.device == InputEvent.DEVICE_ID_EMULATION:
		return
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		# The first click only captures the mouse for looking around.
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	elif event.is_action_pressed("throw"):
		throw_knife()


func _process(_delta: float) -> void:
	if _dead:
		return
	_update_pickup_in_reach()
	# Walking (keys or joystick), still sliding to a stop, or falling all keep world time running.
	var wants_to_move := Input.get_vector("move_left", "move_right", "move_forward", "move_back") != Vector2.ZERO
	var still_moving := Vector2(velocity.x, velocity.z).length() > STILL_SPEED or not is_on_floor()
	if wants_to_move or still_moving:
		WorldTime.report_activity()


func _physics_process(delta: float) -> void:
	# Movement is relative to where the camera is facing. A fallen knight can't move.
	var input := Vector2.ZERO
	if not _dead:
		input = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction := _yaw.global_basis * Vector3(input.x, 0.0, input.y)
	var target := direction * walk_speed

	velocity.x = move_toward(velocity.x, target.x, acceleration * delta)
	velocity.z = move_toward(velocity.z, target.z, acceleration * delta)
	if is_on_floor():
		velocity.y = 0.0
	else:
		velocity.y -= _gravity * delta
	move_and_slide()

	if not _dead:
		_update_facing(direction, delta)
		_animate_walk(delta)


func is_alive() -> bool:
	return not _dead


## Called by dummies when their swing lands. `from` is where the hit came from.
func take_damage(amount: int, from: Vector3) -> void:
	if _dead:
		return
	health = maxi(health - amount, 0)
	health_changed.emit(health, max_health)
	var away := global_position - from
	away.y = 0.0
	if away.length_squared() > 0.0001:
		velocity += away.normalized() * knockback_speed
	if health == 0:
		_die()


## Throws a knife at whatever is under the crosshair (W-3).
func throw_knife() -> void:
	if _dead or knives <= 0:
		return
	_set_knives(knives - 1)
	WorldTime.report_activity(action_time)

	var forward := -_camera.global_basis.z
	var start := _throw_start()
	var direction := _aim_point() - start
	# Don't throw backwards when the aim lands between the camera and the knight.
	if direction.length() < 1.0 or direction.normalized().dot(forward) < 0.3:
		direction = forward
	var knife = KNIFE_SCENE.instantiate()
	get_parent().add_child(knife)
	knife.launch(start, direction)
	_throw_animation_left = THROW_ANIMATION_TIME


## Grabs the knife in reach, from a poster or wherever a thrown one stuck (W-2, W-4).
func pick_up_knife() -> void:
	if _dead or knives >= max_knives or not is_instance_valid(_pickup_in_reach):
		return
	if not _pickup_in_reach.can_be_picked_up():
		return
	_pickup_in_reach.pick_up()
	# A picked-up thrown knife is deleted, so forget it now. The next frame finds whatever else is in reach.
	_pickup_in_reach = null
	pickup_changed.emit("")
	_set_knives(knives + 1)
	WorldTime.report_activity(action_time)


## Turns the camera. x is left/right, y is up/down, both in radians.
func add_look_input(amount: Vector2) -> void:
	if amount == Vector2.ZERO:
		return
	WorldTime.report_activity()
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
	# The camera is the player's, not the world's, so the glide ignores world time.
	_view_tween.set_ignore_time_scale(true)

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


func _announce_status() -> void:
	health_changed.emit(health, max_health)
	knives_changed.emit(knives, max_knives)
	pickup_changed.emit("")


func _set_knives(count: int) -> void:
	knives = count
	knives_changed.emit(knives, max_knives)


## Finds the nearest knife the knight could grab, and tells the HUD when that changes.
func _update_pickup_in_reach() -> void:
	var nearest = null
	if knives < max_knives:
		var nearest_distance := pickup_range
		var hands := global_position + Vector3.UP
		var pickups: Array = get_tree().get_nodes_in_group("knife_pickups")
		for pickup in pickups:
			if not pickup.can_be_picked_up():
				continue
			var distance: float = hands.distance_to(pickup.pickup_point())
			if distance < nearest_distance:
				nearest = pickup
				nearest_distance = distance
	if nearest != _pickup_in_reach:
		_pickup_in_reach = nearest
		pickup_changed.emit("" if nearest == null else nearest.pickup_prompt())


## The point in the world under the crosshair (the middle of the screen).
func _aim_point() -> Vector3:
	var middle := get_viewport().get_visible_rect().size * 0.5
	var origin := _camera.project_ray_origin(middle)
	var end := origin + _camera.project_ray_normal(middle) * aim_distance
	var query := PhysicsRayQueryParameters3D.create(origin, end, AIM_MASK)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return end
	return hit["position"]


## Where a thrown knife leaves the knight: by the right shoulder, or just below the eye slit.
func _throw_start() -> Vector3:
	var view := _camera.global_basis
	if first_person:
		return _camera.global_position - view.z * 0.4 - view.y * 0.12 + view.x * 0.15
	return global_position + Vector3(0.0, 1.45, 0.0) - view.z * 0.45 + view.x * 0.25


func _die() -> void:
	_dead = true
	_pickup_in_reach = null
	pickup_changed.emit("")
	if first_person:
		toggle_view()  # Back to third person so the player sees the knight fall.
	var fall := create_tween().set_ignore_time_scale(true)
	fall.tween_property(_model, "rotation:x", PI * 0.5, 0.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	fall.tween_interval(0.5)
	fall.tween_callback(func() -> void: died.emit())


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
	if _throw_animation_left > 0.0:
		# The throwing arm starts raised and swings down.
		_throw_animation_left = maxf(_throw_animation_left - delta, 0.0)
		_right_arm.rotation.x = 2.8 * _throw_animation_left / THROW_ANIMATION_TIME
