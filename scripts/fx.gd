extends RefCounted
## Particle effects (M7, 1E): dust, hit sparks, frost, ice, the blaster's trail
## and explosion, and furnace sparks.
##
## All of them are CPUParticles3D, which run on the normal (world-time) delta,
## so every effect slows down when world time does (T-3), and they work the same
## on the Compatibility renderer on PC and in iPhone Safari. One-shot effects are
## pooled: a few emitters of each kind are reused round-robin instead of being
## made and thrown away. How many particles each effect gets follows the
## graphics setting ("effects" in GRAPHICS_LEVELS).
##
## Use it with `const Fx := preload("res://scripts/fx.gd")`, then e.g.
## `Fx.hit_sparks(point)`.

const Config := preload("res://scripts/game_config.gd")
const Effects := preload("res://scripts/effects.gd")
const ICE := Color(0.72, 0.9, 1.0)
const ULTRA := Color(0.82, 0.4, 1.0)
const POOL_SIZE := 6

## kind -> {"nodes": Array of emitters, "next": index}
static var _pools := {}
static var _material: StandardMaterial3D


static func hit_sparks(at: Vector3) -> void:
	_burst("sparks", at, {"amount": 12, "life": 0.35, "speed": Vector2(3.0, 6.0),
			"gravity": -9.0, "color": Color(1.0, 0.92, 0.65), "size": 0.06})


## A puff of dust at the knight's feet (running and landing). `big` for landings.
static func dust(at: Vector3, big := false) -> void:
	_burst("dust_big" if big else "dust", at, {"amount": 12 if big else 5, "life": 0.6,
			"speed": Vector2(0.6, 1.6 if big else 1.0), "gravity": 0.4, "spread": 75.0,
			"color": Color(0.86, 0.8, 0.66, 0.75), "size": 0.18, "fade": true})


static func ice_shatter(at: Vector3, size := 1.0) -> void:
	_burst("shatter", at, {"amount": 22, "life": 0.7, "speed": Vector2(3.0, 6.0) * sqrt(size),
			"gravity": -9.0, "color": ICE, "size": 0.09 * size})


## The hammer's ground slam: an icy ring rushing outwards, with ice crystals.
static func ice_ring(at: Vector3, radius: float, scene_root: Node) -> void:
	var torus := TorusMesh.new()
	torus.inner_radius = 0.8
	torus.outer_radius = 1.0
	torus.rings = 24
	torus.ring_segments = 4
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(ICE, 0.7)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	torus.material = material
	var ring := MeshInstance3D.new()
	ring.mesh = torus
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	scene_root.add_child(ring)
	ring.global_position = Vector3(at.x, 0.15, at.z)
	ring.scale = Vector3(0.3, 0.6, 0.3)
	var grow := ring.create_tween().set_parallel()
	grow.tween_property(ring, "scale", Vector3(radius, 0.6, radius), 0.4).set_ease(Tween.EASE_OUT)
	grow.tween_property(material, "albedo_color:a", 0.0, 0.5)
	grow.chain().tween_callback(ring.queue_free)
	_burst("crystals", at + Vector3.UP * 0.3, {"amount": 30, "life": 0.8, "speed": Vector2(4.0, 8.0),
			"gravity": -9.0, "spread": 80.0, "color": ICE, "size": 0.1})


## The Ultra blaster's explosion: a glowing ball and a spray of sparks.
static func explosion(at: Vector3, radius: float, scene_root: Node) -> void:
	Effects.burst(at, radius, ULTRA, scene_root)
	_burst("explosion", at, {"amount": 40, "life": 0.9, "speed": Vector2(5.0, 11.0),
			"gravity": -6.0, "color": Color(1.0, 0.8, 1.0), "size": 0.12})


static func furnace_sparks(at: Vector3) -> void:
	_burst("embers", at, {"amount": 16, "life": 0.9, "speed": Vector2(1.5, 3.0), "gravity": -2.5,
			"spread": 35.0, "color": Color(1.0, 0.6, 0.2), "size": 0.05})


