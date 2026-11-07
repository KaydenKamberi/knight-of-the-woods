extends Node3D
## A wanted poster pinned to a tree with a throwing knife (PRD W-1, W-2).
##
## Walk up and press interact to pull the knife out. A new knife appears in the
## poster after respawn_delay seconds of world time (W-6). The portrait is a blank
## placeholder for now; in M4 it will show the current wave's mini boss (W-5).

## Seconds (world time) before a new knife appears after one is pulled out.
@export var respawn_delay := 5.0

var has_knife := true

var _respawn_timer: SceneTreeTimer

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
	# The timer runs on world time and stops while the game is paused.
	_respawn_timer = get_tree().create_timer(respawn_delay, false)
	_respawn_timer.timeout.connect(rearm)


# -----------------------------------------------------------------------------

## Puts a new knife through the poster, popping it in so it's easy to spot.
func rearm() -> void:
	if has_knife:
		return
	has_knife = true
	_knife.visible = true
	_knife.scale = Vector3.ONE * 0.01
	create_tween().tween_property(_knife, "scale", Vector3.ONE, 0.25) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
