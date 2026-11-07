extends Node3D
## A thrown grenade (PRD G-3). It flies in an arc on world time and explodes
## where it lands.
##
## Every regular enemy in the blast is destroyed. Bosses are tougher: a mini boss
## loses 1 / (its wave × 2) of its health, so wave n's mini boss takes 2 × n
## grenades, and the big boss loses 1 / 40. Only enemies (the "dummies" group)
## are hit, so the knight, his soldiers and tamed animals are always safe.

const Config := preload("res://scripts/game_config.gd")
const Art := preload("res://scripts/art.gd")
const Fx := preload("res://scripts/fx.gd")
## The ray only hits the world, enemies and debris (never the knight or allies).
const HIT_MASK := 1 | 8 | 16
const GRAVITY := 12.0

var velocity := Vector3.ZERO
var _age := 0.0
var _spin := Vector3.ZERO


func _ready() -> void:
	var body := SphereMesh.new()
	body.radius = 0.11
	body.height = 0.2
	body.radial_segments = 8
	body.rings = 4
	body.material = Art.material(Color(0.22, 0.24, 0.2), {"rim": true})
	var mesh := MeshInstance3D.new()
	mesh.mesh = body
	add_child(mesh)
	var fuse := BoxMesh.new()
	fuse.size = Vector3(0.05, 0.08, 0.05)
	fuse.material = Art.material(Color(1.0, 0.6, 0.2), {"emission": Color(1.0, 0.5, 0.1), "energy": 2.0})
	var fuse_mesh := MeshInstance3D.new()
	fuse_mesh.mesh = fuse
	fuse_mesh.position = Vector3(0, 0.12, 0)
	add_child(fuse_mesh)
	_spin = Vector3(randf_range(-8, 8), randf_range(-8, 8), randf_range(-8, 8))


func launch(from: Vector3, launch_velocity: Vector3) -> void:
	global_position = from
	velocity = launch_velocity


func _physics_process(delta: float) -> void:
	_age += delta
	if _age > 8.0:
		_explode(global_position)
		return
	velocity.y -= GRAVITY * delta
	rotation += _spin * delta
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
	Fx.grenade_blast(at, Config.GRENADE_BLAST_RADIUS, get_tree().current_scene)
	var enemies: Array = get_tree().get_nodes_in_group("dummies")
	for enemy in enemies:
		if not enemy.is_alive():
			continue
		var body_middle: Vector3 = enemy.global_position + Vector3.UP * enemy.size_scale
		if body_middle.distance_to(at) > Config.GRENADE_BLAST_RADIUS + 0.4 * enemy.size_scale:
			continue
		enemy.take_hit(damage_for(enemy), at, 9.0)
	WorldTime.bump()
	queue_free()


## How much one grenade takes off `enemy` (G-3).
static func damage_for(enemy) -> int:
	if enemy.is_big_boss:
		return ceili(float(enemy.max_health) / Config.BIG_BOSS_GRENADES)
	if enemy.is_mini_boss:
		var grenades := maxi(enemy.boss_wave, 1) * Config.GRENADES_PER_WAVE_OF_BOSS
		return ceili(float(enemy.max_health) / grenades)
	return enemy.health  # Regular enemies are destroyed outright.
