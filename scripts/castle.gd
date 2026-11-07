@tool
extends Node3D
## The knight's castle (PRD S-2), at the south edge of the forest.
##
## Built from simple boxes in code, like the trees: four stone walls around a
## square courtyard, a tower at each corner, battlements along the tops, and a
## wide gate in the front wall that faces the middle of the forest (-Z). There's
## no door and no lintel, so anyone can walk through the gate, even the big boss. Green-and-gold banners (the
## knight's colours) hang by the gate and inside the courtyard.
##
## The walls and towers have collision on the world layer, so nothing walks
## through them and the third-person camera's spring arm stops at them. Enemies
## never attack the castle; it's the home base. In the game (not the editor) the
## castle also places the furnace site in the courtyard and puts the knight at
## his starting spot. Sizes live in game_config.gd.

const Config := preload("res://scripts/game_config.gd")
const FURNACE_SITE := preload("res://scripts/furnace_site.gd")
const STONE := Color(0.56, 0.55, 0.51)
const DARK_STONE := Color(0.4, 0.39, 0.37)
const FLOOR := Color(0.47, 0.45, 0.4)
const ROOF := Color(0.28, 0.32, 0.42)
## The same green and gold as the knight's tabard and emblem.
const GREEN := Color(0.16, 0.38, 0.22)
const GOLD := Color(0.86, 0.68, 0.22)
const WOOD := Color(0.4, 0.27, 0.16)

var _materials := {}
var _built: Node3D


func _ready() -> void:
	position = Config.CASTLE_CENTER
	rotation = Vector3.ZERO
	_build()
	if not Engine.is_editor_hint():
		var site = FURNACE_SITE.new()
		site.name = "FurnaceSite"
		site.position = Config.FURNACE_OFFSET
		add_child(site)
		_place_knight.call_deferred()


## The point just outside the gate, in world space. Rescuers and the army march out from here.
static func gate_outside() -> Vector3:
	return Config.CASTLE_CENTER + Vector3(0.0, 0.0, -Config.CASTLE_HALF_SIZE - 2.5)


## True if `point` (world space, any height) is inside the castle walls.
static func is_inside(point: Vector3) -> bool:
	var local := point - Config.CASTLE_CENTER
	var reach := Config.CASTLE_HALF_SIZE + Config.CASTLE_TOWER_SIZE * 0.5
	return absf(local.x) <= reach and absf(local.z) <= reach


func _place_knight() -> void:
	var knight := get_tree().get_first_node_in_group("player") as Node3D
	if knight != null:
		knight.global_position = Config.KNIGHT_START


func _build() -> void:
	if is_instance_valid(_built):
		_built.free()
	_built = Node3D.new()
	_built.name = "Built"
	add_child(_built)
	var walls := StaticBody3D.new()
	walls.name = "Walls"
	_built.add_child(walls)

	var h := Config.CASTLE_HALF_SIZE
	var t := Config.CASTLE_WALL_THICKNESS
	var wall_height := Config.CASTLE_WALL_HEIGHT
	var gate := Config.CASTLE_GATE_WIDTH
	var post_height := Config.CASTLE_GATE_POST_HEIGHT

	# Back (+Z), left and right walls run the full length.
	_solid(walls, Vector3(2.0 * h + t, wall_height, t), Vector3(0, wall_height * 0.5, h), STONE)
	_solid(walls, Vector3(t, wall_height, 2.0 * h + t), Vector3(-h, wall_height * 0.5, 0), STONE)
	_solid(walls, Vector3(t, wall_height, 2.0 * h + t), Vector3(h, wall_height * 0.5, 0), STONE)
	# The front wall (-Z) has the gate in the middle: a full-height opening framed
	# by two taller, darker posts.
	var side_length := h + t * 0.5 - gate * 0.5
	var side_middle := gate * 0.5 + side_length * 0.5
	for side in [-1.0, 1.0]:
		_solid(walls, Vector3(side_length, wall_height, t), Vector3(side_middle * side, wall_height * 0.5, -h), STONE)
		var post := Vector3((gate * 0.5 + 0.45) * side, post_height * 0.5, -h)
		_solid(walls, Vector3(0.9, post_height, t + 0.4), post, DARK_STONE)
		_visual(Vector3(1.1, 0.3, t + 0.6), post + Vector3(0, post_height * 0.5 + 0.15, 0), STONE)

	# A stone floor for the courtyard (just for looks; the ground does the colliding).
	_visual(Vector3(2.0 * h - t, 0.04, 2.0 * h - t), Vector3(0, 0.02, 0), FLOOR)
	_visual(Vector3(gate, 0.04, t + 0.2), Vector3(0, 0.02, -h), FLOOR)

	_build_towers(walls, h)
	_build_battlements(h, t, wall_height)
	_build_banners(h, t)


