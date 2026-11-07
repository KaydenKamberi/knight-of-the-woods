extends RefCounted
## Low-poly models of the crafted weapons, held in the knight's right hand.
## Each is built from boxes, pointing along -Z from the grip at the origin.

const KNIFE_MODEL := preload("res://scenes/knife_model.tscn")
const Art := preload("res://scripts/art.gd")
const WOOD := Color(0.45, 0.3, 0.17)
const STEEL := Color(0.75, 0.77, 0.82)
const DARK := Color(0.25, 0.25, 0.28)
const ICE := Color(0.55, 0.85, 1.0)
const ULTRA := Color(0.8, 0.35, 1.0)
const DIAMOND := Color(0.78, 0.95, 1.0)


## Builds the model for `weapon` ("knife", "spear", ...). `layer` is the render
## layer for its meshes (the knight's layer, so first person hides it).
static func build(weapon: String, layer: int) -> Node3D:
	var root := Node3D.new()
	root.name = "Held_" + weapon
	match weapon:
		"knife":
			root.add_child(KNIFE_MODEL.instantiate())
		"spear":
			_box(root, Vector3(0.04, 0.04, 2.0), WOOD, Vector3(0, 0, -0.6))
			_box(root, Vector3(0.08, 0.03, 0.26), STEEL, Vector3(0, 0, -1.72), true)
		"sword":
			_box(root, Vector3(0.035, 0.035, 0.14), DARK, Vector3(0, 0, 0.05))
			_box(root, Vector3(0.18, 0.03, 0.04), Color(0.85, 0.68, 0.25), Vector3(0, 0, -0.03))
			_box(root, Vector3(0.06, 0.015, 0.75), STEEL, Vector3(0, 0, -0.43), true)
		"axe":
			_box(root, Vector3(0.04, 0.04, 0.85), WOOD, Vector3(0, 0, -0.32))
			_box(root, Vector3(0.04, 0.26, 0.2), STEEL, Vector3(0, 0.12, -0.64), true)
		"bow":
			_box(root, Vector3(0.03, 0.55, 0.03), WOOD, Vector3(0, 0, -0.08))
			var upper := _box(root, Vector3(0.03, 0.32, 0.03), WOOD, Vector3(0, 0.38, -0.02))
			upper.rotation.x = -0.5
			var lower := _box(root, Vector3(0.03, 0.32, 0.03), WOOD, Vector3(0, -0.38, -0.02))
			lower.rotation.x = 0.5
			_box(root, Vector3(0.006, 1.0, 0.006), Color(0.95, 0.95, 0.9), Vector3(0, 0, 0.1))
		"cryo_dagger":
			_box(root, Vector3(0.03, 0.03, 0.1), DARK, Vector3(0, 0, 0.04))
			_box(root, Vector3(0.045, 0.012, 0.3), ICE, Vector3(0, 0, -0.17), true, true)
		"cryo_hammer":
			_box(root, Vector3(0.05, 0.05, 0.95), WOOD, Vector3(0, 0, -0.35))
			_box(root, Vector3(0.3, 0.22, 0.24), ICE, Vector3(0, 0, -0.85), true, true)
		"diamond_sword":
			_box(root, Vector3(0.035, 0.035, 0.14), DARK, Vector3(0, 0, 0.05))
			_box(root, Vector3(0.2, 0.035, 0.045), Color(0.85, 0.68, 0.25), Vector3(0, 0, -0.03))
			_box(root, Vector3(0.07, 0.018, 0.8), DIAMOND, Vector3(0, 0, -0.45), true, true)
		"diamond_axe":
			_box(root, Vector3(0.04, 0.04, 0.85), WOOD, Vector3(0, 0, -0.32))
			_box(root, Vector3(0.045, 0.3, 0.22), DIAMOND, Vector3(0, 0.13, -0.64), true, true)
		"diamond_dagger":
			_box(root, Vector3(0.03, 0.03, 0.1), WOOD, Vector3(0, 0, 0.04))
			_box(root, Vector3(0.11, 0.025, 0.03), Color(0.85, 0.68, 0.25), Vector3(0, 0, -0.02))
			_box(root, Vector3(0.045, 0.014, 0.28), DIAMOND, Vector3(0, 0, -0.17), true, true)
		"dagger":
			_box(root, Vector3(0.03, 0.03, 0.1), WOOD, Vector3(0, 0, 0.04))
			_box(root, Vector3(0.11, 0.025, 0.03), DARK, Vector3(0, 0, -0.02))
			_box(root, Vector3(0.04, 0.012, 0.26), STEEL, Vector3(0, 0, -0.16), true)
		"bat":
			_box(root, Vector3(0.05, 0.05, 0.3), WOOD.darkened(0.2), Vector3(0, 0, -0.05))
			_box(root, Vector3(0.08, 0.08, 0.35), WOOD, Vector3(0, 0, -0.36))
			_box(root, Vector3(0.11, 0.11, 0.3), WOOD.lightened(0.08), Vector3(0, 0, -0.66))
		"grenade":
			var ball := SphereMesh.new()
			ball.radius = 0.1
			ball.height = 0.18
			ball.radial_segments = 8
			ball.rings = 4
			ball.material = _material(Color(0.22, 0.24, 0.2), true, false)
			var ball_mesh := MeshInstance3D.new()
			ball_mesh.mesh = ball
			ball_mesh.position = Vector3(0, 0, -0.08)
			root.add_child(ball_mesh)
			_box(root, Vector3(0.04, 0.07, 0.04), Color(1.0, 0.6, 0.2), Vector3(0, 0.1, -0.08), false, true)
		"ultra_blaster":
			var tube := CylinderMesh.new()
			tube.top_radius = 0.07
			tube.bottom_radius = 0.08
			tube.height = 0.55
			tube.radial_segments = 8
			tube.rings = 0
			tube.material = _material(DARK, true, false)
			var tube_mesh := MeshInstance3D.new()
			tube_mesh.mesh = tube
			tube_mesh.transform = Transform3D(Basis(Vector3.RIGHT, PI / 2.0), Vector3(0, 0.05, -0.2))
			root.add_child(tube_mesh)
			_box(root, Vector3(0.1, 0.1, 0.12), ULTRA, Vector3(0, 0.12, 0.05), false, true)
	_set_layer(root, layer)
	return root


static func _box(parent: Node3D, size: Vector3, color: Color, at: Vector3, shiny := false, glow := false) -> MeshInstance3D:
	var box := BoxMesh.new()
	box.size = size
	box.material = _material(color, shiny, glow)
	var mesh := MeshInstance3D.new()
	mesh.mesh = box
	mesh.position = at
	parent.add_child(mesh)
	return mesh


## Toon materials: shiny parts get a little rim light, glowing ones (Cryo, Ultra) glow.
static func _material(color: Color, shiny: bool, glow: bool) -> Material:
	var options := {"rim": shiny}
	if glow:
		options["emission"] = color
		options["energy"] = 1.2
	return Art.material(color, options)


static func _set_layer(node: Node, layer: int) -> void:
	if node is VisualInstance3D:
		(node as VisualInstance3D).layers = layer
	for child in node.get_children():
		_set_layer(child, layer)
