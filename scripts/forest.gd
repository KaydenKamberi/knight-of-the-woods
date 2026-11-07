@tool
extends Node3D
## Builds the stylized low-poly forest from code (PRD S-1, S-3, S-4, M7 art pass).
##
## Leafy trees (a trunk with 2 or 3 overlapping leaf clumps in different
## greens), pines made of stacked cones, berry bushes, rocks, flowers and grass
## are scattered around an open sandy clearing in the middle, with a sandy lane
## to the castle gate. A few trees around the clearing carry wanted posters with
## knives (W-1). Nothing grows where the castle stands. A thick ring of trees
## surrounds the play area, with an invisible wall inside it so the knight
## can't walk out. The same seed always makes the same forest.
##
## Everything is drawn with MultiMeshes split into chunks (SCENERY_CHUNK metres
## square), so the camera skips chunks it can't see and far chunks are cut off
## at the view distance (F-1, F-3). Each tree is one mesh coloured per vertex, so
## a whole kind of tree in a chunk is one draw call. Leaves and grass sway in the
## wind. Because this is a @tool script, the forest also shows up in the editor.
## Press "Rebuild Forest" in the Inspector after changing a setting.

## Size of one cell in the grid used to keep things from overlapping.
const GRID_CELL := 2.0
## The biggest keep-out radius anything uses (half of inner_tree_spacing or less).
const MAX_KEEP_OUT := 1.8
const POSTER_SCENE := preload("res://scenes/wanted_poster.tscn")
## Poster trees are all this size, so the poster sits neatly on the trunk below the leaves.
const POSTER_TREE_SIZE := 1.1
## How far the poster sits from the middle of its tree trunk, and how high up.
const POSTER_OFFSET := 0.24
const POSTER_HEIGHT := 1.4
## Physics layer value for the invisible edge wall (layer 3, "boundary").
## The knight bumps into it, but thrown knives fly through.
const BOUNDARY_LAYER := 4
const Config := preload("res://scripts/game_config.gd")
const Art := preload("res://scripts/art.gd")
const GRASS_SHADER := preload("res://shaders/grass.gdshader")

@export var forest_seed := 7
## The open space in the middle (sandy, with the swinging log).
@export var clearing_radius := 7.0
## The knight can walk anywhere inside this circle.
@export var play_radius := 34.0
## How thick the ring of trees outside the play area is.
@export var edge_depth := 14.0
@export var inner_tree_count := 70
@export var edge_tree_count := 320
@export var rock_count := 28
@export var bush_count := 45
@export var small_rock_count := 70
@export var flower_count := 260
## Roughly how far apart trees stand inside the play area, in metres.
@export var inner_tree_spacing := 3.6
@export var edge_tree_spacing := 2.6
## Share of trees that are pines. The rest are round leafy trees.
@export_range(0.0, 1.0) var pine_share := 0.55
@export_group("Wanted posters")
@export var poster_count := 6
## How far from the middle poster trees stand: x is the nearest, y the farthest, in metres.
@export var poster_distance := Vector2(9.5, 14.0)
@export_group("")
@export_tool_button("Rebuild Forest", "Reload") var rebuild_button := rebuild

var _rng := RandomNumberGenerator.new()
## Grid cell -> Array of Vector3(x, z, keep_out radius) for everything placed so far.
var _grid := {}
var _generated: Node3D


func _ready() -> void:
	rebuild()


## Throws away the old forest and builds a new one from the current settings.
func rebuild() -> void:
	if is_instance_valid(_generated):
		_generated.free()
	_generated = Node3D.new()
	_generated.name = "Generated"
	add_child(_generated)
	_grid.clear()
	_rng.seed = forest_seed

	_build_paths()
	_build_trees()
	_build_rocks()
	_build_bushes()
	_build_small_details()
	_build_grass()
	_build_edge_wall()


## The sandy clearing in the middle and the lane up to the castle gate.
func _build_paths() -> void:
	var sand := Art.material(Art.color("sand"))
	var clearing := CylinderMesh.new()
	clearing.top_radius = clearing_radius - 1.0
	clearing.bottom_radius = clearing_radius - 1.0
	clearing.height = 0.02
	clearing.radial_segments = 20
	clearing.rings = 0
	clearing.material = sand
	_add_flat_piece(clearing, Vector3(0, 0.01, 0))
	var lane_start := clearing_radius - 1.5
	var lane_end := Config.CASTLE_CENTER.z - Config.CASTLE_HALF_SIZE
	var lane := BoxMesh.new()
	lane.size = Vector3(Config.CASTLE_GATE_WIDTH + 0.6, 0.02, lane_end - lane_start)
	lane.material = sand
	_add_flat_piece(lane, Vector3(Config.CASTLE_CENTER.x, 0.012, (lane_start + lane_end) * 0.5))


