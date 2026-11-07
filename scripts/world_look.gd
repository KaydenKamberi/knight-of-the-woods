extends Node3D
## The shared look of the world (M7 art pass): the sky, the sun, the ground, and
## the WorldEnvironment with its fog, ambient light and colour grade. Used by the
## game and the title screen, so they always match.
##
## The Graphics autoload finds the environment and the sun through the groups
## below and adjusts them for the Low / Medium / High settings (shadows, fog
## distance, colour grade).


func _ready() -> void:
	add_to_group("world_look")
	Graphics.apply_to_world(self)


func environment() -> Environment:
	return ($WorldEnvironment as WorldEnvironment).environment


func sun() -> DirectionalLight3D:
	return $Sun as DirectionalLight3D
