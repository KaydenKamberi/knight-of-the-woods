extends Node3D
## The secret bunker (PRD B-1 to B-4), built from code like the castle.
##
## Two hidden entrances lead to the same small underground room:
## - a wooden trapdoor at the edge of the forest clearing, half covered by
##   leaves and a couple of bushes;
## - a loose stone in the inside of the castle's left (west) wall, a slightly
##   darker slab with a stone sticking out.
## Their prompts only show up close, so they're easy to walk past.
##
## The room is low-poly stone with wooden beams, crates and barrels, lit only by
## four flickering torches (the sun and sky light are turned down inside, see
## world_look.gd). A ladder climbs back up to the trapdoor and a tunnel leads to
## the castle. The chest at the back holds the game's only diamonds and titanium.
##
## The room really sits far outside the forest (BUNKER_CENTER), so nothing
## outside can see or reach it. Torches flicker on world time, like everything
## else. Sizes and spots live in game_config.gd.

const Config := preload("res://scripts/game_config.gd")
const Art := preload("res://scripts/art.gd")
const PASSAGE := preload("res://scripts/bunker_passage.gd")
const CHEST := preload("res://scripts/bunker_chest.gd")
const WALL := Color(0.42, 0.42, 0.45)
const WALL_DARK := Color(0.33, 0.33, 0.36)
const FLOOR := Color(0.36, 0.33, 0.3)
const WOOD: Color = Config.PALETTE["wood"]
const WOOD_DARK := Color(0.32, 0.21, 0.13)
const LEAF: Color = Config.PALETTE["leaf_1"]
const FLAME := Color(1.0, 0.62, 0.22)
const WALL_THICKNESS := 0.6

var _torch_lights: Array[OmniLight3D] = []
var _time := 0.0


func _ready() -> void:
	_build_room()
	_build_trapdoor()
	_build_castle_door()


func _process(delta: float) -> void:
	# Torches flicker, on world time.
	_time += delta
	for i in _torch_lights.size():
		_torch_lights[i].light_energy = 1.7 + 0.22 * sin(_time * 11.0 + i * 1.7) + 0.14 * sin(_time * 6.3 + i * 2.9)


## Where the knight comes out inside the bunker, at the ladder or at the tunnel.
static func ladder_arrival() -> Vector3:
	return Config.BUNKER_CENTER + Vector3(-Config.BUNKER_SIZE.x * 0.5 + 1.8, 0.0, 0.0)


static func tunnel_arrival() -> Vector3:
	return Config.BUNKER_CENTER + Vector3(Config.BUNKER_SIZE.x * 0.5 - 1.8, 0.0, 0.0)


# --- The room -------------------------------------------------------------------

func _build_room() -> void:
	var room := Node3D.new()
	room.name = "Room"
	room.position = Config.BUNKER_CENTER
	add_child(room)
	var walls := StaticBody3D.new()
	walls.name = "Walls"
	room.add_child(walls)
	var w := Config.BUNKER_SIZE.x
	var h := Config.BUNKER_SIZE.y
	var d := Config.BUNKER_SIZE.z
	var t := WALL_THICKNESS

	_box(room, Vector3(w + 2.0 * t, 0.1, d + 2.0 * t), Vector3(0, 0.05, 0), FLOOR)
	_solid(room, walls, Vector3(w + 2.0 * t, h, t), Vector3(0, h * 0.5, -d * 0.5 - t * 0.5), WALL)
	_solid(room, walls, Vector3(w + 2.0 * t, h, t), Vector3(0, h * 0.5, d * 0.5 + t * 0.5), WALL)
	_solid(room, walls, Vector3(t, h, d), Vector3(-w * 0.5 - t * 0.5, h * 0.5, 0), WALL)
	_solid(room, walls, Vector3(t, h, d), Vector3(w * 0.5 + t * 0.5, h * 0.5, 0), WALL)
	_solid(room, walls, Vector3(w + 2.0 * t, t, d + 2.0 * t), Vector3(0, h + t * 0.5, 0), WALL_DARK)
	# A darker band of stone along the bottom of the walls, and wooden ceiling beams.
	for z in [-d * 0.5 + 0.02, d * 0.5 - 0.02]:
		_box(room, Vector3(w, 0.4, 0.06), Vector3(0, 0.2, z), WALL_DARK)
	for z in [-2.6, 0.0, 2.6]:
		_box(room, Vector3(w, 0.22, 0.28), Vector3(0, h - 0.11, z), WOOD_DARK)

	for spot in [Vector3(-2.6, 2.1, -d * 0.5 + 0.12), Vector3(2.6, 2.1, -d * 0.5 + 0.12),
			Vector3(-2.6, 2.1, d * 0.5 - 0.12), Vector3(2.6, 2.1, d * 0.5 - 0.12)]:
		_torch(room, spot, 1.0 if spot.z < 0.0 else -1.0)

	_build_ladder(room, w, h)
	_build_tunnel(room, w)
	_build_props(room, w, d)

	var chest := CHEST.new()
	chest.name = "Chest"
	room.add_child(chest)
	chest.position = Vector3(0, 0, -d * 0.5 + 0.75)
	chest.rotation.y = PI  # Its front faces into the room.
	Graphics.register_shadow_caster(room, false)