func _add_flat_piece(mesh: Mesh, at: Vector3) -> void:
	var piece := MeshInstance3D.new()
	piece.mesh = mesh
	piece.position = at
	piece.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_generated.add_child(piece)


func _build_trees() -> void:
	var pines: Array[Transform3D] = []
	var leafy_a: Array[Transform3D] = []
	var leafy_b: Array[Transform3D] = []
	var pine_tints: Array[Color] = []
	var a_tints: Array[Color] = []
	var b_tints: Array[Color] = []
	var colliders: Array[Vector3] = []

	# Poster trees go first, so the random trees keep out of their way.
	for spot in _place_poster_trees():
		var turn := Basis(Vector3.UP, _rng.randf() * TAU)
		leafy_a.append(Transform3D(turn.scaled(Vector3.ONE * POSTER_TREE_SIZE), spot))
		a_tints.append(_random_tint())
		colliders.append(spot)
		_add_poster(spot)

	var spots := _scatter(inner_tree_count, clearing_radius, play_radius - 1.0, inner_tree_spacing * 0.5)
	spots.append_array(_scatter(edge_tree_count, play_radius - 1.0, play_radius + edge_depth, edge_tree_spacing * 0.5))

	for spot in spots:
		# Random size, a little stretch and a random turn, so no two trees look the same.
		var size := _rng.randf_range(0.8, 1.35)
		var stretch := Vector3(size, size * _rng.randf_range(0.9, 1.15), size)
		var xform := Transform3D(Basis(Vector3.UP, _rng.randf() * TAU).scaled(stretch), spot)
		if _rng.randf() < pine_share:
			pines.append(xform)
			pine_tints.append(_random_tint())
		elif _rng.randf() < 0.5:
			leafy_a.append(xform)
			a_tints.append(_random_tint())
		else:
			leafy_b.append(xform)
			b_tints.append(_random_tint())
		# Only trees the knight can reach need to block him.
		if spot.length() < play_radius + 1.0:
			colliders.append(spot)

	var leaves := Art.material(Color.WHITE, {"instance_color": true, "fade": true, "sway": 1.0})
	_add_chunked("Pines", _pine_mesh(), leaves, pines, pine_tints, "trees")
	_add_chunked("LeafyTreesA", _leafy_mesh(true), leaves, leafy_a, a_tints, "trees")
	_add_chunked("LeafyTreesB", _leafy_mesh(false), leaves, leafy_b, b_tints, "trees")

	var body := _add_static_body("TreeColliders")
	var trunk_shape := CylinderShape3D.new()
	trunk_shape.radius = 0.25
	trunk_shape.height = 4.0
	for spot in colliders:
		_add_shape(body, trunk_shape, spot + Vector3(0.0, 2.0, 0.0))


func _build_rocks() -> void:
	var rocks: Array[Transform3D] = []
	var tints: Array[Color] = []
	var body := _add_static_body("RockColliders")
	for spot in _scatter(rock_count, clearing_radius, play_radius - 1.0, 0.9):
		var size := _rng.randf_range(0.5, 1.6)
		var squash := Vector3(_rng.randf_range(0.9, 1.25), _rng.randf_range(0.6, 1.0), 1.0) * size
		var turn_and_squash := Basis(Vector3.UP, _rng.randf() * TAU) * Basis.from_scale(squash)
		rocks.append(Transform3D(turn_and_squash, spot))
		tints.append(_random_tint())
		# Small rocks are just decoration; big ones block the knight.
		if size > 0.9:
			var shape := CylinderShape3D.new()
			shape.radius = 0.6 * size
			shape.height = 1.0 * size
			_add_shape(body, shape, spot + Vector3(0.0, shape.height * 0.5, 0.0))
	var stone := Art.material(Color.WHITE, {"instance_color": true, "fade": true})
	_add_chunked("Rocks", _rock_mesh(), stone, rocks, tints, "trees")


