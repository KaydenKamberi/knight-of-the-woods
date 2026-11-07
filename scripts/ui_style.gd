extends RefCounted
## The shared UI style (M7, 1F): dark wood panels with soft rounded corners and a
## gold accent, parchment-coloured text, and one readable font (Godot's built-in
## one, so nothing extra has to load in the web build) at sizes that work on a
## phone and a PC.
##
## The Graphics autoload puts theme() on the game window, so every Control
## (HUD, crafting menu, furnace panel, pause menu, title and end screens) gets it.
## Menus that build their own panels use panel() for the same look.

const Config := preload("res://scripts/game_config.gd")
const WOOD := Color(0.17, 0.12, 0.08, 0.95)
const WOOD_LIGHT := Color(0.26, 0.19, 0.12, 0.98)
const WOOD_DARK := Color(0.11, 0.08, 0.05, 0.95)
const PARCHMENT := Color(0.96, 0.9, 0.76)
const FONT_SIZE := 20

static var _theme: Theme


## A panel background: dark wood with a gold edge.
static func panel(border := 2, corner := 12) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = WOOD
	style.border_color = Config.PALETTE["knight_gold"]
	style.set_border_width_all(border)
	style.set_corner_radius_all(corner)
	style.set_content_margin_all(20)
	style.shadow_color = Color(0, 0, 0, 0.35)
	style.shadow_size = 6
	return style


static func theme() -> Theme:
	if _theme != null:
		return _theme
	var gold: Color = Config.PALETTE["knight_gold"]
	_theme = Theme.new()
	_theme.default_font_size = FONT_SIZE

	_theme.set_stylebox("panel", "PanelContainer", panel())
	_theme.set_stylebox("panel", "Panel", panel())

	var normal := _button_style(WOOD_LIGHT, gold.darkened(0.25))
	var hover := _button_style(WOOD_LIGHT.lightened(0.12), gold)
	var pressed := _button_style(WOOD_DARK, gold)
	var disabled := _button_style(WOOD_DARK, Color(0.4, 0.36, 0.3))
	var focus := _button_style(Color(0, 0, 0, 0), gold.lightened(0.2))
	focus.draw_center = false
	_theme.set_stylebox("normal", "Button", normal)
	_theme.set_stylebox("hover", "Button", hover)
	_theme.set_stylebox("pressed", "Button", pressed)
	_theme.set_stylebox("disabled", "Button", disabled)
	_theme.set_stylebox("focus", "Button", focus)
	_theme.set_color("font_color", "Button", PARCHMENT)
	_theme.set_color("font_hover_color", "Button", Color(1, 0.95, 0.8))
	_theme.set_color("font_pressed_color", "Button", gold)
	_theme.set_color("font_disabled_color", "Button", Color(0.55, 0.5, 0.42))
	_theme.set_font_size("font_size", "Button", 22)

	_theme.set_color("font_color", "Label", PARCHMENT)
	_theme.set_color("font_outline_color", "Label", Color(0, 0, 0, 0.75))

	var bar_back := StyleBoxFlat.new()
	bar_back.bg_color = Color(0, 0, 0, 0.5)
	bar_back.set_corner_radius_all(6)
	_theme.set_stylebox("background", "ProgressBar", bar_back)
	return _theme


static func _button_style(fill: Color, edge: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = edge
	style.set_border_width_all(2)
	style.set_corner_radius_all(10)
	style.content_margin_left = 18
	style.content_margin_right = 18
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	return style
