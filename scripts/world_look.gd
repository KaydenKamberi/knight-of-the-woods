extends Node3D
## The shared look of the world (M7 art pass): the sky, the sun, the ground, and
## the WorldEnvironment with its fog, ambient light and colour grade. Used by the
## game and the title screen, so they always match.
##
## The Graphics autoload finds the environment and the sun through the groups
## below and adjusts them for the Low / Medium / High settings (shadows, fog
## distance, colour grade).
##
## Inside the secret bunker (B-4) the sun is switched off and the sky light and
## fog turned down, so only the torches light the room.

## Sky light while underground, compared to outside.
const UNDERGROUND_AMBIENT := 0.35

## The environment is shared between scene loads (title screen, Try Again), so the
## outside sky light is remembered once and put back whenever a scene starts.
static var _outside_ambient := -1.0

var underground := false


func _ready() -> void:
	add_to_group("world_look")
	var env := environment()
	if _outside_ambient < 0.0:
		_outside_ambient = env.ambient_light_energy
	env.ambient_light_energy = _outside_ambient
	env.fog_enabled = true
	Graphics.apply_to_world(self)


func environment() -> Environment:
	return ($WorldEnvironment as WorldEnvironment).environment


func sun() -> DirectionalLight3D:
	return $Sun as DirectionalLight3D


## Called when the knight goes into or comes out of the bunker.
func set_underground(enabled: bool) -> void:
	if enabled == underground:
		return
	underground = enabled
	var env := environment()
	env.ambient_light_energy = _outside_ambient * (UNDERGROUND_AMBIENT if enabled else 1.0)
	env.fog_enabled = not enabled
	sun().visible = not enabled
