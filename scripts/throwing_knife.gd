extends Node3D
## A thrown knife (PRD W-3, W-4).
##
## It flies where the knight aimed, drops a little, and spins end over end.
## All of that is worked out from the physics delta, so it slows down with
## world time. Each step it looks ahead with a ray. When the ray hits
## something, the knife sticks in it, does damage if it's a dummy, and becomes
## a pickup the knight can grab again.
##
## The knife's origin is the guard. The blade points along -Z.

## Physics layers a knife can hit: world (1), dummies (4) and debris (5).
## It flies through the knight (2) and the invisible edge wall (3).
const HIT_MASK := 1 | 8 | 16
## Distance from the guard to the tip of the blade, in metres.
const BLADE_LENGTH := 0.25

@export var speed := 26.0
## How fast the knife drops while flying, in metres per second per second.
@export var drop := 4.0
## Spin speed in radians per second.
@export var spin_speed := 22.0
@export var damage := 50
## Speed added to whatever loose body the knife hits, in metres per second.
@export var hit_push := 5.0
## How deep the blade sinks into what it hits, in metres.
@export var sink_depth := 0.1
## A knife that hits nothing for this long (world seconds) goes back to an empty poster.
@export var max_flight_time := 5.0

var velocity := Vector3.ZERO

var _flying := false
var _flight_time := 0.0

@onready var _spinner: Node3D = $Spinner


## Starts the knife flying from `from` in `direction`. Call after adding it to the scene.
func launch(from: Vector3, direction: Vector3) -> void:
	global_position = from
	velocity = direction.normalized() * speed
	_face(velocity)
	_flying = true


func _physics_process(delta: float) -> void:
	if not _flying:
		return
	_flight_time += delta
	if _flight_time > max_flight_time:
		_flying = false
		_return_to_a_poster()
		return

	velocity.y -= drop * delta
	var direction := velocity.normalized()
	var start := global_position
	var step := velocity * delta
	# Look ahead as far as the tip will reach this step.
	var query := PhysicsRayQueryParameters3D.create(start, start + step + direction * BLADE_LENGTH, HIT_MASK)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		global_position = start + step
		_face(velocity)
		_spinner.rotate_x(-spin_speed * delta)
		return

	# Stick: blade pointing the way it flew, tip buried sink_depth deep.
	_flying = false
	var point: Vector3 = hit["position"]
	global_position = point - direction * (BLADE_LENGTH - sink_depth)
	_face(direction)
	_spinner.rotation = Vector3.ZERO
	# Handle the hit after the physics step, since it can turn a dummy into a ragdoll.
	_on_hit.call_deferred(hit["collider"], point, direction)


# --- Pickup (the knight looks for nodes in the "knife_pickups" group) -------

func can_be_picked_up() -> bool:
	return not _flying and is_inside_tree()


func pickup_point() -> Vector3:
	return global_position


func pickup_prompt() -> String:
	return "Pick up the knife"


func pick_up() -> void:
	queue_free()


# -----------------------------------------------------------------------------

func _on_hit(collider: Object, point: Vector3, direction: Vector3) -> void:
	var stick_to: Node = null
	if is_instance_valid(collider):
		var target = _damage_target(collider)
		if target != null:
			# The target decides which of its parts the knife sticks in.
			stick_to = target.take_knife_hit(collider, point, direction, damage, hit_push)
			if stick_to is Node3D:
				_sink_towards((stick_to as Node3D).global_position, direction)
		elif collider is RigidBody3D:
			var loose_body := collider as RigidBody3D
			loose_body.apply_impulse(direction * hit_push * loose_body.mass * 0.2, point - loose_body.global_position)
		if stick_to == null:
			stick_to = collider as Node
	if stick_to != null:
		# Riding along with whatever it hit: a swinging log, a ragdoll piece, a tree.
		reparent(stick_to, true)
	add_to_group("knife_pickups")


## Slides the knife forward along its flight line until the tip is just short of
## `center`. A walking dummy is hit on its collision capsule, which is wider than
## its body, so this pushes the blade into the body part it struck.
func _sink_towards(center: Vector3, direction: Vector3) -> void:
	var tip_depth := (center - global_position).dot(direction) - 0.05
	if tip_depth > BLADE_LENGTH:
		global_position += direction * (tip_depth - BLADE_LENGTH)


## Returns the thing that should take damage from this hit, or null.
func _damage_target(collider: Object):
	if collider.has_method("take_knife_hit"):
		return collider
	if collider.has_meta("dummy"):
		var dummy = collider.get_meta("dummy")
		if is_instance_valid(dummy):
			return dummy
	return null


## Knives that fly off into nothing go back to a poster, so they're never lost for good.
func _return_to_a_poster() -> void:
	var empty_posters := get_tree().get_nodes_in_group("wanted_posters").filter(
			func(poster) -> bool: return not poster.has_knife)
	if not empty_posters.is_empty():
		empty_posters.pick_random().rearm()
	queue_free()


func _face(direction: Vector3) -> void:
	if direction.length_squared() < 0.0001:
		return
	var up := Vector3.UP if absf(direction.normalized().y) < 0.98 else Vector3.FORWARD
	global_basis = Basis.looking_at(direction, up)