## A torch on the wall: a bracket, a stick, a flame and a warm light.
## `out` is which way the wall faces (+Z for the back wall, -Z for the front).
func _torch(room: Node3D, at: Vector3, out: float) -> void:
	_box(room, Vector3(0.12, 0.12, 0.12), at + Vector3(0, -0.3, 0), Color(0.25, 0.25, 0.27))
	var stick := _box(room, Vector3(0.07, 0.45, 0.07), at + Vector3(0, -0.05, 0.12 * out), WOOD_DARK)
	stick.rotation.x = 0.35 * out
	var flame_material := Art.material(FLAME, {"emission": FLAME, "energy": 2.5})
	var core_material := Art.material(Color(1.0, 0.9, 0.5), {"emission": Color(1.0, 0.85, 0.4), "energy": 3.0})
	var flame := PrismMesh.new()
	flame.size = Vector3(0.16, 0.26, 0.16)
	flame.material = flame_material
	var flame_mesh := MeshInstance3D.new()
	flame_mesh.mesh = flame
	flame_mesh.position = at + Vector3(0, 0.27, 0.2 * out)
	flame_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	room.add_child(flame_mesh)
	_box(room, Vector3(0.07, 0.1, 0.07), at + Vector3(0, 0.22, 0.2 * out), Color.WHITE, core_material)
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.72, 0.42)
	light.light_energy = 1.7
	light.omni_range = 6.5
	light.omni_attenuation = 1.1
	light.shadow_enabled = false
	light.position = at + Vector3(0, 0.4, 0.45 * out)
	room.add_child(light)
	_torch_lights.append(light)


## The ladder up to the trapdoor, against the left wall, with the hatch's underside above.
func _build_ladder(room: Node3D, w: float, h: float) -> void:
	var x := -w * 0.5 + 0.3
	for z in [-0.32, 0.32]:
		_box(room, Vector3(0.08, h, 0.08), Vector3(x, h * 0.5, z), WOOD)
	for i in 8:
		_box(room, Vector3(0.07, 0.06, 0.62), Vector3(x, 0.35 + i * 0.38, 0), WOOD)
	_box(room, Vector3(1.3, 0.05, 1.3), Vector3(x + 0.35, h - 0.03, 0), WOOD_DARK)
	_box(room, Vector3(1.4, 0.04, 0.08), Vector3(x + 0.35, h - 0.06, 0), Color(0.25, 0.25, 0.27))
	var climb := PASSAGE.new()
	climb.name = "LadderUp"
	climb.prompt = "Climb up to the forest"
	climb.button = "CLIMB"
	climb.leads_inside = false
	var out_dir := -Config.TRAPDOOR_SPOT.normalized()
	climb.destination = Config.TRAPDOOR_SPOT + out_dir * 1.3
	climb.facing = out_dir
	climb.use_point = Vector3(0.5, 1.0, 0)
	room.add_child(climb)
	climb.position = Vector3(x, 0, 0)


