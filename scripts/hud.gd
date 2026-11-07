extends CanvasLayer
## Heads-up display.
##
## - Health bar, knife count and world-speed readout in the top-left corner (E-3).
## - Crosshair in the middle, where knives are aimed, and a shift-lock indicator.
## - "Press E" prompt when a knife is in reach (PC), or the Grab button (touch).
## - Touch controls on phones and tablets, and a short controls hint on PC
##   (K-1). The last kind of input used wins: touching the screen switches to
##   touch controls, and typing or clicking a real mouse switches back.
## - Wave counter, dummies left, break countdown, a "Wave X" banner and the
##   mini boss's health bar (M4), fed by the wave manager.
## - Army counter (A-5) and short messages when soldiers arrive or fall.
## - Hotbar (R-15), carried materials, "+1 Wood" messages, and the crafting
##   menu (C / Craft button, only during crafting breaks).
## - Game-over screen with a Restart button when the knight falls, and the
##   "Final battle coming soon" screen after wave 19.

signal input_mode_changed(touch: bool)
## Forwarded from the touch controls, in screen pixels.
signal look_dragged(relative: Vector2)
signal crafting_menu_toggled(open: bool)

const TouchControls := preload("res://scripts/touch_controls.gd")
const CraftingMenu := preload("res://scripts/crafting_menu.gd")
const Config := preload("res://scripts/game_config.gd")
const HOTBAR_SLOTS := 9

## Show the "World time 5%" readout (handy while tuning the time mechanic).
@export var show_world_time := true

var touch_mode := false

var _pickup_prompt := ""
var _last_health := -1
var _flash_tween: Tween
var _banner_tween: Tween
var _crafting_available := false
var _knives_left := 0
var _crafting_menu: CraftingMenu
var _hotbar_slots: Array[Label] = []
var _slot_style: StyleBoxFlat
var _selected_style: StyleBoxFlat

@onready var _touch_controls: TouchControls = $TouchControls
@onready var _pc_hint: Control = $PcHint
@onready var _health_bar: ProgressBar = $Status/HealthBar
@onready var _knife_label: Label = $Status/KnifeLabel
@onready var _world_time_label: Label = $Status/WorldTimeLabel
@onready var _crosshair: Control = $Crosshair
@onready var _shift_lock_label: Label = $Status/ShiftLockLabel
@onready var _pickup_label: Label = $PickupPrompt
@onready var _damage_flash: ColorRect = $DamageFlash
@onready var _game_over: Control = $GameOver
@onready var _restart_button: Button = $GameOver/Center/RestartButton
@onready var _end_title: Label = $GameOver/Center/Title
@onready var _end_subtitle: Label = $GameOver/Center/Subtitle
@onready var _wave_label: Label = $WaveInfo/WaveLabel
@onready var _enemies_label: Label = $WaveInfo/EnemiesLabel
@onready var _countdown_label: Label = $WaveInfo/CountdownLabel
@onready var _boss_name_label: Label = $WaveInfo/BossName
@onready var _boss_bar: ProgressBar = $WaveInfo/BossBar
@onready var _banner: Label = $Banner
@onready var _army_label: Label = $Status/ArmyLabel
@onready var _toasts: VBoxContainer = $Toasts
@onready var _materials_label: Label = $Status/MaterialsLabel
@onready var _craft_hint: Label = $WaveInfo/CraftHint
@onready var _hotbar: HBoxContainer = $Hotbar


func _ready() -> void:
	add_to_group("hud")
	_touch_controls.look_dragged.connect(func(relative: Vector2) -> void: look_dragged.emit(relative))
	_restart_button.pressed.connect(_on_restart_pressed)
	_build_hotbar()
	_crafting_menu = CraftingMenu.new()
	_crafting_menu.name = "CraftingMenu"
	_crafting_menu.visible = false
	_crafting_menu.close_requested.connect(close_crafting)
	add_child(_crafting_menu)
	_set_touch_mode(DisplayServer.is_touchscreen_available())
	_watch_inventory.call_deferred()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("craft"):
		if _crafting_menu.visible:
			close_crafting()
		else:
			open_crafting()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("pause") and _crafting_menu.visible:
		close_crafting()
		get_viewport().set_input_as_handled()


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if not touch_mode:
			_set_touch_mode(true)
	elif touch_mode:
		var real_mouse_click: bool = event is InputEventMouseButton \
				and event.device != InputEvent.DEVICE_ID_EMULATION
		if event is InputEventKey or real_mouse_click:
			_set_touch_mode(false)


