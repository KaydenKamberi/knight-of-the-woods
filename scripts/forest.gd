@tool
extends Node3D
## Builds the small low-poly forest from code (PRD S-1, S-3, S-4).
##
## Trees, rocks and bushes are scattered around an open clearing in the middle.
## A thick ring of trees surrounds the play area, with an invisible wall inside
## it so the knight can't walk out. The same seed always makes the same forest.
##
## Everything is drawn with a few MultiMeshes (one draw call per kind of
## object), which keeps it fast on phones. Because this is a @tool script, the
## forest also shows up in the editor. Press "Rebuild Forest" in the Inspector
## after changing a setting.

## Size of one cell in the grid used to keep things from overlapping.
const GRID_CELL := 2.0
## The biggest keep-out radius anything uses (half of inner_tree_spacing or less).
const MAX_KEEP_OUT := 1.8
const TRUNK_COLOR := Color(0.36, 0.24, 0.15)
const PINE_COLOR := Color(0.16, 0.36, 0.2)
const LEAF_COLOR := Color(0.3, 0.5, 0.2)
const ROCK_COLOR := Color(0.5, 0.5, 0.48)
const BUSH_COLOR := Color(0.22, 0.42, 0.18)

@export var forest_seed := 7
## The open space in the middle where the knight starts.
@export var clearing_radius := 7.0
## The knight can walk anywhere inside this circle.
@export var play_radius := 34.0
## How thick the ring of trees outside the play area is.
@export var edge_depth := 14.0
@export var inner_tree_count := 70
@export var edge_tree_count := 320
@export var rock_count := 28
@export var bush_count := 45
## Roughly how far apart trees stand inside the play area, in metres.
@export var inner_tree_spacing := 3.6
@export var edge_tree_spacing := 2.6
## Share of trees that are pines. The rest are round leafy trees.
@export_range(0.0, 1.0) var pine_share := 0.6
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

	_build_trees()
	_build_rocks()
	_build_bushes()
	_build_edge_wall()


func _build_trees() -> void:
	var pines: Array[Transform3D] = []
	var pine_tints: Array[Color] = []
	var leafy: Array[Transform3D] = []
	var leafy_tints: Array[Color] = []
	var colliders: Array[Vector3] = []

	var spots := _scatter(inner_tree_count, clearing_radius, play_radius - 1.0, inner_tree_spacing * 0.5)
	spots.append_array(_scatter(edge_tree_count, play_radius - 1.0, play_radius + edge_depth, edge_tree_spacing * 0.5))

	for spot in spots:
		var size := _rng.randf_range(0.8, 1.35)
		var xform := Transform3D(Basis(Vector3.UP, _rng.randf() * TAU).scaled(Vector3.ONE * size), spot)
		if _rng.randf() < pine_share:
			pines.append(xform)
			pine_tints.append(_random_tint())
		else:
			leafy.append(xform)
			leafy_tints.append(_random_tint())
		# Only trees the knight can reach need to block him.
		if spot.length() < play_radius + 1.0:
			colliders.append(spot)

	var trunk_material := _material(TRUNK_COLOR, false)
	_add_multimesh("PineTrunks", _pine_trunk_mesh(trunk_material), pines)
	_add_multimesh("PineNeedles", _pine_needles_mesh(_material(PINE_COLOR, true)), pines, pine_tints)
	_add_multimesh("LeafyTrunks", _leafy_trunk_mesh(trunk_material), leafy)
	_add_multimesh("LeafyCrowns", _leafy_crown_mesh(_material(LEAF_COLOR, true)), leafy, leafy_tints)

	var body := _add_static_body("TreeColliders")
	var trunk_shape := CylinderShape3D.new()
	trunk_shape.radius = 0.35
	trunk_shape.height = 4.0
	for spot in colliders:
		_add_shape(body, trunk_shape, spot + Vector3(0.0, 2.0, 0.0))


func _build_rocks() -> void:
	var rocks: Array[Transform3D] = []
	var tints: Array[Color] = []
	var body := _add_static_body("RockColliders")
	for spot in _scatter(rock_count, clearing_radius - 2.0, play_radius - 1.0, 0.9):
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
	_add_multimesh("Rocks", _rock_mesh(_material(ROCK_COLOR, true)), rocks, tints)


func _build_bushes() -> void:
	var bushes: Array[Transform3D] = []
	var tints: Array[Color] = []
	for spot in _scatter(bush_count, clearing_radius, play_radius + edge_depth * 0.5, 0.7):
		var size := _rng.randf_range(0.7, 1.3)
		bushes.append(Transform3D(Basis(Vector3.UP, _rng.randf() * TAU).scaled(Vector3.ONE * size), spot))
		tints.append(_random_tint())
	var instance := _add_multimesh("Bushes", _bush_mesh(_material(BUSH_COLOR, true)), bushes, tints)
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


