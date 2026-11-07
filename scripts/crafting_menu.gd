extends Control
## The crafting menu (PRD R-5, R-7, R-10, R-12, R-14). Opens with C, or the
## Craft button on touch, but only during breaks after waves 1 to 14.
##
## Cryo armour has its own section at the top (X-1), so it's always in view;
## below it, one row per weapon recipe from game_config.gd with its cost and a
## Craft button. Rows update whenever the inventory changes. (The furnace and smelting live
## at the furnace in the castle courtyard, not here.)
##
## The menu fills the screen (re-filling it if the window is resized). The
## panel sits in a CenterContainer, so it's always in the middle, at PANEL_SIZE
## but never more than 90% of the screen. Every name, description and cost
## wraps, so a row can never be wider than the panel.

signal close_requested

const Config := preload("res://scripts/game_config.gd")
const Inventory := preload("res://scripts/inventory.gd")
## The panel's size, shrunk if the screen is smaller (never more than 90% of it).
const PANEL_SIZE := Vector2(940, 640)
## Items in their own section above the weapons list.
const ARMOUR := ["cryo_armor"]
const MAX_SCREEN_SHARE := 0.9
## What each item does, shown under its name.
const DESCRIPTIONS := {
	"spear": "60 damage · long reach, hits before enemies get close",
	"sword": "50 damage · fast swings",
	"axe": "75 damage · slow, heavy swings that hit everyone in front",
	"bow": "40 damage · ranged, unlimited arrows",
	"cryo_dagger": "30 damage · a slash freezes the head; the next hit shatters it",
	"cryo_hammer": "100 damage · slowest · right click slam (once a wave) · F spin",
	"ultra_blaster": "1,000 damage · exploding shots · 3 uses, then it breaks",
	"cryo_armor": "Reflects 25% of melee damage and slows attackers",
}

var _inventory = null
var _panel: PanelContainer
var _materials_label: Label
var _rows := {}


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
	print("[CRAFT] viewport=", get_viewport_rect().size, " root=", get_rect(), " panel=", _panel.get_global_rect())
	# Containers lay out just after this, so print the settled numbers again next frame.
	if not get_tree().process_frame.is_connected(_print_layout):
		get_tree().process_frame.connect(_print_layout, CONNECT_ONE_SHOT)


## Fills the whole screen and sizes the panel for it. (set_anchors_preset alone
## keeps the old size, which for a Control made in code is 0 x 0, so the offsets
## have to be reset too.)
func _fit_to_screen() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var screen := get_viewport_rect().size
	_panel.custom_minimum_size = Vector2(
			minf(PANEL_SIZE.x, screen.x * MAX_SCREEN_SHARE),
			minf(PANEL_SIZE.y, screen.y * MAX_SCREEN_SHARE))


## Temporary layout check: the root should match the viewport and the panel should
## be centred in it.
func _print_layout() -> void:
	print("[CRAFT] laid out: viewport=", get_viewport_rect().size, " root=", get_rect(), " panel=", _panel.get_global_rect())


func refresh() -> void:
	if _inventory == null or not visible:
		return
	var parts: Array[String] = []
	for id in Config.MATERIALS:
		parts.append("%s %d" % [Config.MATERIAL_NAMES[id], _inventory.materials.get(id, 0)])
	_materials_label.text = "  ·  ".join(parts)
	for item in _rows:
		var button: Button = _rows[item]
		if _inventory.owns(item) and item != "ultra_blaster":
			# Armour is put on the moment it's crafted.
			button.text = "Equipped" if item in ARMOUR else "Owned"
			button.disabled = true
		else:
			button.text = "Craft"
			button.disabled = not _inventory.can_craft(item)


func _connect_inventory() -> void:
	_inventory = get_tree().get_first_node_in_group("inventory")
	if _inventory != null:
		_inventory.changed.connect(refresh)


func _build() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.02, 0.03, 0.85)
	add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	# The CenterContainer fills the screen and keeps the panel in its middle.
	var center := CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var panel := PanelContainer.new()
	_panel = panel
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.1, 0.08, 0.95)
	style.border_color = Color(0.75, 0.6, 0.3)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(18)
	panel.add_theme_stylebox_override("panel", style)
	center.add_child(panel)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	panel.add_child(column)
	column.add_child(_label("Crafting", 30, Color(1, 0.88, 0.6)))
	_materials_label = _label("", 16, Color(0.85, 0.9, 1.0))
	_wrap(_materials_label)
	column.add_child(_materials_label)

	# Armour first, outside the scrolling list, so it can never be scrolled out of view.
	column.add_child(_label("Armour", 18, Color(0.7, 0.88, 1.0)))
	for item in ARMOUR:
		_add_recipe_row(column, item)
	column.add_child(_label("Weapons", 18, Color(1, 0.85, 0.5)))

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	var rows := VBoxContainer.new()
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rows.add_theme_constant_override("separation", 4)
	scroll.add_child(rows)
	for item in Config.RECIPES:
		if not (item in ARMOUR):
			_add_recipe_row(rows, item)

	var close := _button("Close (C)")
	close.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	close.pressed.connect(func() -> void: close_requested.emit())
	column.add_child(close)


func _add_recipe_row(parent: Control, item: String) -> void:
	var title: String = "Cryo armour" if item == "cryo_armor" else Config.WEAPONS[item]["name"]
	var button := _row(parent, title, DESCRIPTIONS[item], Inventory.describe_cost(Config.RECIPES[item]))
	button.pressed.connect(func() -> void: _inventory.craft(item))
	_rows[item] = button


## One compact recipe row: the name, what it does, the cost, then a button. Returns the button.
func _row(parent: Control, title: String, description: String, cost: String) -> Button:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	parent.add_child(row)
	var title_label := _label(title, 22, Color(1, 0.95, 0.85))
	title_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	title_label.add_theme_constant_override("outline_size", 4)
	title_label.custom_minimum_size = Vector2(170, 0)
	title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_wrap(title_label)
	row.add_child(title_label)
	var description_label := _label(description, 14, Color(0.8, 0.8, 0.8))
	description_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	description_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_wrap(description_label)
	row.add_child(description_label)
	var cost_label := _label(cost, 16, Color(0.95, 0.8, 0.5))
	cost_label.custom_minimum_size = Vector2(170, 0)
	cost_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_wrap(cost_label)
	row.add_child(cost_label)
	var button := _button("Craft")
	row.add_child(button)
	return button


func _label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label


## Lets a label wrap onto more lines instead of pushing its row wider,
## and never clips or trims its text.
func _wrap(label: Label) -> void:
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.clip_text = false
	label.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING


func _button(text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(110, 40)
	button.add_theme_font_size_override("font_size", 18)
	return button
