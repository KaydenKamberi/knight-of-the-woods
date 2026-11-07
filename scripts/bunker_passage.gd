extends Node3D
## A way into or out of the secret bunker (PRD B-1, B-2): the forest trapdoor,
## the hidden door in the castle wall, and the ladder and tunnel inside.
##
## Walking up shows its prompt (only when close, so the entrances stay hidden);
## E or Grab (on touch, the button shows this passage's word) takes the knight
## through. The trapdoor or stone opens first (the bunker script listens to
## `used`), then the screen fades to black and he comes out at `destination`,
## facing `facing`. It works any time, during breaks or waves, as often as the
## player likes.
##
## The bunker script sets the fields below before adding this to the scene.

## Sent when the knight uses this passage, so the bunker can open the trapdoor or stone.
signal used

const Config := preload("res://scripts/game_config.gd")

var prompt := "Enter"
var button := "ENTER"
## Where the knight comes out, and which way he faces there.
var destination := Vector3.ZERO
var facing := Vector3.FORWARD
## True if this leads into the bunker, false if it leads back out.
var leads_inside := true
## Where the knight has to stand near, measured from this node.
var use_point := Vector3.UP
## Real seconds to wait (while the door opens) before the knight goes through.
var open_delay := 0.0

var _busy := false


func _ready() -> void:
	add_to_group("interactables")


func can_be_picked_up() -> bool:
	return not _busy


func pickup_point() -> Vector3:
	return to_global(use_point)


func pickup_range() -> float:
	return Config.PASSAGE_USE_RANGE


func pickup_prompt() -> String:
	return prompt


func pickup_button() -> String:
	return button


func interact() -> void:
	if _busy:
		return
	_busy = true
	used.emit()
	if open_delay > 0.0:
		get_tree().create_timer(open_delay, false, false, true).timeout.connect(_go_through)
	else:
		_go_through()


func _go_through() -> void:
	_busy = false
	var knight = get_tree().get_first_node_in_group("player")
	if knight != null:
		knight.travel_to(destination, facing, leads_inside)
