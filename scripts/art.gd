extends RefCounted
## Materials for the toon look (M7 art pass). Every solid thing in the game gets
## its material from here, so they all share one shader (shaders/toon.gdshader)
## and one palette (PALETTE in game_config.gd).
##
## Use it from another script with `const Art := preload("res://scripts/art.gd")`:
##   Art.material(Art.color("stone"))                    # a shared, cached material
##   Art.material(color, {"rim": true, "unique": true})   # a character's own material
## Options:
##   rim: true for characters (a soft rim light so they stand out)
##   emission: a Color, with energy: how strongly it glows
##   sway: how much it moves in the wind (leaves)
##   fade: true for scenery that dissolves out at the view distance
##   instance_color: true for MultiMeshes whose copies are tinted (and vertex colours)
##   unique: true to get a material of its own (for flashing or tinting one object)

const Config := preload("res://scripts/game_config.gd")
const TOON := preload("res://shaders/toon.gdshader")

static var _cache := {}


## A colour from the shared palette.
static func color(palette_name: String) -> Color:
	return Config.PALETTE.get(palette_name, Color.MAGENTA)


static func material(albedo: Color, options := {}) -> ShaderMaterial:
	var unique: bool = options.get("unique", false)
	var key := ""
	if not unique:
		key = "%s|%s" % [albedo.to_html(), str(options)]
		if _cache.has(key):
			return _cache[key]
	var made := ShaderMaterial.new()
	made.shader = TOON
	made.set_shader_parameter("albedo", albedo)
	if options.get("rim", false):
		made.set_shader_parameter("rim_strength", Config.CHARACTER_RIM)
	if options.has("emission"):
		made.set_shader_parameter("emission_color", options["emission"])
		made.set_shader_parameter("emission_energy", options.get("energy", 1.0))
	if options.has("sway"):
		made.set_shader_parameter("sway", options["sway"])
	if options.get("fade", false):
		made.set_shader_parameter("distance_fade", true)
	if options.get("instance_color", false):
		made.set_shader_parameter("use_instance_color", true)
	if not unique:
		_cache[key] = made
	return made


## Sets a material's colour, whether it's a toon material or a standard one.
static func set_color(target: Material, albedo: Color) -> void:
	if target is ShaderMaterial:
		(target as ShaderMaterial).set_shader_parameter("albedo", albedo)
	elif target is BaseMaterial3D:
		(target as BaseMaterial3D).albedo_color = albedo


static func get_color(target: Material) -> Color:
	if target is ShaderMaterial:
		return (target as ShaderMaterial).get_shader_parameter("albedo")
	if target is BaseMaterial3D:
		return (target as BaseMaterial3D).albedo_color
	return Color.WHITE


## Makes a material glow (energy 0 turns the glow off).
static func set_emission(target: Material, glow: Color, energy: float) -> void:
	if target is ShaderMaterial:
		(target as ShaderMaterial).set_shader_parameter("emission_color", glow)
		(target as ShaderMaterial).set_shader_parameter("emission_energy", energy)
	elif target is BaseMaterial3D:
		var standard := target as BaseMaterial3D
		standard.emission_enabled = energy > 0.0
		standard.emission = glow
		standard.emission_energy_multiplier = energy


## A short white flash when something is hit. The flash fades on world time.
static func flash(materials: Array, owner: Node) -> void:
	if materials.is_empty() or not is_instance_valid(owner) or not owner.is_inside_tree():
		return
	var toon: Array = materials.filter(func(target) -> bool: return target is ShaderMaterial)
	if toon.is_empty():
		return
	var fade := owner.create_tween().set_parallel()
	for target in toon:
		target.set_shader_parameter("flash", 1.0)
		fade.tween_property(target, "shader_parameter/flash", 0.0, 0.15)
