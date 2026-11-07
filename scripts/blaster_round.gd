extends Node3D
## A round from the Ultra blaster (PRD R-12, R-17). It's lobbed like a grenade,
## falls on world time, and explodes where it lands, hitting every enemy in
## the blast with BLASTER damage. Mini bosses go down in one hit (R-17).

const Config := preload("res://scripts/game_config.gd")
const Effects := preload("res://scripts/effects.gd")
const HIT_MASK := 1 | 8 | 16
const GRAVITY := 9.8
const COLOR := Color(0.8, 0.35, 1.0)

var velocity := Vector3.ZERO
var _age := 0.0


func _ready() -> void:
	var material := StandardMaterial3D.new()
	material.albedo_color = COLOR
	material.emission_enabled = true
	material.emission = COLOR
	material.emission_energy_multiplier = 2.0
	var sphere := SphereMesh.new()
	sphere.radius = 0.12
	sphere.height = 0.24
	sphere.radial_segments = 8
	sphere.rings = 4
	sphere.material = material
	var mesh := MeshInstance3D.new()
	mesh.mesh = sphere
	add_child(mesh)


func launch(from: Vector3, launch_velocity: Vector3) -> void:
	global_position = from
	velocity = launch_velocity


func _physics_process(delta: float) -> void:
	_age += delta
	if _age > 8.0:
		_explode(global_position)
		return
	velocity.y -= GRAVITY * delta
	var start := global_position
	var step := velocity * delta
	var query := PhysicsRayQueryParameters3D.create(start, start + step, HIT_MASK)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		global_position = start + step
	else:
		_explode(hit["position"])


func _explode(at: Vector3) -> void:
	set_physics_process(false)
	Effects.burst(at, Config.BLASTER_BLAST_RADIUS, COLOR, get_tree().current_scene)
	var damage: int = Config.WEAPONS["ultra_blaster"]["damage"]
	var enemies: Array = get_tree().get_nodes_in_group("dummies")
	for enemy in enemies:
		if not enemy.is_alive():
			continue
		var body_middle: Vector3 = enemy.global_position + Vector3.UP
		if body_middle.distance_to(at) <= Config.BLASTER_BLAST_RADIUS:
			# R-17: one blaster hit defeats any regular dummy or mini boss.
			enemy.take_hit(maxi(damage, enemy.health), at, 9.0)
	WorldTime.bump()
	queue_free()