func _process(_delta: float) -> void:
	_pc_hint.visible = not touch_mode and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED
	_pickup_label.visible = not touch_mode and not _pickup_prompt.is_empty()
	_update_hotbar()
	_world_time_label.visible = show_world_time
	if show_world_time:
		_world_time_label.text = "World time %d%%" % roundi(WorldTime.speed * 100.0)


# --- Called by the knight (connected in forest.tscn) ---------------------------

func set_health(health: int, max_health: int) -> void:
	_health_bar.max_value = max_health
	_health_bar.value = health
	if _last_health >= 0 and health < _last_health:
		_flash_damage()
	_last_health = health


func set_knives(count: int, max_count: int) -> void:
	_knife_label.text = "Knives %d / %d" % [count, max_count]
	_knives_left = count


func set_shift_lock(enabled: bool) -> void:
	_touch_controls.lock_on = enabled
	_shift_lock_label.visible = enabled


func set_pickup_prompt(prompt: String) -> void:
	_pickup_prompt = prompt
	_pickup_label.text = "[E]  " + prompt
	_touch_controls.grab_visible = not prompt.is_empty()


## Freezes the game and shows the game-over screen.
func show_game_over() -> void:
	_show_end_screen("You have fallen", "The dummies got the better of you.")


# --- Crafting -------------------------------------------------------------------

func open_crafting() -> void:
	if not _crafting_available or _game_over.visible:
		return
	_crafting_menu.open()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_touch_controls.visible = false
	crafting_menu_toggled.emit(true)


func close_crafting() -> void:
	if not _crafting_menu.visible:
		return
	_crafting_menu.visible = false
	_touch_controls.visible = touch_mode and not _game_over.visible
	crafting_menu_toggled.emit(false)


## Connected to the wave manager: crafting opens during breaks after waves 1 to 14.
func on_crafting_available_changed(available: bool) -> void:
	_crafting_available = available
	_craft_hint.visible = available
	_craft_hint.text = "Tap Craft to make weapons" if touch_mode else "Press C to craft"
	_touch_controls.craft_visible = available
	if not available:
		close_crafting()


func _watch_inventory() -> void:
	var inventory = get_tree().get_first_node_in_group("inventory")
	if inventory == null:
		return
	inventory.changed.connect(func() -> void: _update_materials(inventory))
	inventory.item_added.connect(func(material: String, amount: int) -> void:
		show_toast("+%d %s" % [amount, Config.MATERIAL_NAMES.get(material, material)]))
	_update_materials(inventory)


## The materials the knight carries, under the health bar (only the ones he has).
func _update_materials(inventory) -> void:
	var parts: Array[String] = []
	for id in Config.MATERIALS:
		var count: int = inventory.materials.get(id, 0)
		if count > 0:
			parts.append("%s %d" % [Config.MATERIAL_NAMES[id], count])
	_materials_label.text = "  ·  ".join(parts)
	_materials_label.visible = not parts.is_empty()


# --- Hotbar ---------------------------------------------------------------------

func _build_hotbar() -> void:
	_slot_style = StyleBoxFlat.new()
	_slot_style.bg_color = Color(0, 0, 0, 0.5)
	_slot_style.set_corner_radius_all(6)
	_slot_style.set_content_margin_all(8)
	_selected_style = _slot_style.duplicate()
	_selected_style.bg_color = Color(0.25, 0.2, 0.08, 0.85)
	_selected_style.border_color = Color(1, 0.85, 0.35)
	_selected_style.set_border_width_all(2)
	for i in HOTBAR_SLOTS:
		var slot := Label.new()
		slot.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		slot.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		slot.custom_minimum_size = Vector2(96, 52)
		slot.add_theme_font_size_override("font_size", 15)
		slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.visible = false
		_hotbar.add_child(slot)
		_hotbar_slots.append(slot)


func _update_hotbar() -> void:
	var knight = get_tree().get_first_node_in_group("player")
	if knight == null or knight.weapons == null:
		return
	var info: Array = knight.weapons.hotbar_info()
	for i in HOTBAR_SLOTS:
		var slot := _hotbar_slots[i]
		slot.visible = i < info.size()
		if not slot.visible:
			continue
		var entry: Dictionary = info[i]
		var text := "%d  %s" % [entry["key"], entry["name"]]
		if not String(entry["detail"]).is_empty():
			text += "\n" + entry["detail"]
		slot.text = text
		slot.add_theme_stylebox_override("normal", _selected_style if entry["selected"] else _slot_style)
	var equipped: String = knight.weapons.equipped()
	_touch_controls.hammer_equipped = equipped == "cryo_hammer"
	# The Attack button dims only when holding knives with none left to throw.
	_touch_controls.throw_enabled = equipped != "knife" or _knives_left > 0