## A glowing trail behind a moving node (the blaster round). Freed with it.
static func blaster_trail(node: Node3D) -> void:
	var trail := _emitter({"amount": 24, "life": 0.45, "speed": Vector2(0.0, 0.3), "gravity": 0.0,
			"color": ULTRA, "size": 0.1, "fade": true})
	trail.one_shot = false
	trail.explosiveness = 0.0
	trail.local_coords = false
	node.add_child(trail)
	trail.emitting = true


## Frost drifting off a frozen enemy. Returns the emitter so it can be removed when it thaws.
static func frost_on(body: Node3D, size := 1.0) -> CPUParticles3D:
	var frost := _emitter({"amount": 10, "life": 1.0, "speed": Vector2(0.1, 0.4), "gravity": -0.5,
			"color": Color(0.9, 0.97, 1.0, 0.85), "size": 0.06 * size, "fade": true})
	frost.one_shot = false
	frost.explosiveness = 0.0
	frost.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	frost.emission_sphere_radius = 0.5 * size
	frost.position = Vector3.UP * 1.0 * size
	body.add_child(frost)
	frost.emitting = true
	return frost


# --- Inside ---------------------------------------------------------------------

## Fires a pooled one-shot effect of `kind` at `at`.
static func _burst(kind: String, at: Vector3, spec: Dictionary) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.current_scene == null:
		return
	var pool: Dictionary = _pools.get(kind, {"nodes": [], "next": 0})
	_pools[kind] = pool
	var nodes: Array = pool["nodes"]
	# Drop emitters that went away with an old scene.
	for i in range(nodes.size() - 1, -1, -1):
		if not is_instance_valid(nodes[i]) or not nodes[i].is_inside_tree():
			nodes.remove_at(i)
	var emitter: CPUParticles3D
	if nodes.size() < POOL_SIZE:
		emitter = _emitter(spec)
		tree.current_scene.add_child(emitter)
		nodes.append(emitter)
	else:
		pool["next"] = (int(pool["next"]) + 1) % nodes.size()
		emitter = nodes[pool["next"]]
	emitter.amount = maxi(int(spec["amount"] * _effects_share()), 1)
	emitter.global_position = at
	emitter.restart()
	emitter.emitting = true


static func _emitter(spec: Dictionary) -> CPUParticles3D:
	var emitter := CPUParticles3D.new()
	emitter.one_shot = true
	emitter.explosiveness = 1.0
	emitter.amount = maxi(int(spec["amount"] * _effects_share()), 1)
	emitter.lifetime = spec["life"]
	emitter.emitting = false
	emitter.direction = Vector3.UP
	emitter.spread = spec.get("spread", 180.0)
	var speed: Vector2 = spec["speed"]
	emitter.initial_velocity_min = speed.x
	emitter.initial_velocity_max = speed.y
	emitter.gravity = Vector3(0.0, spec["gravity"], 0.0)
	var size: float = spec["size"]
	emitter.scale_amount_min = 0.7
	emitter.scale_amount_max = 1.2
	var cube := BoxMesh.new()
	cube.size = Vector3.ONE * size
	cube.material = _particle_material()
	emitter.mesh = cube
	var color: Color = spec["color"]
	if spec.get("fade", false):
		var ramp := Gradient.new()
		ramp.set_color(0, color)
		ramp.set_color(1, Color(color, 0.0))
		emitter.color_ramp = ramp
	else:
		emitter.color = color
	emitter.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return emitter


## One unlit, vertex-coloured material shared by every particle.
static func _particle_material() -> StandardMaterial3D:
	if _material == null:
		_material = StandardMaterial3D.new()
		_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_material.vertex_color_use_as_albedo = true
		_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return _material


static func _effects_share() -> float:
	var tree := Engine.get_main_loop() as SceneTree
	var graphics = tree.root.get_node_or_null("Graphics") if tree != null else null
	if graphics == null:
		return 1.0
	return graphics.setting("effects", 1.0)