func _build_towers(walls: StaticBody3D, h: float) -> void:
	var size := Config.CASTLE_TOWER_SIZE
	var height := Config.CASTLE_TOWER_HEIGHT
	for x in [-1.0, 1.0]:
		for z in [-1.0, 1.0]:
			var base := Vector3(h * x, 0.0, h * z)
			_solid(walls, Vector3(size, height, size), base + Vector3(0, height * 0.5, 0), STONE)
			_visual(Vector3(size + 0.4, 0.4, size + 0.4), base + Vector3(0, height + 0.2, 0), DARK_STONE)
			# A four-sided pointed roof.
			var roof := CylinderMesh.new()
			roof.top_radius = 0.0
			roof.bottom_radius = (size + 0.4) * 0.72
			roof.height = 2.2
			roof.radial_segments = 4
			roof.rings = 0
			roof.material = _material(ROOF)
			var roof_mesh := MeshInstance3D.new()
			roof_mesh.mesh = roof
			roof_mesh.transform = Transform3D(Basis(Vector3.UP, PI / 4.0), base + Vector3(0, height + 1.5, 0))
			_built.add_child(roof_mesh)
			# A green flag on a pole at the top.
			var top := base + Vector3(0, height + 2.6, 0)
			_visual(Vector3(0.08, 1.4, 0.08), top + Vector3(0, 0.7, 0), WOOD)
			_visual(Vector3(0.9, 0.5, 0.04), top + Vector3(0.48, 1.15, 0), GREEN)


## Battlements: a row of small stone blocks along the tops of the walls, drawn as one MultiMesh.
func _build_battlements(h: float, t: float, wall_height: float) -> void:
	var spots: Array[Vector3] = []
	var step := 1.5
	var clear_of_towers := Config.CASTLE_TOWER_SIZE * 0.5 + 0.4
	var along := -h + clear_of_towers
	var gate_gap := Config.CASTLE_GATE_WIDTH * 0.5 + 1.0
	while along <= h - clear_of_towers:
		spots.append(Vector3(along, 0, h))
		# The front wall has the open gate in it, so leave a gap there.
		if absf(along) > gate_gap:
			spots.append(Vector3(along, 0, -h))
		spots.append(Vector3(-h, 0, along))
		spots.append(Vector3(h, 0, along))
		along += step
	var box := BoxMesh.new()
	box.size = Vector3(0.6, 0.6, t * 1.02)
	box.material = _material(STONE)
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = box
	multimesh.instance_count = spots.size()
	for i in spots.size():
		var spot := spots[i]
		# Blocks on the side walls are turned so they sit along the wall.
		var turn := Basis(Vector3.UP, PI / 2.0) if absf(absf(spot.x) - h) < 0.01 else Basis.IDENTITY
		multimesh.set_instance_transform(i, Transform3D(turn, spot + Vector3(0, wall_height + 0.3, 0)))
	var instance := MultiMeshInstance3D.new()
	instance.name = "Battlements"
	instance.multimesh = multimesh
	_built.add_child(instance)


## Green banners with a gold diamond: two outside by the gate, two inside on the back wall.
func _build_banners(h: float, t: float) -> void:
	var gate := Config.CASTLE_GATE_WIDTH
	# Every banner's front faces -Z: out to the forest on the front wall, into the
	# courtyard on the back wall.
	for x in [-(gate * 0.5 + 1.4), gate * 0.5 + 1.4]:
		_banner(Vector3(x, 2.4, -h - t * 0.5 - 0.04))
	for x in [-3.0, 3.0]:
		_banner(Vector3(x, 2.4, h - t * 0.5 - 0.04))


func _banner(at: Vector3) -> void:
	var banner := Node3D.new()
	banner.position = at
	_built.add_child(banner)
	_add_box(banner, Vector3(1.0, 1.8, 0.05), Vector3.ZERO, GREEN)
	_add_box(banner, Vector3(1.2, 0.12, 0.08), Vector3(0, 0.95, 0), GOLD)
	var diamond := _add_box(banner, Vector3(0.36, 0.36, 0.03), Vector3(0, 0.1, -0.04), GOLD)
	diamond.rotation.z = PI / 4.0
	# A pointed tail at the bottom.
	var tail := _add_box(banner, Vector3(0.7, 0.7, 0.05), Vector3(0, -0.9, 0), GREEN)
	tail.rotation.z = PI / 4.0


# --- Helpers -----------------------------------------------------------------------

## A box that's drawn and collides.
func _solid(walls: StaticBody3D, size: Vector3, at: Vector3, color: Color) -> void:
	_visual(size, at, color)
	var shape := BoxShape3D.new()
	shape.size = size
	var collision := CollisionShape3D.new()
	collision.shape = shape
	collision.position = at
	walls.add_child(collision)


## A box that's only drawn.
func _visual(size: Vector3, at: Vector3, color: Color) -> MeshInstance3D:
	return _add_box(_built, size, at, color)


func _add_box(parent: Node3D, size: Vector3, at: Vector3, color: Color) -> MeshInstance3D:
	var box := BoxMesh.new()
	box.size = size
	box.material = _material(color)
	var mesh := MeshInstance3D.new()
	mesh.mesh = box
	mesh.position = at
	parent.add_child(mesh)
	return mesh


## One material per colour, shared by every box of that colour.
func _material(color: Color) -> StandardMaterial3D:
	if not _materials.has(color):
		var material := StandardMaterial3D.new()
		material.albedo_color = color
		material.roughness = 1.0
		_materials[color] = material
	return _materials[color]
