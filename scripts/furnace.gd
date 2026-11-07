extends StaticBody3D
## The furnace (PRD R-14). Built once from the crafting menu, it stands in the
## clearing and unlocks smelting raw iron into iron. It's just for show and
## for blocking: smelting itself happens in the crafting menu.


var _model: Node3D


func _ready() -> void:
	_model = Node3D.new()
	_model.name = "Model"
	add_child(_model)
	var stone := Color(0.52, 0.5, 0.47)
	var dark_stone := Color(0.36, 0.34, 0.32)
	_box(Vector3(1.4, 1.1, 1.2), stone, Vector3(0, 0.55, 0))
	_box(Vector3(1.5, 0.15, 1.3), dark_stone, Vector3(0, 1.15, 0))
	_box(Vector3(1.0, 0.5, 0.9), stone, Vector3(0, 1.45, 0))
	_box(Vector3(0.4, 1.0, 0.4), dark_stone, Vector3(0.3, 2.2, 0.2))

	# The glowing mouth of the fire, on the side facing the middle of the clearing.
	var glow := StandardMaterial3D.new()
	glow.albedo_color = Color(1.0, 0.45, 0.1)
	glow.emission_enabled = true
	glow.emission = Color(1.0, 0.4, 0.05)
	glow.emission_energy_multiplier = 2.0
	var mouth := BoxMesh.new()
	mouth.size = Vector3(0.6, 0.45, 0.05)
	mouth.material = glow
	var mouth_mesh := MeshInstance3D.new()
	mouth_mesh.mesh = mouth
	mouth_mesh.position = Vector3(0, 0.45, -0.61)
	_model.add_child(mouth_mesh)
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.55, 0.2)
	light.light_energy = 1.2
	light.omni_range = 4.0
	light.position = Vector3(0, 0.6, -1.0)
	_model.add_child(light)
	# Face the mouth towards the middle of the clearing.
	var to_middle := Vector3(-position.x, 0.0, -position.z)
	if to_middle.length_squared() > 0.01:
		rotation.y = atan2(-to_middle.x, -to_middle.z)

	var shape := BoxShape3D.new()
	shape.size = Vector3(1.4, 1.7, 1.2)
	var collision := CollisionShape3D.new()
	collision.shape = shape
	collision.position = Vector3(0, 0.85, 0)
	add_child(collision)

	# Pop up out of the ground so it's easy to spot. (Only the model scales:
	# physics bodies shouldn't be scaled.)
	_model.scale = Vector3.ONE * 0.01
	create_tween().tween_property(_model, "scale", Vector3.ONE, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _box(size: Vector3, color: Color, at: Vector3) -> void:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 1.0
	var box := BoxMesh.new()
	box.size = size
	box.material = material
	var mesh := MeshInstance3D.new()
	mesh.mesh = box
	mesh.position = at
	_model.add_child(mesh)