## Berry bushes: a leafy mound with red berries tucked into it.
func _build_bushes() -> void:
	var bushes: Array[Transform3D] = []
	var tints: Array[Color] = []
	for spot in _scatter(bush_count, clearing_radius, play_radius + edge_depth * 0.5, 0.7):
		var size := _rng.randf_range(0.7, 1.3)
		bushes.append(Transform3D(Basis(Vector3.UP, _rng.randf() * TAU).scaled(Vector3.ONE * size), spot))
		tints.append(_random_tint())
	var leafy := Art.material(Color.WHITE, {"instance_color": true, "fade": true, "sway": 0.6})
	_add_chunked("BerryBushes", _bush_mesh(), leafy, bushes, tints, "small")


## Flowers in three colours and small loose rocks, for detail.
func _build_small_details() -> void:
	var plain := Art.material(Color.WHITE, {"instance_color": true, "fade": true})
	for colour_index in 3:
		var flowers: Array[Transform3D] = []
		var tints: Array[Color] = []
		for i in flower_count / 3:
			var spot := _random_ground_spot(play_radius - 1.0)
			if not _grass_allowed(spot):
				continue
			var size := _rng.randf_range(0.8, 1.3)
			flowers.append(Transform3D(Basis(Vector3.UP, _rng.randf() * TAU).scaled(Vector3.ONE * size), spot))
			tints.append(_random_tint())
		_add_chunked("Flowers%d" % (colour_index + 1), _flower_mesh(Art.color("flower_%d" % (colour_index + 1))),
				plain, flowers, tints, "small")
	var pebbles: Array[Transform3D] = []
	var pebble_tints: Array[Color] = []
	for i in small_rock_count:
		var spot := _random_ground_spot(play_radius + 2.0)
		if _in_castle_grounds(Vector2(spot.x, spot.z), 0.0):
			continue
		var size := _rng.randf_range(0.15, 0.4)
		var turn := Basis(Vector3.UP, _rng.randf() * TAU) * Basis.from_scale(Vector3(1.2, 0.7, 1.0) * size)
		pebbles.append(Transform3D(turn, spot))
		pebble_tints.append(_random_tint())
	_add_chunked("SmallRocks", _rock_mesh(), plain, pebbles, pebble_tints, "small")


## Thousands of grass blades, swaying in the wind, everywhere except the castle,
## the sandy clearing and the lane.
func _build_grass() -> void:
	var blades: Array[Transform3D] = []
	var tints: Array[Color] = []
	var attempts := Config.GRASS_BLADES * 3
	while blades.size() < Config.GRASS_BLADES and attempts > 0:
		attempts -= 1
		var spot := _random_ground_spot(play_radius + 4.0)
		if not _grass_allowed(spot):
			continue
		var size := _rng.randf_range(0.6, 1.5)
		var shape := Vector3(size, size * _rng.randf_range(0.7, 1.4), size)
		blades.append(Transform3D(Basis(Vector3.UP, _rng.randf() * TAU).scaled(shape), spot))
		var shade := _rng.randf_range(0.85, 1.12)
		tints.append(Color(shade, shade, shade * _rng.randf_range(0.9, 1.05)))
	var grass := ShaderMaterial.new()
	grass.shader = GRASS_SHADER
	grass.set_shader_parameter("base_color", Art.color("grass_base"))
	grass.set_shader_parameter("tip_color", Art.color("grass_tip"))
	_add_chunked("Grass", _blade_mesh(), grass, blades, tints, "grass")


## True where grass and flowers may grow: not in the castle, the clearing or the lane.
func _grass_allowed(spot: Vector3) -> bool:
	var point := Vector2(spot.x, spot.z)
	if point.length() < clearing_radius - 0.5:
		return false
	var castle := Vector2(Config.CASTLE_CENTER.x, Config.CASTLE_CENTER.z)
	var reach := Config.CASTLE_HALF_SIZE + Config.CASTLE_TOWER_SIZE * 0.5 + 0.5
	if absf(point.x - castle.x) <= reach and absf(point.y - castle.y) <= reach:
		return false
	var lane_half_width := Config.CASTLE_GATE_WIDTH * 0.5 + 0.8
	return not (absf(point.x - castle.x) <= lane_half_width and point.y > 0.0 and point.y < castle.y)


func _random_ground_spot(radius: float) -> Vector3:
	var angle := _rng.randf() * TAU
	var distance := sqrt(_rng.randf()) * radius
	return Vector3(cos(angle) * distance, 0.0, sin(angle) * distance)


