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
## - The furnace panel (E at the built furnace, only when smelting is allowed).
## - The big boss's health bar across the top in wave 20.
## - Game-over screen with a Restart button when the knight falls, and the
##   victory screen ("The castle is safe!") with stats after the final battle.

signal input_mode_changed(touch: bool)
## Forwarded from the touch controls, in screen pixels.
signal look_dragged(relative: Vector2)
signal crafting_menu_toggled(open: bool)

const TouchControls := preload("res://scripts/touch_controls.gd")
const CraftingMenu := preload("res://scripts/crafting_menu.gd")
const FurnaceMenu := preload("res://scripts/furnace_menu.gd")
const PauseMenu := preload("res://scripts/pause_menu.gd")
const ArmorIcon := preload("res://scripts/armor_icon.gd")
const TITLE_SCENE := "res://scenes/title.tscn"
const Config := preload("res://scripts/game_config.gd")
## Enough slots for every weapon at once. Keys 1 to 9 pick the first nine.
const HOTBAR_SLOTS := 16
## A hotbar slot's widest and narrowest size; slots shrink when there are many.
const SLOT_WIDTH_MAX := 96.0
const SLOT_WIDTH_MIN := 62.0

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
var _furnace_menu: FurnaceMenu
var _pause_menu: PauseMenu
var _armor_badge: HBoxContainer
var _fade: ColorRect
var _companions_label: Label
var _release_panel: Control
var _release_title: Label
var _release_buttons: VBoxContainer
var _release_callback := Callable()
var _reload_bar: ProgressBar
## True during the victory camera pan (no pausing then).
var _in_cutscene := false
var _final_wave := false
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
@onready var _status: Control = $Status
@onready var _wave_info: Control = $WaveInfo
@onready var _big_boss_panel: Control = $BigBoss
@onready var _big_boss_bar: ProgressBar = $BigBoss/Bar
@onready var _big_boss_name: Label = $BigBoss/Bar/Name
@onready var _end_stats: Label = $GameOver/Center/Stats
@onready var _quit_button: Button = $GameOver/Center/QuitButton
@onready var _main_menu_button: Button = $GameOver/Center/MainMenuButton


func _ready() -> void:
	add_to_group("hud")
	_touch_controls.look_dragged.connect(func(relative: Vector2) -> void: look_dragged.emit(relative))
	_restart_button.pressed.connect(_on_restart_pressed)
	_quit_button.pressed.connect(_on_quit_pressed)
	_main_menu_button.pressed.connect(go_to_main_menu)
	_pause_menu = PauseMenu.new()
	_pause_menu.name = "PauseMenu"
	_pause_menu.visible = false
	_pause_menu.resume_requested.connect(close_pause)
	_pause_menu.main_menu_requested.connect(go_to_main_menu)
	add_child(_pause_menu)
	_build_hotbar()
	_build_armor_badge()
	_furnace_menu = FurnaceMenu.new()
	_furnace_menu.name = "FurnaceMenu"
	_furnace_menu.visible = false
	_furnace_menu.close_requested.connect(close_furnace_menu)
	add_child(_furnace_menu)
	_crafting_menu = CraftingMenu.new()
	_crafting_menu.name = "CraftingMenu"
	_crafting_menu.visible = false
	_crafting_menu.close_requested.connect(close_crafting)
	add_child(_crafting_menu)
	_build_reload_bar()
	_build_companions_label()
	_build_release_panel()
	_fade = ColorRect.new()
	_fade.name = "Fade"
	_fade.color = Color.BLACK
	_fade.modulate.a = 0.0
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_fade)
	_fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_set_touch_mode(DisplayServer.is_touchscreen_available())
	_watch_inventory.call_deferred()


func _unhandled_input(event: InputEvent) -> void:
	if _release_panel.visible:
		if event.is_action_pressed("pause"):
			_on_release_button(-1)
			get_viewport().set_input_as_handled()
		return
	if _furnace_menu.visible:
		# E (or Esc) closes the furnace panel.
		if event.is_action_pressed("interact") or event.is_action_pressed("pause"):
			close_furnace_menu()
			get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("craft"):
		if _crafting_menu.visible:
			close_crafting()
		else:
			open_crafting()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("pause") and _crafting_menu.visible:
		close_crafting()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("pause"):
		open_pause()
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


