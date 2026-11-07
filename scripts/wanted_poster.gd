extends Node3D
## A wanted poster pinned to a tree with a throwing knife (PRD W-1, W-2).
##
## Walk up and press interact to pull the knife out. A new knife appears in the
## poster after respawn_delay seconds of world time (W-6). The portrait shows the
## current wave's mini boss, with its name and wave number (W-5). The wave
## manager calls show_mini_boss() on every poster when a new boss is coming.

const MiniBosses := preload("res://scripts/mini_bosses.gd")
const Config := preload("res://scripts/game_config.gd")

## Seconds (world time) before a new knife appears after one is pulled out.
@export var respawn_delay := Config.POSTER_RESPAWN_DELAY

var has_knife := true

var _respawn_timer: SceneTreeTimer
var _bust: Node3D

@onready var _knife: Node3D = $Knife
@onready var _portrait: Node3D = $Portrait
@onready var _unknown: Label3D = $Portrait/Unknown
@onready var _boss_name: Label3D = $BossName
@onready var _wave_number: Label3D = $WaveNumber


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


## Draws `info`'s mini boss (from MiniBosses.info()) on the poster: a little bust
## in its colours and headgear, with its name and wave underneath.
func show_mini_boss(info: Dictionary) -> void:
	if is_instance_valid(_bust):
		_bust.queue_free()
	_bust = Node3D.new()
	_bust.name = "Bust"
	_portrait.add_child(_bust)
	# The bust is built facing -Z like a real dummy, so turn it round to face out of the poster.
	_bust.transform = Transform3D(Basis(Vector3.UP, PI), Vector3(0.0, -0.02, 0.012))

	var color: Color = info["color"]
	var stitch := Color(0.2, 0.13, 0.08)
	var head_size := 0.12
	var depth := 0.02
	var head := Node3D.new()
	_bust.add_child(head)
	MiniBosses.add_box(head, Vector3(head_size, head_size, depth), color.lightened(0.1), Vector3.ZERO)
	MiniBosses.add_box(_bust, Vector3(0.17, 0.05, depth), color, Vector3(0.0, -0.085, 0.0))
	for x in [-0.028, 0.028]:
		for tilt in [PI / 4.0, -PI / 4.0]:
			MiniBosses.add_box(head, Vector3(0.036, 0.007, 0.004), stitch, Vector3(x, 0.012, -depth * 0.5 - 0.002), tilt)
	MiniBosses.add_box(head, Vector3(0.05, 0.006, 0.004), stitch, Vector3(0.0, -0.028, -depth * 0.5 - 0.002))
	MiniBosses.add_headgear(head, info["headgear"], head_size, depth)

	_unknown.visible = false
	_boss_name.text = String(info["name"]).to_upper()
	_wave_number.text = "Wave %d" % info["wave"]
