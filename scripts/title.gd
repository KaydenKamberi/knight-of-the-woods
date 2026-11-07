extends Node3D
## The title screen (M7, Part 5). Behind the menu the camera pans slowly over
## the forest towards the castle. Play starts a fresh run at wave 1, Settings
## holds the graphics picker (there are no sounds yet, so no volume), and Quit
## only shows on PC (not on the web or on phones). The name comes from
## GAME_TITLE in game_config.gd, so it's easy to change.

const Config := preload("res://scripts/game_config.gd")
const UiStyle := preload("res://scripts/ui_style.gd")
const GraphicsPicker := preload("res://scripts/graphics_picker.gd")
const GAME_SCENE := "res://scenes/forest.tscn"
## The camera swings slowly back and forth around this point, at this distance and height.
const VIEW_CENTER := Vector3(0.0, 0.0, 16.0)
const VIEW_DISTANCE := 27.0
const VIEW_HEIGHT := 7.0

var _time := 0.0
var _main: Control
var _settings: Control

@onready var _camera: Camera3D = $Camera3D


func _ready() -> void:
	get_tree().paused = false
	# Nobody is walking here, so keep world time at full speed: the wind and the log move.
	WorldTime.set_override(1.0)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_build_menu()


func _process(_delta: float) -> void:
	_time += WorldTime.real_delta
	var swing := sin(_time * 0.12) * 0.6
	var eye := VIEW_CENTER + Vector3(sin(swing) * VIEW_DISTANCE, VIEW_HEIGHT + sin(_time * 0.09), -cos(swing) * VIEW_DISTANCE)
	_camera.global_position = eye
	_camera.look_at(Config.CASTLE_CENTER + Vector3(0.0, 3.0, -4.0), Vector3.UP)


func _build_menu() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var root := Control.new()
	layer.add_child(root)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var center := CenterContainer.new()
	root.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE

	_main = VBoxContainer.new()
	_main.add_theme_constant_override("separation", 18)
	center.add_child(_main)
	var title := Label.new()
	title.text = Config.GAME_TITLE
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 64)
	title.add_theme_color_override("font_color", Config.PALETTE["knight_gold"].lightened(0.25))
	title.add_theme_color_override("font_outline_color", Color(0.1, 0.07, 0.04, 1))
	title.add_theme_constant_override("outline_size", 14)
	_main.add_child(title)
	var tagline := Label.new()
	tagline.text = "Time only moves when you move."
	tagline.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tagline.add_theme_font_size_override("font_size", 22)
	tagline.add_theme_constant_override("outline_size", 6)
	_main.add_child(tagline)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 20)
	_main.add_child(gap)
	_main.add_child(_button("Play", _on_play))
	_main.add_child(_button("Settings", _on_settings))
	var quit := _button("Quit", _on_quit)
	# Quitting means nothing in a web page or on a phone.
	quit.visible = not (OS.has_feature("web") or OS.has_feature("mobile") or DisplayServer.is_touchscreen_available())
	_main.add_child(quit)

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiStyle.panel())
	panel.visible = false
	center.add_child(panel)
	_settings = panel
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 16)
	panel.add_child(column)
	var heading := Label.new()
	heading.text = "Settings"
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_font_size_override("font_size", 36)
	column.add_child(heading)
	column.add_child(GraphicsPicker.new())
	column.add_child(_button("Back", _on_back))


func _button(text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(280, 60)
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	button.pressed.connect(action)
	return button


func _on_play() -> void:
	WorldTime.clear_override()
	get_tree().change_scene_to_file(GAME_SCENE)


func _on_settings() -> void:
	_main.visible = false
	_settings.visible = true


func _on_back() -> void:
	_settings.visible = false
	_main.visible = true


func _on_quit() -> void:
	get_tree().quit()