## A ring of invisible boxes just inside the edge trees.
func _build_edge_wall() -> void:
	var body := _add_static_body("EdgeWall")
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
	var cell := _cell_of(point)
	var reach := ceili((keep_out + MAX_KEEP_OUT) / GRID_CELL)
	for x in range(cell.x - reach, cell.x + reach + 1):
		for y in range(cell.y - reach, cell.y + reach + 1):
			for other: Vector3 in _grid.get(Vector2i(x, y), []):
				if point.distance_to(Vector2(other.x, other.y)) < keep_out + other.z:
					return false
	return true


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

func _add_multimesh(node_name: String, mesh: Mesh, xforms: Array[Transform3D], tints: Array[Color] = []) -> MultiMeshInstance3D:
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_colors = not tints.is_empty()
	multimesh.mesh = mesh
	multimesh.instance_count = xforms.size()
	for i in xforms.size():
		multimesh.set_instance_transform(i, xforms[i])
		if multimesh.use_colors:
			multimesh.set_instance_color(i, tints[i])
	var instance := MultiMeshInstance3D.new()
	instance.name = node_name
	instance.multimesh = multimesh
	_generated.add_child(instance)
	return instance


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
# Each mesh is put together from Godot's built-in shapes, then given flat
# (faceted) shading for the low-poly look.


func _material(color: Color, tinted: bool) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 1.0
	# Lets each MultiMesh instance's tint colour change the shade.
	material.vertex_color_use_as_albedo = tinted
	return material


func _pine_trunk_mesh(material: Material) -> ArrayMesh:
	return _flat_mesh(material, [
		[_cylinder(0.1, 0.2, 1.6, 6), Transform3D(Basis.IDENTITY, Vector3(0.0, 0.8, 0.0))],
	])


func _pine_needles_mesh(material: Material) -> ArrayMesh:
	return _flat_mesh(material, [
		[_cylinder(0.0, 1.4, 1.8, 7), Transform3D(Basis.IDENTITY, Vector3(0.0, 2.1, 0.0))],
		[_cylinder(0.0, 1.1, 1.5, 7), Transform3D(Basis(Vector3.UP, 0.4), Vector3(0.0, 3.0, 0.0))],
		[_cylinder(0.0, 0.75, 1.3, 7), Transform3D(Basis(Vector3.UP, 0.9), Vector3(0.0, 3.8, 0.0))],
	])


func _leafy_trunk_mesh(material: Material) -> ArrayMesh:
	return _flat_mesh(material, [
		[_cylinder(0.14, 0.24, 2.4, 6), Transform3D(Basis.IDENTITY, Vector3(0.0, 1.2, 0.0))],
	])


func _leafy_crown_mesh(material: Material) -> ArrayMesh:
	return _flat_mesh(material, [
		[_sphere(1.4, 7, 4), Transform3D(Basis.from_scale(Vector3(1.0, 0.85, 1.0)), Vector3(0.0, 3.0, 0.0))],
		[_sphere(0.9, 6, 3), Transform3D(Basis.IDENTITY, Vector3(0.6, 3.6, 0.3))],
		[_sphere(0.8, 6, 3), Transform3D(Basis.IDENTITY, Vector3(-0.6, 2.7, -0.4))],
	])


func _rock_mesh(material: Material) -> ArrayMesh:
	return _flat_mesh(material, [
		[_sphere(0.6, 6, 3), Transform3D(Basis.from_scale(Vector3(1.2, 0.8, 1.0)), Vector3(0.0, 0.15, 0.0))],
	])


func _bush_mesh(material: Material) -> ArrayMesh:
	return _flat_mesh(material, [
		[_sphere(0.55, 6, 3), Transform3D(Basis.from_scale(Vector3(1.0, 0.8, 1.0)), Vector3(0.0, 0.3, 0.0))],
		[_sphere(0.4, 6, 3), Transform3D(Basis.IDENTITY, Vector3(0.4, 0.35, 0.2))],
	])


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


## Joins several [shape, transform] pairs into one mesh where every triangle
## gets its own flat normal.
func _flat_mesh(material: Material, parts: Array) -> ArrayMesh:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for part in parts:
		var arrays: Array = (part[0] as PrimitiveMesh).get_mesh_arrays()
		var xform: Transform3D = part[1]
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
				tool.add_vertex(point)
	tool.set_material(material)
	return tool.commit()
