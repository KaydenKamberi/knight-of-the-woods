extends Control
## The furnace panel (PRD R-14): opens with E at the built furnace, when
## smelting is allowed (before wave 1 and during breaks, never from wave 15 on).
##
## Shows the coal, raw iron and iron the knight carries, with Smelt 1 (1 coal +
## 1 raw iron makes 1 iron) and Smelt all (as many as the smaller of the two
## allows). Both are greyed out without at least 1 of each. Smelting is instant;
## the furnace's fire flares up each time.
##
## Laid out like the crafting menu so it can't go off screen: the root fills the
## screen, and a CenterContainer keeps the panel in the middle.

signal close_requested

const Config := preload("res://scripts/game_config.gd")
const PANEL_SIZE := Vector2(560, 380)
const MAX_SCREEN_SHARE := 0.9

var _inventory = null
var _panel: PanelContainer
var _counts_label: Label
var _smelt_one: Button
var _smelt_all: Button


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build()
	_fit_to_screen()
	get_viewport().size_changed.connect(_fit_to_screen)
	_connect_inventory.call_deferred()


func open() -> void:
	_fit_to_screen()
	visible = true
	refresh()


func refresh() -> void:
	if _inventory == null or not visible:
		return
	var coal: int = _inventory.materials.get("coal", 0)
	var raw_iron: int = _inventory.materials.get("raw_iron", 0)
	var iron: int = _inventory.materials.get("iron", 0)
	_counts_label.text = "Coal: %d\nRaw iron: %d\nIron ingots: %d" % [coal, raw_iron, iron]
	var can_smelt: bool = _inventory.can_afford(Config.SMELT_COST)
	_smelt_one.disabled = not can_smelt
	_smelt_all.disabled = not can_smelt
	_smelt_all.text = "Smelt all (%d)" % mini(coal, raw_iron) if can_smelt else "Smelt all"


func _smelt(count: int) -> void:
	var made: int = _inventory.smelt(count)
	if made <= 0:
		return
	var site = get_tree().get_first_node_in_group("furnace_site")
	if site != null:
		site.flame_burst()
	var hud = get_tree().get_first_node_in_group("hud")
	if hud != null:
		hud.show_toast("+%d iron" % made)


func _fit_to_screen() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var screen := get_viewport_rect().size
	_panel.custom_minimum_size = Vector2(
			minf(PANEL_SIZE.x, screen.x * MAX_SCREEN_SHARE),
			minf(PANEL_SIZE.y, screen.y * MAX_SCREEN_SHARE))


func _connect_inventory() -> void:
	_inventory = get_tree().get_first_node_in_group("inventory")
	if _inventory != null:
		_inventory.changed.connect(refresh)


func _build() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.02, 0.03, 0.7)
	add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var center := CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_panel = PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.14, 0.09, 0.06, 0.95)
	style.border_color = Color(1.0, 0.55, 0.2)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(22)
	_panel.add_theme_stylebox_override("panel", style)
	center.add_child(_panel)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 14)
	_panel.add_child(column)
	column.add_child(_label("Furnace", 34, Color(1, 0.75, 0.45)))
	column.add_child(_label("1 coal + 1 raw iron makes 1 iron ingot", 18, Color(0.85, 0.85, 0.85)))
	_counts_label = _label("", 22, Color.WHITE)
	column.add_child(_counts_label)

	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 14)
	column.add_child(buttons)
	_smelt_one = _button("Smelt 1")
	_smelt_one.pressed.connect(_smelt.bind(1))
	buttons.add_child(_smelt_one)
	_smelt_all = _button("Smelt all")
	_smelt_all.pressed.connect(_smelt.bind(999))
	buttons.add_child(_smelt_all)

	var close := _button("Close (E)")
	close.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	close.pressed.connect(_on_close_pressed)
	column.add_child(close)


func _on_close_pressed() -> void:
	close_requested.emit()


func _label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label


func _button(text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(160, 46)
	button.add_theme_font_size_override("font_size", 20)
	return button