## A ring of invisible boxes just inside the edge trees.
func _build_edge_wall() -> void:
	var body := _add_static_body("EdgeWall")
	body.collision_layer = BOUNDARY_LAYER
	body.collision_mask = 0
	var segments := 48
	var radius := play_radius + 0.5
	var shape := BoxShape3D.new()
	shape.size = Vector3(TAU * radius / segments + 0.6, 6.0, 1.0)
	for i in segments:
		var angle := TAU * i / segments
		var spot := Vector3(cos(angle), 0.0, sin(angle)) * radius + Vector3(0.0, 3.0, 0.0)
		# Turn each box so its long side runs along the circle.
		_add_shape(body, shape, spot, Basis(Vector3.UP, -(angle + PI / 2.0)))


# --- Placement --------------------------------------------------------------

## Picks one spot per poster, spread evenly around the clearing.
func _place_poster_trees() -> Array[Vector3]:
	var spots: Array[Vector3] = []
	var keep_out := inner_tree_spacing * 0.5
	var start_angle := _rng.randf() * TAU
	for i in poster_count:
		for _attempt in 20:
			var angle := start_angle + TAU * i / poster_count + _rng.randf_range(-0.25, 0.25)
			var distance := _rng.randf_range(poster_distance.x, poster_distance.y)
			var point := Vector2(cos(angle), sin(angle)) * distance
			if _is_free(point, keep_out):
				_mark_used(point, keep_out)
				spots.append(Vector3(point.x, 0.0, point.y))
				break
	return spots


## Pins a wanted poster to the side of the tree at `tree` that faces the clearing.
func _add_poster(tree: Vector3) -> void:
	var to_middle := Vector3(-tree.x, 0.0, -tree.z).normalized()
	var poster := POSTER_SCENE.instantiate() as Node3D
	_generated.add_child(poster)
	# The poster's front is its +Z side, so point -Z away from the clearing.
	var spot := tree + to_middle * POSTER_OFFSET + Vector3.UP * POSTER_HEIGHT
	poster.transform = Transform3D(Basis.looking_at(-to_middle, Vector3.UP), spot)


## Picks up to `count` random spots on the ground between two distances from the
## middle, each at least `keep_out` metres clear of everything placed before.
func _scatter(count: int, min_radius: float, max_radius: float, keep_out: float) -> Array[Vector3]:
	var spots: Array[Vector3] = []
	var attempts := count * 30
	while spots.size() < count and attempts > 0:
		attempts -= 1
		var angle := _rng.randf() * TAU
		# The square root spreads spots evenly over the ring instead of bunching them in the middle.
		var distance := sqrt(_rng.randf_range(min_radius * min_radius, max_radius * max_radius))
		var point := Vector2(cos(angle), sin(angle)) * distance
		if _is_free(point, keep_out):
			_mark_used(point, keep_out)
			spots.append(Vector3(point.x, 0.0, point.y))
	return spots


func _is_free(point: Vector2, keep_out: float) -> bool:
	if _in_castle_grounds(point, keep_out):
		return false
	var cell := _cell_of(point)
	var reach := ceili((keep_out + MAX_KEEP_OUT) / GRID_CELL)
	for x in range(cell.x - reach, cell.x + reach + 1):
		for y in range(cell.y - reach, cell.y + reach + 1):
			for other: Vector3 in _grid.get(Vector2i(x, y), []):
				if point.distance_to(Vector2(other.x, other.y)) < keep_out + other.z:
					return false
	return true


## True inside the castle's footprint (plus a margin) or on the lane from its gate to the clearing.
func _in_castle_grounds(point: Vector2, keep_out: float) -> bool:
	var center := Vector2(Config.CASTLE_CENTER.x, Config.CASTLE_CENTER.z)
	var reach := Config.CASTLE_HALF_SIZE + Config.CASTLE_TOWER_SIZE * 0.5 + Config.CASTLE_TREE_MARGIN + keep_out
	if absf(point.x - center.x) <= reach and absf(point.y - center.y) <= reach:
		return true
	# The lane: as wide as the gate plus a little, from the clearing to the castle.
	var lane_half_width := Config.CASTLE_GATE_WIDTH * 0.5 + 1.0 + keep_out
	return absf(point.x - center.x) <= lane_half_width and point.y > 0.0 and point.y < center.y


func _mark_used(point: Vector2, keep_out: float) -> void:
	var cell := _cell_of(point)
	if not _grid.has(cell):
		_grid[cell] = []
	_grid[cell].append(Vector3(point.x, point.y, keep_out))


