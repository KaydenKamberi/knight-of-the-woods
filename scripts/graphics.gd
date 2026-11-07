extends Node
## Graphics settings: Low (potato), Medium and High (PRD F-3, F-5, M7).
##
## An autoload, so any script can reach it as `Graphics`. The numbers for each
## level live in GRAPHICS_LEVELS in game_config.gd. Changing the level applies
## straight away (no restart) and is saved to user://settings.cfg, so it's
## remembered next time. On the very first launch, phones and touch devices
## start on Low and PCs on High.
##
## What each level controls:
## - shadows (off / knight and bosses / everything), render resolution, view distance
## - grass and how far it sways, leaf sway, toon steps and the rim light
## - fog and colour grade, how many particles and floating leaves, and how many
##   defeated enemies' pieces stay on the ground
##
## It also drives the shaders' shared settings (TOON_* and the palette) and the
## world_time clock that makes the wind sway, which follows world time (T-3).
## In debug builds it shows an FPS counter in the corner.

signal level_changed(level: String)

const Config := preload("res://scripts/game_config.gd")
const UiStyle := preload("res://scripts/ui_style.gd")
const SETTINGS_PATH := "user://settings.cfg"

var level := "high"

var _world_clock := 0.0
var _fps_label: Label


func _ready() -> void:
	_load()
	get_tree().root.theme = UiStyle.theme()
	_push_shader_settings()
	_apply()
	if OS.is_debug_build():
		_add_fps_counter()


func _process(delta: float) -> void:
	# delta is already scaled by world time, so the wind slows down with the world.
	_world_clock += delta
	RenderingServer.global_shader_parameter_set("world_time", _world_clock)
	if _fps_label != null:
		_fps_label.text = "%d FPS (%s)" % [Engine.get_frames_per_second(), level.capitalize()]


## A setting for the current level, like setting("ragdolls_kept").
func setting(key: String, fallback = null):
	return Config.GRAPHICS_LEVELS[level].get(key, fallback)


func set_level(new_level: String) -> void:
	if not Config.GRAPHICS_LEVELS.has(new_level) or new_level == level:
		return
	level = new_level
	_save()
	_apply()
	level_changed.emit(level)


## Shadows on a character (or anything else): important ones (the knight and
## bosses) keep their shadow on Medium; the rest only cast one on High.
func register_shadow_caster(node: Node, important: bool) -> void:
	node.add_to_group("important_shadow" if important else "minor_shadow")
	_apply_shadow(node, important)


## Scenery (chunks of trees, rocks, bushes, grass) registers here so its view
## distance, shadows and grass density follow the setting. kind: "trees",
## "small" (rocks, bushes, flowers) or "grass".
func register_scenery(instance: GeometryInstance3D, kind: String) -> void:
	instance.add_to_group("scenery_" + kind)
	_apply_scenery(instance, kind)


## Called by the WorldLook scene (sky, sun, fog) when it appears.
func apply_to_world(world_look: Node) -> void:
	var environment: Environment = world_look.environment()
	var view: float = setting("view_distance")
	# Fog thick enough that the forest melts into it just before the view distance.
	environment.fog_density = 2.2 / maxf(view, 1.0)
	environment.adjustment_enabled = setting("color_grade")
	world_look.sun().shadow_enabled = setting("shadows") != "off"


# -----------------------------------------------------------------------------

func _apply() -> void:
	var tree := get_tree()
	tree.root.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
	tree.root.scaling_3d_scale = setting("render_scale")
	var view: float = setting("view_distance")
	RenderingServer.global_shader_parameter_set("fade_end", view)
	RenderingServer.global_shader_parameter_set("fade_start", maxf(view - Config.FADE_BAND, 1.0))
	RenderingServer.global_shader_parameter_set("toon_steps", setting("toon_steps"))
	RenderingServer.global_shader_parameter_set("toon_rim", setting("rim"))
	RenderingServer.global_shader_parameter_set("leaf_sway", setting("leaf_sway"))
	RenderingServer.global_shader_parameter_set("grass_wind", setting("grass_wind"))
	for world_look in tree.get_nodes_in_group("world_look"):
		apply_to_world(world_look)
	for node in tree.get_nodes_in_group("important_shadow"):
		_apply_shadow(node, true)
	for node in tree.get_nodes_in_group("minor_shadow"):
		_apply_shadow(node, false)
	for kind in ["trees", "small", "grass"]:
		for instance in tree.get_nodes_in_group("scenery_" + kind):
			_apply_scenery(instance, kind)
	tree.call_group("floating_leaves", "apply_graphics")


