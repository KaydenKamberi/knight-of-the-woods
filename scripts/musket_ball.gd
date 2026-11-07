extends Node3D
## A heavy ball from the musket (PRD G-1, G-2).
##
## It flies fast where the knight aimed, drops a little, and runs on world time
## like knives and arrows, so in slow motion you can watch it travel. It hits
## the first enemy (or wild animal) in its way for the musket's damage, then is
## gone. A shot rolled as a critical hit does double damage and shows "CRIT!".
## Its ray only hits the world, enemies and debris, never the knight or allies.

const Config := preload("res://scripts/game_config.gd")
const Art := preload("res://scripts/art.gd")
const Fx := preload("res://scripts/fx.gd")
const HIT_MASK := 1 | 8 | 16
const DROP := 2.0
const LIFETIME := 3.0
const PUSH := 6.0

var velocity := Vector3.ZERO
var damage := 90
var crit := false
var _age := 0.0


func _ready() -> void:
	var ball := SphereMesh.new()
	ball.radius = 0.06
	ball.height = 0.12
	ball.radial_segments = 6
	ball.rings = 3
	ball.material = Art.material(Color(0.25, 0.25, 0.28), {"rim": true})
	var mesh := MeshInstance3D.new()
	mesh.mesh = ball
	add_child(mesh)


## Call right after adding the ball to the scene.
func launch(from: Vector3, direction: Vector3, ball_damage: int, is_crit: bool) -> void:
	global_position = from
	velocity = direction.normalized() * Config.MUSKET_BALL_SPEED
	damage = ball_damage
	crit = is_crit


func _physics_process(delta: float) -> void:
	_age += delta
	if _age > LIFETIME:
		queue_free()
		return
	velocity.y -= DROP * delta
	var start := global_position
	var step := velocity * delta
	var query := PhysicsRayQueryParameters3D.create(start, start + step, HIT_MASK)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		global_position = start + step
		return
	set_physics_process(false)
	_on_hit.call_deferred(hit["collider"], hit["position"], velocity.normalized())


func _on_hit(collider: Object, point: Vector3, direction: Vector3) -> void:
	var target = null
	if is_instance_valid(collider):
		if collider.has_method("take_projectile_hit"):
			target = collider
		elif collider.has_meta("dummy") and is_instance_valid(collider.get_meta("dummy")):
			target = collider.get_meta("dummy")
	if target != null:
		if crit:
			Fx.crit(point)
		target.take_projectile_hit(collider, point, direction, damage, PUSH)
	else:
		Fx.dust(point)
	queue_free()
