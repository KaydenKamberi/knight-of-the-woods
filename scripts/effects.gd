extends RefCounted
## Simple visual effects built in code.


## A glowing sphere that grows to `radius` and fades out, for explosions and the
## hammer's icy blasts. It runs on world time, so it slows down with the world.
static func burst(at: Vector3, radius: float, color: Color, scene_root: Node) -> void:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(color, 0.6)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	var sphere := SphereMesh.new()
	sphere.radius = 1.0
	sphere.height = 2.0
	sphere.radial_segments = 12
	sphere.rings = 6
	sphere.material = material
	var mesh := MeshInstance3D.new()
	mesh.mesh = sphere
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	scene_root.add_child(mesh)
	mesh.global_position = at
	mesh.scale = Vector3.ONE * 0.2

	var light := OmniLight3D.new()
	light.light_color = color
	light.light_energy = 3.0
	light.omni_range = radius * 1.5
	mesh.add_child(light)

	var grow := mesh.create_tween().set_parallel()
	grow.tween_property(mesh, "scale", Vector3.ONE * radius, 0.35).set_ease(Tween.EASE_OUT)
	grow.tween_property(material, "albedo_color:a", 0.0, 0.5)
	grow.tween_property(light, "light_energy", 0.0, 0.5)
	grow.chain().tween_callback(mesh.queue_free)