## The tunnel to the castle, in the right wall: a dark doorway with a wooden frame and steps.
func _build_tunnel(room: Node3D, w: float) -> void:
	var x := w * 0.5
	_box(room, Vector3(0.05, 2.1, 1.3), Vector3(x - 0.03, 1.05, 0), Color(0.08, 0.07, 0.07))
	for z in [-0.72, 0.72]:
		_box(room, Vector3(0.22, 2.3, 0.2), Vector3(x - 0.1, 1.15, z), WOOD_DARK)
	_box(room, Vector3(0.24, 0.22, 1.66), Vector3(x - 0.1, 2.3, 0), WOOD_DARK)
	for i in 2:
		_box(room, Vector3(0.35, 0.14 * (i + 1), 1.2), Vector3(x - 0.2 - 0.35 * (1 - i), 0.07 * (i + 1), 0), WALL_DARK)
	var tunnel := PASSAGE.new()
	tunnel.name = "TunnelToCastle"
	tunnel.prompt = "Take the tunnel to the castle"
	tunnel.button = "ENTER"
	tunnel.leads_inside = false
	tunnel.destination = Config.CASTLE_CENTER + Config.CASTLE_DOOR_OFFSET + Vector3(1.3, 0, 0)
	tunnel.facing = Vector3.RIGHT
	tunnel.use_point = Vector3(-0.7, 1.0, 0)
	room.add_child(tunnel)
	tunnel.position = Vector3(x, 0, 0)


## Crates and barrels in the corners.
func _build_props(room: Node3D, w: float, d: float) -> void:
	for spot in [Vector3(-w * 0.5 + 0.6, 0.35, -d * 0.5 + 0.6), Vector3(-w * 0.5 + 1.4, 0.3, -d * 0.5 + 0.55),
			Vector3(w * 0.5 - 0.7, 0.35, d * 0.5 - 0.6)]:
		var size := 0.7 if spot.y > 0.32 else 0.6
		var crate := _box(room, Vector3.ONE * size, Vector3(spot.x, size * 0.5, spot.z), WOOD)
		crate.rotation.y = spot.x * 0.3
		_box(crate, Vector3(size + 0.02, 0.08, size + 0.02), Vector3.ZERO, WOOD_DARK)
	_box(room, Vector3(0.6, 0.6, 0.6), Vector3(-w * 0.5 + 0.6, 1.0, -d * 0.5 + 0.6), WOOD.darkened(0.1))
	for spot in [Vector3(w * 0.5 - 0.6, 0, -d * 0.5 + 0.6), Vector3(w * 0.5 - 1.35, 0, -d * 0.5 + 0.55),
			Vector3(-w * 0.5 + 0.7, 0, d * 0.5 - 0.7)]:
		var barrel := CylinderMesh.new()
		barrel.top_radius = 0.28
		barrel.bottom_radius = 0.28
		barrel.height = 0.8
		barrel.radial_segments = 8
		barrel.rings = 0
		barrel.material = Art.material(WOOD.lightened(0.05))
		var barrel_mesh := MeshInstance3D.new()
		barrel_mesh.mesh = barrel
		barrel_mesh.position = spot + Vector3(0, 0.4, 0)
		room.add_child(barrel_mesh)
		for y in [0.15, 0.65]:
			var band := CylinderMesh.new()
			band.top_radius = 0.29
			band.bottom_radius = 0.29
			band.height = 0.05
			band.radial_segments = 8
			band.rings = 0
			band.material = Art.material(Color(0.25, 0.25, 0.27))
			var band_mesh := MeshInstance3D.new()
			band_mesh.mesh = band
			band_mesh.position = spot + Vector3(0, y, 0)
			room.add_child(band_mesh)


# --- The two hidden entrances --------------------------------------------------------

