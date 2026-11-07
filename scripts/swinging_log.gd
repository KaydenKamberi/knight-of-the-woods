extends AnimatableBody3D
## A log hanging from two ropes that swings back and forth: the M2 test object
## for world time.
##
## The swing is worked out from the physics delta, which world time scales, so
## the log slows to a crawl when the knight stands still and swings at full
## speed when he moves. As an AnimatableBody3D it also shoves the knight aside
## if he walks into its path.

## How far the log swings to each side of straight down, in degrees.
@export var swing_degrees := 55.0
## Distance from the beam to the middle of the log, in metres. Sets how long one swing takes.
@export var rope_length := 3.2

var _swing_time := 0.0


func _physics_process(delta: float) -> void:
	_swing_time += delta
	# A pendulum swings back and forth at a rate set by its rope length.
	var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
	var swings_per_second := sqrt(gravity / rope_length)
	rotation.z = deg_to_rad(swing_degrees) * sin(_swing_time * swings_per_second)
