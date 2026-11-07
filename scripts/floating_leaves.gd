extends Node3D
## Leaves drifting slowly through the forest air (M7, 1E).
##
## One CPUParticles3D that follows the camera, so there are always a few leaves
## around wherever the player looks. It runs on world time, so the leaves hang
## almost still when time slows. How many there are follows the graphics
## setting (none on Low).

const Config := preload("res://scripts/game_config.gd")
const AREA := Vector3(14.0, 5.0, 14.0)

var _leaves: CPUParticles3D


func _ready() -> void:
	add_to_group("floating_leaves")
	_leaves = CPUParticles3D.new()
	_leaves.local_coords = false
	_leaves.lifetime = 9.0
	_leaves.preprocess = 9.0
	_leaves.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	_leaves.emission_box_extents = AREA
	_leaves.direction = Vector3(1.0, -0.2, 0.3)
	_leaves.spread = 40.0
	_leaves.initial_velocity_min = 0.3
	_leaves.initial_velocity_max = 0.8
	_leaves.gravity = Vector3(0.0, -0.25, 0.0)
	_leaves.angular_velocity_min = -90.0
	_leaves.angular_velocity_max = 90.0
	_leaves.scale_amount_min = 0.7
	_leaves.scale_amount_max = 1.3
	_leaves.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var leaf := QuadMesh.new()
	leaf.size = Vector2(0.14, 0.09)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.vertex_color_use_as_albedo = true
	leaf.material = material
	_leaves.mesh = leaf
	var colors := Gradient.new()
	colors.set_color(0, Config.PALETTE["leaf_2"])
	colors.set_color(1, Config.PALETTE["flower_1"].lerp(Config.PALETTE["leaf_1"], 0.5))
	_leaves.color_initial_ramp = colors
	add_child(_leaves)
	apply_graphics()


func _process(_delta: float) -> void:
	var camera := get_viewport().get_camera_3d()
	if camera != null:
		global_position = camera.global_position + Vector3(0.0, 1.0, 0.0)


## Called by the Graphics autoload when the setting changes.
func apply_graphics() -> void:
	var count: int = Graphics.setting("floating_leaves", 0)
	_leaves.emitting = count > 0
	_leaves.visible = count > 0
	if count > 0:
		_leaves.amount = count