func _cell_of(point: Vector2) -> Vector2i:
	return Vector2i(floori(point.x / GRID_CELL), floori(point.y / GRID_CELL))


## A slight random shade so neighbouring trees and rocks don't look identical.
func _random_tint() -> Color:
	var shade := _rng.randf_range(0.82, 1.12)
	return Color(shade * _rng.randf_range(0.92, 1.08), shade, shade * _rng.randf_range(0.9, 1.05))


# --- Nodes ------------------------------------------------------------------

## Adds MultiMeshes of `mesh`, one per chunk of the forest, so the camera can skip
## chunks it can't see and the graphics setting can cut far ones off (F-1, F-3).
func _add_chunked(node_name: String, mesh: Mesh, material: Material, xforms: Array[Transform3D],
		tints: Array[Color], kind: String) -> void:
	var chunks := {}
	for i in xforms.size():
		var origin := xforms[i].origin
		var key := Vector2i(floori(origin.x / Config.SCENERY_CHUNK), floori(origin.z / Config.SCENERY_CHUNK))
		if not chunks.has(key):
			chunks[key] = [[], []]
		chunks[key][0].append(xforms[i])
		chunks[key][1].append(tints[i] if i < tints.size() else Color.WHITE)
	for key: Vector2i in chunks:
		var chunk_xforms: Array = chunks[key][0]
		var chunk_tints: Array = chunks[key][1]
		var multimesh := MultiMesh.new()
		multimesh.transform_format = MultiMesh.TRANSFORM_3D
		multimesh.use_colors = true
		multimesh.mesh = mesh
		multimesh.instance_count = chunk_xforms.size()
		for i in chunk_xforms.size():
			multimesh.set_instance_transform(i, chunk_xforms[i])
			multimesh.set_instance_color(i, chunk_tints[i])
		var instance := MultiMeshInstance3D.new()
		instance.name = "%s_%d_%d" % [node_name, key.x, key.y]
		instance.multimesh = multimesh
		instance.material_override = material
		_generated.add_child(instance)
		if not Engine.is_editor_hint():
			Graphics.register_scenery(instance, kind)


func _add_static_body(node_name: String) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = node_name
	_generated.add_child(body)
	return body


func _add_shape(body: StaticBody3D, shape: Shape3D, at: Vector3, turn := Basis.IDENTITY) -> void:
	var collision := CollisionShape3D.new()
	collision.shape = shape
	collision.transform = Transform3D(turn, at)
	body.add_child(collision)


# --- Meshes -----------------------------------------------------------------
# Each mesh is put together from Godot's built-in shapes, coloured per part with
# vertex colours, and given flat (faceted) shading for the low-poly look.

## A pine: a trunk and three stacked cones in slightly different greens.
func _pine_mesh() -> ArrayMesh:
	var pine := Art.color("pine")
	return _flat_mesh([
		[_cylinder(0.1, 0.2, 1.6, 6), Transform3D(Basis.IDENTITY, Vector3(0.0, 0.8, 0.0)), Art.color("trunk")],
		[_cylinder(0.0, 1.4, 1.8, 7), Transform3D(Basis.IDENTITY, Vector3(0.0, 2.1, 0.0)), pine.darkened(0.08)],
		[_cylinder(0.0, 1.1, 1.5, 7), Transform3D(Basis(Vector3.UP, 0.4), Vector3(0.0, 3.0, 0.0)), pine],
		[_cylinder(0.0, 0.75, 1.3, 7), Transform3D(Basis(Vector3.UP, 0.9), Vector3(0.0, 3.8, 0.0)), pine.lightened(0.1)],
	])


## A leafy tree: a trunk with overlapping leaf clumps. Shape A has three clumps,
## shape B two, each clump a different green.
func _leafy_mesh(three_clumps: bool) -> ArrayMesh:
	var trunk := Art.color("trunk")
	var parts: Array = [
		[_cylinder(0.14, 0.24, 2.4, 6), Transform3D(Basis.IDENTITY, Vector3(0.0, 1.2, 0.0)), trunk],
	]
	if three_clumps:
		parts.append([_sphere(1.4, 7, 4), Transform3D(Basis.from_scale(Vector3(1.0, 0.85, 1.0)), Vector3(0.0, 3.0, 0.0)), Art.color("leaf_1")])
		parts.append([_sphere(0.95, 6, 3), Transform3D(Basis.IDENTITY, Vector3(0.65, 3.6, 0.3)), Art.color("leaf_2")])
		parts.append([_sphere(0.85, 6, 3), Transform3D(Basis.IDENTITY, Vector3(-0.6, 2.75, -0.45)), Art.color("leaf_3")])
	else:
		parts.append([_sphere(1.25, 7, 4), Transform3D(Basis.from_scale(Vector3(1.1, 0.9, 1.0)), Vector3(0.3, 3.1, 0.0)), Art.color("leaf_2")])
		parts.append([_sphere(1.05, 6, 3), Transform3D(Basis.IDENTITY, Vector3(-0.5, 3.5, 0.4)), Art.color("leaf_3")])
	return _flat_mesh(parts)


