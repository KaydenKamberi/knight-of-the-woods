extends StaticBody3D
## The built furnace in the castle courtyard (PRD R-14). It's built once, from
## its hologram, and stays for the rest of the game. Smelting happens in the
## furnace panel; each smelt calls flame_burst() so the fire flares up in its
## mouth. Between smelts the fire just glows faintly.

const Effects := preload("res://scripts/effects.gd")
const Art := preload("res://scripts/art.gd")
const Fx := preload("res://scripts/fx.gd")
const STONE := Color(0.62, 0.62, 0.6)
const DARK_STONE := Color(0.45, 0.46, 0.46)
const FIRE := Color(1.0, 0.45, 0.1)
## Where the fire's mouth is, on the furnace's front (-Z) side.
const MOUTH := Vector3(0, 0.45, -0.61)
const EMBER_GLOW := 0.3
const EMBER_LIGHT := 0.15

var _model: Node3D
var _glow: Material
var _light: OmniLight3D


## Builds the furnace's shape under `parent`. With `override`, every part uses
## that material (the see-through hologram). Returns the fire's material.
static func build_model(parent: Node3D, override: Material = null) -> Material:
	_box(parent, Vector3(1.4, 1.1, 1.2), Vector3(0, 0.55, 0), STONE, override)
	_box(parent, Vector3(1.5, 0.15, 1.3), Vector3(0, 1.15, 0), DARK_STONE, override)
	_box(parent, Vector3(1.0, 0.5, 0.9), Vector3(0, 1.45, 0), STONE, override)
	_box(parent, Vector3(0.4, 1.0, 0.4), Vector3(0.3, 2.2, 0.2), DARK_STONE, override)
	# The fire has a material of its own, so it can flare up when smelting.
	var glow := Art.material(FIRE, {"emission": FIRE, "energy": EMBER_GLOW, "unique": true})
	_box(parent, Vector3(0.6, 0.45, 0.05), MOUTH, FIRE, override if override != null else glow)
	return glow


static func _box(parent: Node3D, size: Vector3, at: Vector3, color: Color, material: Material) -> void:
	var box := BoxMesh.new()
	box.size = size
	if material != null:
		box.material = material
	else:
		box.material = Art.material(color)
	var mesh := MeshInstance3D.new()
	mesh.mesh = box
	mesh.position = at
	parent.add_child(mesh)


func _ready() -> void:
	add_to_group("furnace")
	_model = Node3D.new()
	_model.name = "Model"
	add_child(_model)
	_glow = build_model(_model)
	_light = OmniLight3D.new()
	_light.light_color = Color(1.0, 0.55, 0.2)
	_light.light_energy = EMBER_LIGHT
	_light.omni_range = 4.0
	_light.position = MOUTH + Vector3(0, 0.1, -0.4)
	_model.add_child(_light)

	var shape := BoxShape3D.new()
	shape.size = Vector3(1.4, 1.7, 1.2)
	var collision := CollisionShape3D.new()
	collision.shape = shape
	collision.position = Vector3(0, 0.85, 0)
	add_child(collision)

	# Pop up with a puff of dust. (Only the model scales: physics bodies shouldn't be scaled.)
	_model.scale = Vector3.ONE * 0.01
	create_tween().tween_property(_model, "scale", Vector3.ONE, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	Effects.burst(global_position + Vector3.UP * 0.6, 2.2, Color(0.62, 0.57, 0.48), get_tree().current_scene)


## The fire flares up for a moment: called each time something is smelted.
func flame_burst() -> void:
	Art.set_emission(_glow, FIRE, 4.0)
	_light.light_energy = 2.5
	var settle := create_tween().set_parallel()
	settle.tween_property(_glow, "shader_parameter/emission_energy", EMBER_GLOW, 0.6)
	settle.tween_property(_light, "light_energy", EMBER_LIGHT, 0.6)
	Effects.burst(to_global(MOUTH + Vector3(0, 0, -0.2)), 0.7, FIRE, get_tree().current_scene)
	Fx.furnace_sparks(to_global(MOUTH + Vector3(0, 0.1, -0.3)))