func _apply_shadow(node: Node, important: bool) -> void:
	var shadows: String = setting("shadows")
	var on := shadows == "all" or (shadows == "important" and important)
	_set_cast_shadow(node, on)


func _set_cast_shadow(node: Node, on: bool) -> void:
	if node is GeometryInstance3D:
		(node as GeometryInstance3D).cast_shadow = \
				GeometryInstance3D.SHADOW_CASTING_SETTING_ON if on else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for child in node.get_children():
		_set_cast_shadow(child, on)


func _apply_scenery(instance: GeometryInstance3D, kind: String) -> void:
	var view: float = setting("view_distance")
	match kind:
		"trees":
			# Chunks are big, so allow for their size before cutting them off.
			instance.visibility_range_end = view + Config.SCENERY_CHUNK
			_set_cast_shadow(instance, setting("shadows") == "all")
		"small":
			instance.visibility_range_end = view * 0.6 + Config.SCENERY_CHUNK * 0.5
			_set_cast_shadow(instance, false)
		"grass":
			var share: float = setting("grass")
			instance.visible = share > 0.0
			instance.visibility_range_end = view * 0.5 + Config.SCENERY_CHUNK * 0.5
			var multimesh: MultiMesh = null
			if instance is MultiMeshInstance3D:
				multimesh = (instance as MultiMeshInstance3D).multimesh
			if multimesh != null:
				multimesh.visible_instance_count = int(multimesh.instance_count * share)
			_set_cast_shadow(instance, false)


func _push_shader_settings() -> void:
	RenderingServer.global_shader_parameter_set("toon_shadow_tint", Config.TOON_SHADOW_TINT)
	RenderingServer.global_shader_parameter_set("toon_shadow_fill", Config.TOON_SHADOW_FILL)
	RenderingServer.global_shader_parameter_set("toon_mid_level", Config.TOON_MID_LEVEL)
	RenderingServer.global_shader_parameter_set("toon_threshold_low", Config.TOON_THRESHOLD_LOW)
	RenderingServer.global_shader_parameter_set("toon_threshold_high", Config.TOON_THRESHOLD_HIGH)
	RenderingServer.global_shader_parameter_set("toon_softness", Config.TOON_SOFTNESS)
	RenderingServer.global_shader_parameter_set("toon_rim_color", Config.TOON_RIM_COLOR)


func _load() -> void:
	var file := ConfigFile.new()
	if file.load(SETTINGS_PATH) == OK:
		var saved: String = file.get_value("graphics", "level", "")
		if Config.GRAPHICS_LEVELS.has(saved):
			level = saved
			return
	# First launch: Low on phones and touch devices, High on PC.
	var touch := DisplayServer.is_touchscreen_available() or OS.has_feature("mobile") \
			or OS.has_feature("web_android") or OS.has_feature("web_ios")
	level = "low" if touch else "high"
	_save()


func _save() -> void:
	var file := ConfigFile.new()
	file.load(SETTINGS_PATH)
	file.set_value("graphics", "level", level)
	file.save(SETTINGS_PATH)


func _add_fps_counter() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 100
	add_child(layer)
	_fps_label = Label.new()
	_fps_label.position = Vector2(8, 696)
	_fps_label.add_theme_font_size_override("font_size", 14)
	_fps_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_fps_label.add_theme_constant_override("outline_size", 4)
	_fps_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_fps_label)
