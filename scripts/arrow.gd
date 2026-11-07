extends Node3D
## An arrow from a soldier's bow (A-6), and later the knight's bow.
##
## Like the throwing knife, it flies and drops on world time, looks ahead with a
## ray each physics step, and sticks in what it hits. Its ray only hits the
## world, dummies and debris (layers 1, 4 and 5), so arrows never hit the knight
## or his soldiers. Stuck arrows fade away after a while; they aren't pickups.
##
## The arrow's origin is its tip, and the shaft runs back along +Z.

const Config := preload("res://scripts/game_config.gd")
const HIT_MASK := 1 | 8 | 16

@export var speed := Config.ARROW_SPEED
## How fast the arrow drops while flying, in metres per second per second.
@export var drop := 6.0
@export var damage := 20
@export var hit_push := 3.0
## Seconds (world time) before an arrow that hit nothing, or a stuck one, disappears.
@export var flight_lifetime := 4.0
@export var stuck_lifetime := 6.0

var velocity := Vector3.ZERO

var _flying := false
var _age := 0.0


## Starts the arrow flying from `from` in `direction`. Call after adding it to the scene.
func launch(from: Vector3, direction: Vector3, arrow_damage: int) -> void:
	damage = arrow_damage
	global_position = from
	velocity = direction.normalized() * speed
	_face(velocity)
	_flying = true


func _physics_process(delta: float) -> void:
	_age += delta
	if not _flying:
		if _age > stuck_lifetime:
			queue_free()
		return
	if _age > flight_lifetime:
		queue_free()
		return

	velocity.y -= drop * delta
	var start := global_position
	var step := velocity * delta
	var query := PhysicsRayQueryParameters3D.create(start, start + step, HIT_MASK)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		global_position = start + step
		_face(velocity)
		return

	_flying = false
	_age = 0.0
	var direction := velocity.normalized()
	var point: Vector3 = hit["position"]
	global_position = point + direction * 0.06
	_on_hit.call_deferred(hit["collider"], point, direction)


func _on_hit(collider: Object, point: Vector3, direction: Vector3) -> void:
	if not is_instance_valid(collider):
		return
	var stick_to: Node = collider as Node
	var target = null
	if collider.has_method("take_projectile_hit"):
		target = collider
	elif collider.has_meta("dummy") and is_instance_valid(collider.get_meta("dummy")):
		target = collider.get_meta("dummy")
	if target != null:
		stick_to = target.take_projectile_hit(collider, point, direction, damage, hit_push)
	if stick_to != null:
		reparent(stick_to, true)


func _face(direction: Vector3) -> void:
	if direction.length_squared() < 0.0001:
		return
	var up := Vector3.UP if absf(direction.normalized().y) < 0.98 else Vector3.FORWARD
	global_basis = Basis.looking_at(direction, up)