## Shows the Cryo armour icon while the armour is on (X-2). Connected to the knight.
func set_armor(equipped: bool) -> void:
	_armor_badge.visible = equipped


## A small "Reloading" bar under the crosshair, shown while the musket reloads.
func _build_reload_bar() -> void:
	_reload_bar = ProgressBar.new()
	_reload_bar.name = "ReloadBar"
	_reload_bar.min_value = 0.0
	_reload_bar.max_value = 1.0
	_reload_bar.step = 0.0
	_reload_bar.show_percentage = false
	_reload_bar.visible = false
	_reload_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(0.95, 0.78, 0.35)
	fill.set_corner_radius_all(4)
	_reload_bar.add_theme_stylebox_override("fill", fill)
	add_child(_reload_bar)
	_reload_bar.set_anchors_preset(Control.PRESET_CENTER)
	_reload_bar.offset_left = -80.0
	_reload_bar.offset_right = 80.0
	_reload_bar.offset_top = 36.0
	_reload_bar.offset_bottom = 46.0
	var label := Label.new()
	label.text = "Reloading"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 15)
	label.add_theme_constant_override("outline_size", 5)
	_reload_bar.add_child(label)
	label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	label.offset_top = 10.0
	label.offset_bottom = 32.0
	label.offset_left = -80.0
	label.offset_right = 80.0


# --- Tamed animals (H-3, H-4) ------------------------------------------------------

## Who's tamed and how they're doing, under the health bar. Connected to the Animals node.
func set_companions(text: String) -> void:
	_companions_label.text = "Animals: " + text
	_companions_label.visible = not text.is_empty()


## H-3: the knight already has 2 animals. Asks which one to let go so `new_name`
## can be tamed, then calls `callback` with its index (or -1 to keep them both).
func ask_release(names: Array[String], new_name: String, callback: Callable) -> void:
	if _release_panel.visible or _game_over.visible:
		callback.call(-1)
		return
	close_crafting()
	close_furnace_menu()
	_release_callback = callback
	_release_title.text = "You can keep %d animals at once.\nLet one go to tame the %s?" % [
			Config.MAX_TAMED, new_name.to_lower()]
	for child in _release_buttons.get_children():
		child.queue_free()
	for i in names.size():
		var button := Button.new()
		button.text = "Let the %s go" % names[i].to_lower()
		button.pressed.connect(_on_release_button.bind(i))
		_release_buttons.add_child(button)
	var keep := Button.new()
	keep.text = "Keep them both"
	keep.pressed.connect(_on_release_button.bind(-1))
	_release_buttons.add_child(keep)
	_release_panel.visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_touch_controls.visible = false
	crafting_menu_toggled.emit(true)
	keep.grab_focus.call_deferred()


func _on_release_button(index: int) -> void:
	if not _release_panel.visible:
		return
	_release_panel.visible = false
	_touch_controls.visible = touch_mode and not _game_over.visible
	crafting_menu_toggled.emit(false)
	var callback := _release_callback
	_release_callback = Callable()
	if callback.is_valid():
		callback.call(index)


func _build_companions_label() -> void:
	_companions_label = Label.new()
	_companions_label.name = "CompanionsLabel"
	_companions_label.visible = false
	_companions_label.add_theme_font_size_override("font_size", 17)
	_companions_label.add_theme_color_override("font_color", Color(0.75, 0.95, 0.7))
	_companions_label.add_theme_constant_override("outline_size", 5)
	_companions_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_status.add_child(_companions_label)


func _build_release_panel() -> void:
	_release_panel = Control.new()
	_release_panel.name = "ReleasePanel"
	_release_panel.visible = false
	_release_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_release_panel)
	_release_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.02, 0.03, 0.6)
	_release_panel.add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center := CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_release_panel.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var panel := PanelContainer.new()
	center.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	panel.add_child(column)
	_release_title = Label.new()
	_release_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_release_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_release_title.custom_minimum_size = Vector2(420, 0)
	column.add_child(_release_title)
	_release_buttons = VBoxContainer.new()
	_release_buttons.add_theme_constant_override("separation", 8)
	column.add_child(_release_buttons)


