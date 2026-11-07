extends Node3D
## A berry bush the knight can pick (PRD N-4).
##
## Walk up and press E (or Grab on touch) to pick its berries, a taming food for
## bunnies and deer. A picked bush has no berries until the next wave is cleared,
## then they grow back. The forest places these among its other bushes.
##
## The knight finds it through the "interactables" group, like the furnace.

const Config := preload("res://scripts/game_config.gd")
const Art := preload("res://scripts/art.gd")
const PICK_RANGE := 1.8

var _berries: Node3D
var _picked := false


func _ready() -> void:
	add_to_group("interactables")
	_build_model()
	_watch_waves.call_deferred()


func _watch_waves() -> void:
	var waves = get_tree().get_first_node_in_group("wave_manager")
	if waves != null:
		waves.wave_cleared.connect(_regrow)


# --- Used by the knight's E / Grab (see knight.gd) -------------------------------

func can_be_picked_up() -> bool:
	return not _picked


func pickup_point() -> Vector3:
	return global_position + Vector3.UP * 0.5


func pickup_range() -> float:
	return PICK_RANGE


func pickup_prompt() -> String:
	return "Pick berries"


func pickup_button() -> String:
	return "PICK"


func interact() -> void:
	if _picked:
		return
	var inventory = get_tree().get_first_node_in_group("inventory")
	if inventory == null:
		return
	_picked = true
	_berries.visible = false
	inventory.add("berries", Config.BERRIES_PER_BUSH)
	WorldTime.bump()


func _regrow(_wave: int) -> void:
	_picked = false
	_berries.visible = true


# --- The model ----------------------------------------------------------------------

func _build_model() -> void:
	var leaf := Art.material(Art.color("leaf_2"), {"sway": 0.6})
	var leaf_dark := Art.material(Art.color("leaf_2").darkened(0.12), {"sway": 0.6})
	_sphere(self, 0.55, Vector3(0.0, 0.32, 0.0), Vector3(1.0, 0.8, 1.0), leaf)
	_sphere(self, 0.4, Vector3(0.38, 0.36, 0.18), Vector3.ONE, leaf_dark)
	_sphere(self, 0.36, Vector3(-0.32, 0.3, -0.2), Vector3.ONE, leaf_dark)
	_berries = Node3D.new()
	_berries.name = "Berries"
	add_child(_berries)
	var berry := Art.material(Art.color("berry"), {"rim": true})
	for i in 9:
		var angle := TAU * i / 9.0 + 0.2
		var spot := Vector3(cos(angle) * 0.52, 0.3 + 0.14 * (i % 3), sin(angle) * 0.48)
		_sphere(_berries, 0.075, spot, Vector3.ONE, berry)


func _sphere(parent: Node3D, radius: float, at: Vector3, stretch: Vector3, material: Material) -> void:
	var sphere := SphereMesh.new()
	sphere.radius = radius
	sphere.height = radius * 2.0
	sphere.radial_segments = 6
	sphere.rings = 3
	sphere.material = material
	var mesh := MeshInstance3D.new()
	mesh.mesh = sphere
	mesh.position = at
	mesh.scale = stretch
	parent.add_child(mesh)
