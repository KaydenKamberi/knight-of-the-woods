extends Node3D
## The chest in the secret bunker (PRD B-3, N-3).
##
## It holds 6 diamonds and 3 titanium (BUNKER_CHEST in game_config.gd), the only
## place in the game to find them. "[E] Open chest" takes everything at once,
## with a "+6 Diamond, +3 Titanium" pop-up. It then stays open and empty for the
## rest of the run, however many times the knight comes back; a new game (Try
## Again) starts with a full chest again.

const Config := preload("res://scripts/game_config.gd")
const Art := preload("res://scripts/art.gd")
const Effects := preload("res://scripts/effects.gd")
const WOOD := Color(0.45, 0.29, 0.16)
const IRON := Color(0.3, 0.3, 0.33)
const GOLD := Color(0.86, 0.68, 0.22)

var _opened := false
var _lid: Node3D


func _ready() -> void:
	add_to_group("interactables")
	_build_model()


func can_be_picked_up() -> bool:
	return not _opened


func pickup_point() -> Vector3:
	return global_position + Vector3.UP * 0.6


func pickup_range() -> float:
	return Config.PASSAGE_USE_RANGE + 0.4


func pickup_prompt() -> String:
	return "Open chest"


func pickup_button() -> String:
	return "OPEN"


func interact() -> void:
	var inventory = get_tree().get_first_node_in_group("inventory")
	if _opened or inventory == null:
		return
	_opened = true
	var lift := create_tween()
	lift.tween_property(_lid, "rotation:x", 1.9, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	Effects.burst(global_position + Vector3.UP * 0.7, 1.2, Color(0.85, 0.97, 1.0), get_tree().current_scene)
	var found: Array[String] = []
	for id in Config.BUNKER_CHEST:
		var amount: int = Config.BUNKER_CHEST[id]
		inventory.add(id, amount, false)
		found.append("+%d %s" % [amount, Config.MATERIAL_NAMES[id]])
	WorldTime.bump()
	var hud = get_tree().get_first_node_in_group("hud")
	if hud != null:
		hud.show_popup(", ".join(found))


func _build_model() -> void:
	# The chest faces -Z (towards the room), with its lid hinged at the back.
	_box(self, Vector3(1.1, 0.55, 0.65), Vector3(0, 0.3, 0), WOOD)
	for x in [-0.42, 0.0, 0.42]:
		_box(self, Vector3(0.07, 0.57, 0.67), Vector3(x, 0.3, 0), IRON)
	_lid = Node3D.new()
	_lid.name = "Lid"
	_lid.position = Vector3(0, 0.58, 0.33)
	add_child(_lid)
	_box(_lid, Vector3(1.12, 0.22, 0.67), Vector3(0, 0.11, -0.33), WOOD.lightened(0.06))
	for x in [-0.42, 0.0, 0.42]:
		_box(_lid, Vector3(0.07, 0.24, 0.69), Vector3(x, 0.11, -0.33), IRON)
	_box(_lid, Vector3(0.14, 0.16, 0.05), Vector3(0, 0.0, -0.68), GOLD)


func _box(parent: Node3D, size: Vector3, at: Vector3, color: Color) -> void:
	var box := BoxMesh.new()
	box.size = size
	box.material = Art.material(color, {"rim": true})
	var mesh := MeshInstance3D.new()
	mesh.mesh = box
	mesh.position = at
	parent.add_child(mesh)