## A wooden trapdoor at the edge of the clearing, half buried in leaves, with a
## couple of bushes beside it.
func _build_trapdoor() -> void:
	var door := Node3D.new()
	door.name = "Trapdoor"
	add_child(door)
	door.position = Config.TRAPDOOR_SPOT
	door.rotation.y = 0.4
	_box(door, Vector3(1.3, 0.06, 1.3), Vector3(0, 0.03, 0), WOOD_DARK)
	for z in [-0.4, 0.0, 0.4]:
		_box(door, Vector3(1.16, 0.06, 0.36), Vector3(0, 0.07, z), WOOD)
	for x in [-0.42, 0.42]:
		_box(door, Vector3(0.08, 0.07, 1.2), Vector3(x, 0.09, 0), Color(0.25, 0.25, 0.27))
	var ring := TorusMesh.new()
	ring.inner_radius = 0.05
	ring.outer_radius = 0.09
	ring.rings = 8
	ring.ring_segments = 4
	ring.material = Art.material(Color(0.3, 0.3, 0.33), {"rim": true})
	var ring_mesh := MeshInstance3D.new()
	ring_mesh.mesh = ring
	ring_mesh.position = Vector3(0.25, 0.12, 0)
	door.add_child(ring_mesh)
	# Fallen leaves over most of it, so it's easy to miss.
	var rng := RandomNumberGenerator.new()
	rng.seed = 41
	for i in 14:
		var leaf := _box(door, Vector3(0.24, 0.02, 0.15), Vector3(rng.randf_range(-0.6, 0.6), 0.12, rng.randf_range(-0.6, 0.6)),
				LEAF.lerp(Color(0.75, 0.55, 0.25), rng.randf() * 0.6))
		leaf.rotation.y = rng.randf() * TAU
	for spot in [Vector3(-0.95, 0, 0.45), Vector3(0.3, 0, -1.0), Vector3(0.9, 0, 0.75)]:
		_bush(door, spot, rng.randf_range(0.7, 1.0))
	var entrance := PASSAGE.new()
	entrance.name = "Entrance"
	entrance.prompt = "Open the trapdoor"
	entrance.button = "ENTER"
	entrance.destination = ladder_arrival()
	entrance.facing = Vector3.RIGHT
	entrance.use_point = Vector3(0, 0.5, 0)
	door.add_child(entrance)
	Graphics.register_shadow_caster(door, false)


## A loose stone on the inside of the castle's left wall: a slightly darker slab
## with thin cracks around it and one stone sticking out.
func _build_castle_door() -> void:
	var door := Node3D.new()
	door.name = "HiddenCastleDoor"
	add_child(door)
	door.position = Config.CASTLE_CENTER + Config.CASTLE_DOOR_OFFSET
	var stone: Color = Config.PALETTE["stone"]
	_box(door, Vector3(0.05, 2.1, 1.3), Vector3(0, 1.05, 0), stone.darkened(0.07))
	var crack := Color(0.38, 0.4, 0.4)
	for z in [-0.66, 0.66]:
		_box(door, Vector3(0.06, 2.1, 0.03), Vector3(0.005, 1.05, z), crack)
	_box(door, Vector3(0.06, 0.03, 1.33), Vector3(0.005, 2.1, 0), crack)
	_box(door, Vector3(0.06, 0.03, 0.6), Vector3(0.005, 1.3, -0.2), crack)
	_box(door, Vector3(0.16, 0.2, 0.3), Vector3(0.07, 1.15, 0.38), stone.darkened(0.02))
	var entrance := PASSAGE.new()
	entrance.name = "Entrance"
	entrance.prompt = "Push the loose stone"
	entrance.button = "ENTER"
	entrance.destination = tunnel_arrival()
	entrance.facing = Vector3.LEFT
	entrance.use_point = Vector3(0.7, 1.0, 0)
	door.add_child(entrance)


# --- Helpers ---------------------------------------------------------------------------

func _bush(parent: Node3D, at: Vector3, size: float) -> void:
	var leafy := Art.material(Art.color("leaf_2"), {"sway": 0.6})
	for part in [[0.5, Vector3(0, 0.3, 0)], [0.36, Vector3(0.32, 0.32, 0.16)]]:
		var sphere := SphereMesh.new()
		sphere.radius = part[0] * size
		sphere.height = part[0] * size * 1.6
		sphere.radial_segments = 6
		sphere.rings = 3
		sphere.material = leafy
		var mesh := MeshInstance3D.new()
		mesh.mesh = sphere
		mesh.position = at + part[1] * size
		parent.add_child(mesh)


## A box that's drawn and collides (the walls and ceiling).
func _solid(room: Node3D, walls: StaticBody3D, size: Vector3, at: Vector3, color: Color) -> void:
	_box(room, size, at, color)
	var shape := BoxShape3D.new()
	shape.size = size
	var collision := CollisionShape3D.new()
	collision.shape = shape
	collision.position = at
	walls.add_child(collision)


func _box(parent: Node3D, size: Vector3, at: Vector3, color: Color, material: Material = null) -> MeshInstance3D:
	var box := BoxMesh.new()
	box.size = size
	box.material = material if material != null else Art.material(color)
	var mesh := MeshInstance3D.new()
	mesh.mesh = box
	mesh.position = at
	parent.add_child(mesh)
	return mesh
