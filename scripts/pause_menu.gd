extends Control
## The pause menu (M7): Esc on PC, the pause icon on touch screens. The game
## freezes while it's open. Resume, change the graphics setting, or go back to
## the title screen. Centred with the same full-screen root and CenterContainer
## as the crafting menu, so it can't go off screen.

signal resume_requested
signal main_menu_requested

const GraphicsPicker := preload("res://scripts/graphics_picker.gd")
const UiStyle := preload("res://scripts/ui_style.gd")


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.03, 0.03, 0.7)
	add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center := CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiStyle.panel())
	center.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 16)
	panel.add_child(column)
	var title := Label.new()
	title.text = "Paused"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 40)
	column.add_child(title)
	column.add_child(_button("Resume", _on_resume))
	column.add_child(GraphicsPicker.new())
	column.add_child(_button("Main Menu", _on_main_menu))


func open() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = true


func _unhandled_input(event: InputEvent) -> void:
	# Esc (or the pause icon) again resumes.
	if visible and event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		resume_requested.emit()


func _button(text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(260, 56)
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	button.pressed.connect(action)
	return button


func _on_resume() -> void:
	resume_requested.emit()


func _on_main_menu() -> void:
	main_menu_requested.emit()