# --- Called by the army (connected in forest.tscn) ---------------------------------

func on_army_changed(total: int, in_field: int, counts: Dictionary) -> void:
	var text := "Army %d  (%d archers · %d spears · %d swords)" % [
			total, counts["archer"], counts["spear"], counts["sword"]]
	if in_field > 0:
		text += "  ·  %d fighting" % in_field
	_army_label.text = text


func on_rescue_arrived(count: int) -> void:
	show_toast("%d soldiers rush in to help!" % count)


func on_soldier_fell(role: String) -> void:
	var names := {"archer": "An archer", "spear": "A spearman", "sword": "A sword fighter"}
	show_toast("%s has fallen" % names.get(role, "A soldier"))


## A short message on the right side of the screen that fades away.
func show_toast(text: String) -> void:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	label.add_theme_font_size_override("font_size", 22)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	label.add_theme_constant_override("outline_size", 6)
	_toasts.add_child(label)
	var fade := label.create_tween().set_ignore_time_scale(true)
	fade.tween_interval(2.5)
	fade.tween_property(label, "modulate:a", 0.0, 0.6)
	fade.tween_callback(label.queue_free)


# --- Called by the wave manager (connected in forest.tscn) ------------------------

func on_wave_started(wave: int, last_wave: int) -> void:
	_wave_label.text = "Wave %d / %d" % [wave, last_wave]
	_show_banner("Wave %d" % wave)


func on_dummies_left_changed(count: int) -> void:
	if count > 0:
		_enemies_label.text = "Dummies left: %d" % count
	else:
		_enemies_label.text = "The mini boss is coming..."


func on_break_time_changed(seconds_left: float, next_wave: int) -> void:
	_countdown_label.visible = seconds_left >= 0.0
	if seconds_left >= 0.0:
		_countdown_label.text = "Wave %d starts in %d" % [next_wave, ceili(seconds_left)]
		_enemies_label.text = "Break: grab your knives"


func on_mini_boss_appeared(boss_name: String) -> void:
	_enemies_label.text = "Mini boss!"
	_boss_name_label.text = boss_name
	_boss_name_label.visible = true
	_boss_bar.visible = true
	_show_banner("%s appears!" % boss_name)


func on_mini_boss_health_changed(health: int, max_health: int) -> void:
	_boss_bar.max_value = max_health
	_boss_bar.value = health


func on_wave_cleared(wave: int) -> void:
	_boss_name_label.visible = false
	_boss_bar.visible = false
	_show_banner("Wave %d cleared!" % wave)


func show_final_battle_placeholder() -> void:
	_show_end_screen("Final battle coming soon",
			"You beat all 19 waves! The battle at the castle gates is on its way.")


# -----------------------------------------------------------------------------

func _show_end_screen(title: String, subtitle: String) -> void:
	close_crafting()
	_end_title.text = title
	_end_subtitle.text = subtitle
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_touch_controls.visible = false
	_pc_hint.visible = false
	_pickup_label.visible = false
	_crosshair.visible = false
	_game_over.visible = true
	_restart_button.grab_focus()


# -----------------------------------------------------------------------------

func _on_restart_pressed() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()


## Shows big text in the middle of the screen for a couple of seconds.
func _show_banner(text: String) -> void:
	_banner.text = text
	if _banner_tween:
		_banner_tween.kill()
	_banner.modulate.a = 0.0
	_banner_tween = create_tween().set_ignore_time_scale(true)
	_banner_tween.tween_property(_banner, "modulate:a", 1.0, 0.2)
	_banner_tween.tween_interval(1.8)
	_banner_tween.tween_property(_banner, "modulate:a", 0.0, 0.5)


func _flash_damage() -> void:
	if _flash_tween:
		_flash_tween.kill()
	_damage_flash.modulate.a = 1.0
	_flash_tween = create_tween().set_ignore_time_scale(true)
	_flash_tween.tween_property(_damage_flash, "modulate:a", 0.0, 0.4)


func _set_touch_mode(enabled: bool) -> void:
	touch_mode = enabled
	_touch_controls.visible = enabled and not _game_over.visible
	input_mode_changed.emit(enabled)
