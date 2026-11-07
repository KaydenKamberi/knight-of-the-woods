extends Control
## The crafting menu (PRD R-5, R-7, R-10, R-12, R-14). Opens with C, or the
## Craft button on touch, but only during breaks after waves 1 to 14.
##
## One row per recipe from game_config.gd with its cost and a Craft button,
## then the furnace (built once) and smelting (1 raw iron + 1 coal = 1 iron)
## once the furnace exists. Rows update whenever the inventory changes.
##
## The panel is sized from the screen (80% wide, 88% tall, centred), and every
## description and cost wraps, so a row can never be wider than the panel.

signal close_requested

const Config := preload("res://scripts/game_config.gd")
const Inventory := preload("res://scripts/inventory.gd")
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
var _materials_label: Label
var _rows := {}
var _furnace_button: Button
var _smelt_row: Control
var _smelt_one: Button
var _smelt_all: Button


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build()
	_connect_inventory.call_deferred()


func open() -> void:
	visible = true
	refresh()


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
			button.text = "Owned"
			button.disabled = true
		else:
			button.text = "Craft"
			button.disabled = not _inventory.can_craft(item)
	_furnace_button.disabled = _inventory.furnace_built or not _inventory.can_afford(Config.FURNACE_COST)
	_furnace_button.text = "Built" if _inventory.furnace_built else "Build"
	_smelt_row.visible = _inventory.furnace_built
	_smelt_one.disabled = not _inventory.can_afford(Config.SMELT_COST)
	_smelt_all.disabled = _smelt_one.disabled


func _connect_inventory() -> void:
	_inventory = get_tree().get_first_node_in_group("inventory")
	if _inventory != null:
		_inventory.changed.connect(refresh)


func _build() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.02, 0.03, 0.85)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	# Sized from the screen, not fixed pixels: 10% margin left and right, 6% top and bottom.
	var panel := PanelContainer.new()
	panel.anchor_left = 0.1
	panel.anchor_right = 0.9
	panel.anchor_top = 0.06
	panel.anchor_bottom = 0.94
	panel.offset_left = 0.0
	panel.offset_right = 0.0
	panel.offset_top = 0.0
	panel.offset_bottom = 0.0
	# If the content ever needs more room, grow evenly both ways instead of off one edge.
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.1, 0.08, 0.95)
	style.border_color = Color(0.75, 0.6, 0.3)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(18)
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	panel.add_child(column)
	column.add_child(_label("Crafting", 34, Color(1, 0.88, 0.6)))
	_materials_label = _label("", 17, Color(0.85, 0.9, 1.0))
	_materials_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_materials_label)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	var rows := VBoxContainer.new()
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rows.add_theme_constant_override("separation", 6)
	scroll.add_child(rows)

	for item in Config.RECIPES:
		var title: String = "Cryo armour" if item == "cryo_armor" else Config.WEAPONS[item]["name"]
		var button := _row(rows, title, DESCRIPTIONS[item], Inventory.describe_cost(Config.RECIPES[item]))
		button.pressed.connect(func() -> void: _inventory.craft(item))
		_rows[item] = button

	_furnace_button = _row(rows, "Furnace", "Built once, in the clearing. Unlocks smelting.",
			Inventory.describe_cost(Config.FURNACE_COST))
	_furnace_button.pressed.connect(func() -> void: _inventory.build_furnace())

	_smelt_row = HBoxContainer.new()
	rows.add_child(_smelt_row)
	var smelt_label := _label("Smelt: %s makes 1 iron" % Inventory.describe_cost(Config.SMELT_COST), 18, Color.WHITE)
	smelt_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_wrap(smelt_label)
	_smelt_row.add_child(smelt_label)
	_smelt_one = _button("Smelt 1")
	_smelt_one.pressed.connect(func() -> void: _inventory.smelt(1))
	_smelt_row.add_child(_smelt_one)
	_smelt_all = _button("Smelt all")
	_smelt_all.pressed.connect(func() -> void: _inventory.smelt(999))
	_smelt_row.add_child(_smelt_all)

	var close := _button("Close (C)")
	close.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	close.pressed.connect(func() -> void: close_requested.emit())
	column.add_child(close)


## One recipe row: name and description on the left, cost, then a button. Returns the button.
func _row(parent: Control, title: String, description: String, cost: String) -> Button:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	parent.add_child(row)
	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.add_theme_constant_override("separation", 0)
	row.add_child(text)
	var title_label := _label(title, 24, Color(1, 0.95, 0.85))
	title_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	title_label.add_theme_constant_override("outline_size", 4)
	_wrap(title_label)
	text.add_child(title_label)
	var description_label := _label(description, 15, Color(0.8, 0.8, 0.8))
	_wrap(description_label)
	text.add_child(description_label)
	var cost_label := _label(cost, 17, Color(0.95, 0.8, 0.5))
	cost_label.custom_minimum_size = Vector2(180, 0)
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