func _build_armor_badge() -> void:
	_armor_badge = HBoxContainer.new()
	_armor_badge.name = "ArmorBadge"
	_armor_badge.visible = false
	_armor_badge.add_theme_constant_override("separation", 6)
	_armor_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var icon := ArmorIcon.new()
	icon.custom_minimum_size = Vector2(20, 24)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_armor_badge.add_child(icon)
	var label := Label.new()
	label.text = "Cryo armour"
	label.add_theme_font_size_override("font_size", 18)
	label.add_theme_color_override("font_color", Color(0.72, 0.9, 1.0))
	label.add_theme_constant_override("outline_size", 5)
	_armor_badge.add_child(label)
	_status.add_child(_armor_badge)


func set_shift_lock(enabled: bool) -> void:
	_touch_controls.lock_on = enabled
	_shift_lock_label.visible = enabled


func set_pickup_prompt(prompt: String, button := "GRAB") -> void:
	_pickup_prompt = prompt
	_pickup_label.text = "[E]  " + prompt
	_touch_controls.grab_visible = not prompt.is_empty()
	_touch_controls.grab_label = button


## Freezes the game and shows the game-over screen: how far you got, Try Again
## (a fresh run from wave 1) and Main Menu.
func show_game_over() -> void:
	var waves = get_tree().get_first_node_in_group("wave_manager")
	if waves != null:
		var stats: Dictionary = waves.stats()
		_end_stats.text = "You reached wave %d\nEnemies defeated: %d" % [maxi(waves.wave, 1), stats.get("enemies", 0)]
		_end_stats.visible = true
	_restart_button.text = "Try Again"
	_show_end_screen("You have fallen", "The dummies got the better of you.")


# --- Pausing ----------------------------------------------------------------------

## Esc on PC, or the pause icon: freezes the game and shows the pause menu.
func open_pause() -> void:
	if _pause_menu.visible or _game_over.visible or _in_cutscene:
		return
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_touch_controls.visible = false
	_pause_menu.open()


func close_pause() -> void:
	_pause_menu.visible = false
	get_tree().paused = false
	_touch_controls.visible = touch_mode and not _game_over.visible


func go_to_main_menu() -> void:
	get_tree().paused = false
	WorldTime.clear_override()
	get_tree().change_scene_to_file(TITLE_SCENE)


# --- Crafting -------------------------------------------------------------------

func open_crafting() -> void:
	if not _crafting_available or _game_over.visible or _furnace_menu.visible:
		return
	_crafting_menu.open()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_touch_controls.visible = false
	# The stats panel would sit under the menu, so hide it while crafting.
	_status.visible = false
	crafting_menu_toggled.emit(true)


func close_crafting() -> void:
	if not _crafting_menu.visible:
		return
	_crafting_menu.visible = false
	_status.visible = true
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
		close_furnace_menu()


# --- Furnace --------------------------------------------------------------------

## Opened by the furnace site (E at the built furnace). Smelting follows the
## crafting rules: before wave 1 and during breaks, never from wave 15 on.
func open_furnace_menu() -> void:
	if _game_over.visible or _crafting_menu.visible or _furnace_menu.visible:
		return
	var waves = get_tree().get_first_node_in_group("wave_manager")
	if waves != null and not waves.can_craft():
		show_toast(waves.workshop_closed_reason())
		return
	_furnace_menu.open()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_touch_controls.visible = false
	_status.visible = false
	crafting_menu_toggled.emit(true)


func close_furnace_menu() -> void:
	if not _furnace_menu.visible:
		return
	_furnace_menu.visible = false
	_status.visible = true
	_touch_controls.visible = touch_mode and not _game_over.visible
	crafting_menu_toggled.emit(false)


func _watch_inventory() -> void:
	var inventory = get_tree().get_first_node_in_group("inventory")
	if inventory == null:
		return
	inventory.changed.connect(func() -> void: _update_materials(inventory))
	inventory.item_added.connect(_on_item_added)
	_update_materials(inventory)


