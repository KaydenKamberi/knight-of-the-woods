extends Node3D
## The furnace's spot in the castle courtyard (PRD R-14).
##
## Until it's built, a see-through blue hologram of the furnace pulses here, with
## a floating "Furnace: 10 stone" label. Walking up shows "[E] Build furnace
## (10 stone)", or "Need 10 stone (you have X)" if there isn't enough. Building
## spends the stone and swaps the hologram for the real furnace. After that,
## walking up shows "[E] Smelt", which opens the furnace panel.
##
## The knight finds this through the "interactables" group (like knives in the
## "knife_pickups" group), so his E key and the touch Grab button both work here.

const Config := preload("res://scripts/game_config.gd")
const FURNACE_SCRIPT := preload("res://scripts/furnace.gd")
const Inventory := preload("res://scripts/inventory.gd")
const HOLOGRAM_COLOR := Color(0.35, 0.75, 1.0)

var _hologram: Node3D
var _hologram_material: StandardMaterial3D
var _label: Label3D
var _furnace = null


func _ready() -> void:
	add_to_group("interactables")
	add_to_group("furnace_site")
	# Face the middle of the courtyard, so the fire's mouth looks into it.
	var to_middle := -position
	rotation.y = atan2(-to_middle.x, -to_middle.z)

	_hologram_material = StandardMaterial3D.new()
	_hologram_material.albedo_color = Color(HOLOGRAM_COLOR, 0.35)
	_hologram_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_hologram_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_hologram_material.emission_enabled = true
	_hologram_material.emission = HOLOGRAM_COLOR
	_hologram = Node3D.new()
	_hologram.name = "Hologram"
	add_child(_hologram)
	FURNACE_SCRIPT.build_model(_hologram, _hologram_material)
	for mesh in _hologram.get_children():
		(mesh as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	_label = Label3D.new()
	_label.text = "Furnace: " + Inventory.describe_cost(Config.FURNACE_COST)
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.font_size = 64
	_label.outline_size = 12
	_label.modulate = Color(0.75, 0.92, 1.0)
	_label.position = Vector3(0, 3.1, 0)
	add_child(_label)


func _process(_delta: float) -> void:
	if is_instance_valid(_hologram):
		# A gentle pulse, in real time so it keeps going while the world is slowed.
		var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() / 1000.0 * 2.5)
		_hologram_material.albedo_color.a = 0.22 + 0.2 * pulse
		_hologram_material.emission_energy_multiplier = 0.4 + 0.5 * pulse


func is_built() -> bool:
	return _furnace != null


# --- Used by the knight's E / Grab (see knight.gd) -------------------------------

func can_be_picked_up() -> bool:
	return true


func pickup_point() -> Vector3:
	return global_position + Vector3.UP


func pickup_range() -> float:
	return Config.FURNACE_USE_RANGE


func pickup_prompt() -> String:
	if is_built():
		return "Smelt"
	var stone := _stone()
	var needed: int = Config.FURNACE_COST["stone"]
	if stone >= needed:
		return "Build furnace (%d stone)" % needed
	return "Need %d stone (you have %d)" % [needed, stone]


## The word on the touch Grab button while this is in reach.
func pickup_button() -> String:
	return "SMELT" if is_built() else "BUILD"


func interact() -> void:
	var hud = get_tree().get_first_node_in_group("hud")
	if is_built():
		if hud != null:
			hud.open_furnace_menu()
		return
	var inventory = get_tree().get_first_node_in_group("inventory")
	if inventory == null or not inventory.build_furnace():
		if hud != null:
			hud.show_toast(pickup_prompt())
		return
	_hologram.queue_free()
	_hologram = null
	_label.queue_free()
	_furnace = FURNACE_SCRIPT.new()
	_furnace.name = "Furnace"
	add_child(_furnace)
	if hud != null:
		hud.show_toast("Furnace built!")


## The fire flares up (called by the furnace panel after each smelt).
func flame_burst() -> void:
	if is_instance_valid(_furnace):
		_furnace.flame_burst()


func _stone() -> int:
	var inventory = get_tree().get_first_node_in_group("inventory")
	return 0 if inventory == null else inventory.materials.get("stone", 0)
