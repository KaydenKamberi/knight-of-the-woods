extends Node3D
## A wanted poster pinned to a tree with a throwing knife (PRD W-1, W-2).
##
## Walk up and press interact to pull the knife out. The portrait is a blank
## placeholder for now; in M4 it will show the current wave's mini boss (W-5).

var has_knife := true

@onready var _knife: Node3D = $Knife


func _ready() -> void:
	add_to_group("wanted_posters")
	add_to_group("knife_pickups")
	_knife.visible = has_knife


# --- Pickup (the knight looks for nodes in the "knife_pickups" group) -------

func can_be_picked_up() -> bool:
	return has_knife


func pickup_point() -> Vector3:
	return _knife.global_position


func pickup_prompt() -> String:
	return "Pull the knife from the poster"


func pick_up() -> void:
	has_knife = false
	_knife.visible = false


# -----------------------------------------------------------------------------

## Puts a knife back through the poster (used for knives that flew off into nothing).
func rearm() -> void:
	has_knife = true
	_knife.visible = true