func _on_item_added(material: String, amount: int) -> void:
	show_toast("+%d %s" % [amount, Config.MATERIAL_NAMES.get(material, material)])


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
	# Narrower slots when the hotbar is full, so it always fits on the screen.
	var room := get_viewport().get_visible_rect().size.x - 40.0
	var count := maxi(info.size(), 1)
	var width := clampf(room / count - 6.0, SLOT_WIDTH_MIN, SLOT_WIDTH_MAX)
	var font_size := 15 if width >= 86.0 else 12
	for i in HOTBAR_SLOTS:
		var slot := _hotbar_slots[i]
		slot.visible = i < info.size()
		if not slot.visible:
			continue
		var entry: Dictionary = info[i]
		slot.custom_minimum_size.x = width
		slot.add_theme_font_size_override("font_size", font_size)
		var text: String = entry["name"] if entry["key"] == 0 else "%d  %s" % [entry["key"], entry["name"]]
		if not String(entry["detail"]).is_empty():
			text += "\n" + entry["detail"]
		slot.text = text
		slot.add_theme_stylebox_override("normal", _selected_style if entry["selected"] else _slot_style)
	var equipped: String = knight.weapons.equipped()
	# The musket's reload bar under the crosshair (G-1).
	_reload_bar.visible = equipped == "musket" and knight.weapons.musket_reloading() and _crosshair.visible
	if _reload_bar.visible:
		_reload_bar.value = knight.weapons.musket_loaded_fraction()
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


## Fades the screen to black, calls `midpoint` (the knight moves through a bunker
## entrance), then fades back in. Real time, so it's quick even in slow motion.
func fade_through_black(midpoint: Callable) -> void:
	var fade := _fade.create_tween().set_ignore_time_scale(true)
	fade.tween_property(_fade, "modulate:a", 1.0, 0.3)
	fade.tween_callback(midpoint)
	fade.tween_interval(0.2)
	fade.tween_property(_fade, "modulate:a", 0.0, 0.4)


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
	_final_wave = wave >= last_wave
	_show_banner("The final battle!" if _final_wave else "Wave %d" % wave)


func on_dummies_left_changed(count: int) -> void:
	if _final_wave:
		_enemies_label.text = "Enemies left: %d" % count
	elif count > 0:
		_enemies_label.text = "Enemies left: %d" % count
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


func on_big_boss_appeared(boss_name: String) -> void:
	_big_boss_name.text = boss_name
	_big_boss_panel.visible = true
	_show_banner("%s is here!" % boss_name)


func on_big_boss_health_changed(health: int, max_health: int) -> void:
	_big_boss_bar.max_value = max_health
	_big_boss_bar.value = health
	if health <= 0:
		_big_boss_panel.visible = false


func on_army_marched_out(count: int) -> void:
	if count > 0:
		show_toast("The whole army marches out! (%d soldiers)" % count)


# --- Winning (called by the Victory node) ---------------------------------------

## Clears the screen for the camera pan over the castle.
func hide_for_cutscene() -> void:
	_in_cutscene = true
	_on_release_button(-1)
	close_crafting()
	close_furnace_menu()
	for node: CanvasItem in [_status, _wave_info, _big_boss_panel, _hotbar, _crosshair, _reload_bar,
			_pickup_label, _pc_hint, _touch_controls, _banner]:
		node.visible = false
	_pickup_prompt = ""
	set_process(false)


## The victory screen: "The castle is safe!" with the run's numbers.
func show_victory(stats: Dictionary, soldiers_left: int, army_size: int) -> void:
	var seconds := int(stats.get("time", 0.0))
	_end_stats.text = "Time played: %d:%02d\nEnemies defeated: %d\nMini bosses defeated: %d\nSoldiers who survived: %d / %d" % [
			seconds / 60, seconds % 60, stats.get("enemies", 0), stats.get("mini_bosses", 0),
			soldiers_left, army_size]
	_end_stats.visible = true
	_restart_button.text = "Play Again"
	# Quitting means nothing in a web page, so only offer it on PC.
	_quit_button.visible = not OS.has_feature("web")
	_show_end_screen("The castle is safe!", "%s has fallen and the woods are still again." % Config.BIG_BOSS_NAME)


# -----------------------------------------------------------------------------

func _show_end_screen(title: String, subtitle: String) -> void:
	_on_release_button(-1)
	close_crafting()
	close_furnace_menu()
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
	WorldTime.clear_override()
	get_tree().reload_current_scene()


func _on_quit_pressed() -> void:
	get_tree().quit()


## A red warning across the middle of the screen (a bandit's theft, D-2).
func show_alert(text: String) -> void:
	_show_banner(text, Color(1.0, 0.42, 0.32))


## Shows big text in the middle of the screen for a couple of seconds.
func _show_banner(text: String, tint := Color.WHITE) -> void:
	_banner.text = text
	_banner.self_modulate = tint
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