func _rock_mesh() -> ArrayMesh:
	return _flat_mesh([
		[_sphere(0.6, 6, 3), Transform3D(Basis.from_scale(Vector3(1.2, 0.8, 1.0)), Vector3(0.0, 0.15, 0.0)), Art.color("rock")],
	])


func _bush_mesh() -> ArrayMesh:
	var leaf := Art.color("leaf_2")
	var berry := Art.color("berry")
	var parts: Array = [
		[_sphere(0.55, 6, 3), Transform3D(Basis.from_scale(Vector3(1.0, 0.8, 1.0)), Vector3(0.0, 0.3, 0.0)), leaf],
		[_sphere(0.4, 6, 3), Transform3D(Basis.IDENTITY, Vector3(0.4, 0.35, 0.2)), leaf.darkened(0.1)],
	]
	for i in 6:
		var angle := TAU * i / 6.0 + 0.3
		parts.append([_sphere(0.07, 5, 3), Transform3D(Basis.IDENTITY,
				Vector3(cos(angle) * 0.5, 0.35 + 0.12 * (i % 3), sin(angle) * 0.45)), berry])
	return _flat_mesh(parts)


## A small flower: a green stem and a coloured head.
func _flower_mesh(head: Color) -> ArrayMesh:
	var stem := BoxMesh.new()
	stem.size = Vector3(0.02, 0.22, 0.02)
	return _flat_mesh([
		[stem, Transform3D(Basis.IDENTITY, Vector3(0.0, 0.11, 0.0)), Art.color("leaf_1")],
		[_sphere(0.06, 5, 2), Transform3D(Basis.from_scale(Vector3(1.0, 0.6, 1.0)), Vector3(0.0, 0.24, 0.0)), head],
	])


## One grass blade: a thin triangle, 0.7 m tall before scaling.
func _blade_mesh() -> ArrayMesh:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for point in [Vector3(-0.07, 0.0, 0.0), Vector3(0.07, 0.0, 0.0), Vector3(0.0, 0.7, 0.0)]:
		tool.set_normal(Vector3.UP)
		tool.set_color(Color.WHITE)
		tool.add_vertex(point)
	return tool.commit()


func _cylinder(top: float, bottom: float, height: float, sides: int) -> CylinderMesh:
	var mesh := CylinderMesh.new()
	mesh.top_radius = top
	mesh.bottom_radius = bottom
	mesh.height = height
	mesh.radial_segments = sides
	mesh.rings = 0
	mesh.cap_top = top > 0.0
	return mesh


func _sphere(radius: float, sides: int, rings: int) -> SphereMesh:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = sides
	mesh.rings = rings
	return mesh


## Joins several [shape, transform, colour] parts into one mesh where every
## triangle gets its own flat normal and its part's colour.
func _flat_mesh(parts: Array) -> ArrayMesh:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for part in parts:
		var arrays: Array = (part[0] as PrimitiveMesh).get_mesh_arrays()
		var xform: Transform3D = part[1]
		var colour: Color = part[2]
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		for i in range(0, indices.size(), 3):
			var ia: int = indices[i]
			var ib: int = indices[i + 1]
			var ic: int = indices[i + 2]
			var a: Vector3 = xform * vertices[ia]
			var b: Vector3 = xform * vertices[ib]
			var c: Vector3 = xform * vertices[ic]
			var normal := (b - a).cross(c - a)
			if normal.length_squared() < 0.000001:
				continue  # Skip squashed triangles, like the tip of a cone.
			# Point the flat normal the same way as the shape's own smooth normals.
			var outward: Vector3 = xform.basis * (normals[ia] + normals[ib] + normals[ic])
			normal = normal.normalized()
			if normal.dot(outward) < 0.0:
				normal = -normal
			for point in [a, b, c]:
				tool.set_normal(normal)
				tool.set_color(colour)
				tool.add_vertex(point)
	return tool.commit()
