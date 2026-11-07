extends VBoxContainer
## Low / Medium / High buttons for the graphics setting (M7). Used by the pause
## menu and the title screen's Settings. The change applies straight away and
## is remembered next time (the Graphics autoload saves it).

const Config := preload("res://scripts/game_config.gd")
const DESCRIPTIONS := {
	"low": "Low (potato): smooth on phones. No shadows or grass, fewer effects.",
	"medium": "Medium: shadows on the knight and bosses, some grass and effects.",
	"high": "High: everything on. Best on a PC.",
}

var _buttons := {}
var _description: Label


func _ready() -> void:
	add_theme_constant_override("separation", 10)
	var title := Label.new()
	title.text = "Graphics"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 24)
	add_child(title)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 10)
	add_child(row)
	var group := ButtonGroup.new()
	for level in Config.GRAPHICS_ORDER:
		var button := Button.new()
		button.text = String(level).capitalize()
		button.toggle_mode = true
		button.button_group = group
		button.custom_minimum_size = Vector2(130, 52)
		button.pressed.connect(_on_level_pressed.bind(level))
		row.add_child(button)
		_buttons[level] = button
	_description = Label.new()
	_description.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_description.custom_minimum_size = Vector2(420, 0)
	_description.add_theme_font_size_override("font_size", 16)
	add_child(_description)
	Graphics.level_changed.connect(_show_level)
	_show_level(Graphics.level)


func _on_level_pressed(level: String) -> void:
	Graphics.set_level(level)
	_show_level(level)


func _show_level(level: String) -> void:
	for key in _buttons:
		(_buttons[key] as Button).set_pressed_no_signal(key == level)
	_description.text = DESCRIPTIONS.get(level, "")
