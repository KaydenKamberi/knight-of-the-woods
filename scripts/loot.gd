extends Node3D
## A piece of loot (PRD R-13). It pops out of a defeated dummy, lands, then
## bobs and spins on the ground. When the knight comes close it drifts towards
## him, and walking over it puts it in the inventory. All on world time.

const Config := preload("res://scripts/game_config.gd")
const Art := preload("res://scripts/art.gd")
const Pool := preload("res://scripts/pool.gd")
## Loot closer than this (metres) drifts towards the knight.
const MAGNET_RANGE := 2.5
const MAGNET_SPEED := 6.0
const RESTING_HEIGHT := 0.2
const GRAVITY := 12.0

var material_id := "wood"

var _velocity := Vector3.ZERO
var _landed := false
var _age := 0.0
var _model: Node3D
var _knight: Node3D = null


## Call right after adding the loot to the scene.
func setup(id: String, start: Vector3, launch_velocity: Vector3) -> void:
	material_id = id
	global_position = start
	_velocity = launch_velocity
	_landed = false
	_age = 0.0
	set_physics_process(true)
	# A reused piece of loot may have been something else last time.
	if is_instance_valid(_model):
		_model.free()
	_model = Node3D.new()
	add_child(_model)
	_build_model()


func _physics_process(delta: float) -> void:
	_age += delta
	if not _landed:
		_velocity.y -= GRAVITY * delta
		global_position += _velocity * delta
		if global_position.y <= RESTING_HEIGHT and _velocity.y < 0.0:
			global_position.y = RESTING_HEIGHT
			_landed = true
	else:
		_model.position.y = sin(_age * 3.0) * 0.06
	_model.rotate_y(1.5 * delta)

	if _knight == null:
		_knight = get_tree().get_first_node_in_group("player") as Node3D
		if _knight == null:
			return
	var to_knight := _knight.global_position + Vector3.UP * 0.5 - global_position
	var distance := to_knight.length()
	if distance < Config.LOOT_PICKUP_RANGE:
		var inventory = get_tree().get_first_node_in_group("inventory")
		if inventory != null:
			inventory.add(material_id)
		# Stop here and go back to the pool at the end of the frame.
		set_physics_process(false)
		_return_to_pool.call_deferred()
	elif _landed and distance < MAGNET_RANGE:
		global_position += to_knight.normalized() * minf(MAGNET_SPEED * delta, distance)


func _build_model() -> void:
	match material_id:
		"wood":
			var log_mesh := CylinderMesh.new()
			log_mesh.top_radius = 0.08
			log_mesh.bottom_radius = 0.08
			log_mesh.height = 0.36
			log_mesh.radial_segments = 6
			log_mesh.rings = 0
			_add(log_mesh, Color(0.48, 0.32, 0.18), Basis(Vector3.RIGHT, PI / 2.0))
		"stone":
			_add(_rock(0.13), Color(0.55, 0.55, 0.53))
		"coal":
			_add(_rock(0.12), Color(0.1, 0.1, 0.11))
		"raw_iron":
			var lump := BoxMesh.new()
			lump.size = Vector3(0.18, 0.13, 0.15)
			_add(lump, Color(0.5, 0.36, 0.3), Basis.from_euler(Vector3(0.3, 0.4, 0.2)), 0.4)
		"iron":
			var bar := BoxMesh.new()
			bar.size = Vector3(0.24, 0.07, 0.11)
			_add(bar, Color(0.75, 0.77, 0.8), Basis.IDENTITY, 0.7)
		"string":
			var spool := TorusMesh.new()
			spool.inner_radius = 0.04
			spool.outer_radius = 0.1
			spool.rings = 8
			spool.ring_segments = 6
			_add(spool, Color(0.92, 0.88, 0.76), Basis(Vector3.RIGHT, PI / 2.0))
		"cryo":
			_add_crystal(Color(0.55, 0.85, 1.0), 0.22)
		"gunpowder":
			# A small black pouch tied at the top.
			_add(_rock(0.12), Color(0.18, 0.17, 0.17))
			var tie := BoxMesh.new()
			tie.size = Vector3(0.07, 0.07, 0.07)
			_add(tie, Color(0.8, 0.7, 0.45), Basis.IDENTITY, 0.0, Vector3(0, 0.14, 0))
		"meat":
			# A drumstick: a meaty lump on a bone.
			var lump := SphereMesh.new()
			lump.radius = 0.11
			lump.height = 0.2
			lump.radial_segments = 6
			lump.rings = 3
			_add(lump, Color(0.72, 0.28, 0.22), Basis.from_scale(Vector3(1.0, 0.85, 1.25)))
			var bone := BoxMesh.new()
			bone.size = Vector3(0.05, 0.05, 0.18)
			_add(bone, Color(0.95, 0.92, 0.84), Basis.IDENTITY, 0.0, Vector3(0, 0, 0.17))
		"berries":
			for i in 3:
				var berry := SphereMesh.new()
				berry.radius = 0.06
				berry.height = 0.12
				berry.radial_segments = 6
				berry.rings = 3
				var angle := TAU * i / 3.0
				_add(berry, Config.PALETTE["berry"], Basis.IDENTITY, 0.0, Vector3(cos(angle), 0.0, sin(angle)) * 0.06)
		"diamond":
			_add_crystal(Color(0.85, 0.97, 1.0), 0.26)
		"titanium":
			var ingot := BoxMesh.new()
			ingot.size = Vector3(0.26, 0.08, 0.12)
			_add(ingot, Color(0.62, 0.68, 0.78), Basis.IDENTITY, 0.8)
		"ultra":
			_add_crystal(Color(0.8, 0.35, 1.0), 0.3)
			var light := OmniLight3D.new()
			light.light_color = Color(0.8, 0.4, 1.0)
			light.omni_range = 2.5
			_model.add_child(light)


func _rock(radius: float) -> SphereMesh:
	var rock := SphereMesh.new()
	rock.radius = radius
	rock.height = radius * 1.6
	rock.radial_segments = 6
	rock.rings = 3
	return rock


## A glowing two-pointed crystal.
func _add_crystal(color: Color, height: float) -> void:
	for flip in [0.0, PI]:
		var half := PrismMesh.new()
		half.size = Vector3(height * 0.55, height * 0.5, height * 0.55)
		var turn := Basis(Vector3.RIGHT, flip)
		var offset := Vector3.UP * height * 0.25 * (1.0 if flip == 0.0 else -1.0)
		_add(half, color, turn, 0.2, offset, true)


func _add(mesh: PrimitiveMesh, color: Color, turn := Basis.IDENTITY, metallic := 0.0,
		offset := Vector3.ZERO, glow := false) -> void:
	# Shiny metals and glowing crystals catch the eye with a rim light or a glow.
	var options := {"rim": metallic > 0.0 or glow}
	if glow:
		options["emission"] = color
		options["energy"] = 1.5
	mesh.material = Art.material(color, options)
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.transform = Transform3D(turn, offset)
	_model.add_child(instance)


func _return_to_pool() -> void:
	Pool.give_back("loot", self)
