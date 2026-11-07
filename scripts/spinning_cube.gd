extends MeshInstance3D
## Spins the test cube so we can see at a glance that the project runs.

## How fast the cube turns, in degrees per second.
@export var spin_speed_degrees: float = 90.0


func _process(delta: float) -> void:
	rotate_y(deg_to_rad(spin_speed_degrees) * delta)
