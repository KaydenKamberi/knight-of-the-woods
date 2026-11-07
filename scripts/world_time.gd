extends Node
## World time: the game's core mechanic (PRD T-1 to T-4).
##
## Standing still holds the world at a near-freeze. Holding a move key ramps
## time up in steps (5% -> 15% -> 25% ... -> 100%), so a short tap barely moves
## time and holding W keeps speeding it up. Letting go steps it back down.
## Throwing (and later swinging) gives a short bump. This is an autoload, so any
## script can reach it as `WorldTime`.
##
## It works by setting Engine.time_scale, so everything that runs on Godot's
## normal clock follows world time automatically (T-3): physics and ragdolls,
## the delta in _process and _physics_process, animations, tweens and timers.
## Sounds follow it through AudioServer.playback_speed_scale. Anything that
## doesn't follow Engine.time_scale by itself can read `speed` instead.
##
## To keep something in real time instead (like the player's camera look, T-4),
## don't scale it by delta, or use real_delta, or call set_ignore_time_scale(true)
## on its Tween.
##
## The knight calls report_moving() every frame a move key or the joystick is
## held, and bump() when he throws or grabs a knife.

const Config := preload("res://scripts/game_config.gd")

# --- Tuning: the starting values live in scripts/game_config.gd ---------------

## World speed while the player stands still. 0.05 means 5% speed (T-1).
var slow_speed := Config.TIME_SLOW_SPEED
## How much each ramp step adds while a move key is held. 0.1 means +10% (T-2).
var step_size := Config.TIME_STEP_SIZE
## Real seconds between ramp steps while a move key is held.
var step_interval := Config.TIME_STEP_INTERVAL
## How much each step takes away after the move key is let go.
var drop_step_size := Config.TIME_DROP_STEP_SIZE
## Real seconds between steps back down after letting go.
var drop_step_interval := Config.TIME_DROP_STEP_INTERVAL
## World speed during a bump from throwing or grabbing (never lowers the current speed).
var bump_speed := Config.TIME_BUMP_SPEED
## Real seconds a bump lasts.
var bump_time := Config.TIME_BUMP_TIME
## Set to true to let turning the camera ramp time too (the old K-2 behaviour).
var look_counts_as_moving := false
## Set to false to turn the mechanic off and keep time at full speed (handy for testing).
var enabled := true

# -----------------------------------------------------------------------------

## The current world speed, from slow_speed (standing still) up to 1.0 (full speed).
var speed := 1.0
## Real seconds since the last frame, not affected by world speed.
var real_delta := 0.0

## The stepped speed, before any bump.
var _ramp_speed := 0.0
var _moving_reported := false
var _was_moving := false
var _step_timer := 0.0
var _bump_left := 0.0
## A forced speed (the victory slow-motion), and real seconds left on it (-1 = until cleared).
var _override_speed := -1.0
var _override_left := 0.0
var _last_frame_usec := 0


func _ready() -> void:
	# Keep running even if the game is paused, so time can still settle.
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ramp_speed = slow_speed
	_last_frame_usec = Time.get_ticks_usec()
	_apply_speed()


func _process(_delta: float) -> void:
	# The delta passed in is already scaled by world speed, so measure real time ourselves.
	var now := Time.get_ticks_usec()
	real_delta = minf((now - _last_frame_usec) / 1_000_000.0, 0.1)
	_last_frame_usec = now

	var moving := _moving_reported
	_moving_reported = false
	if moving != _was_moving:
		_step_timer = 0.0
		if moving:
			# The first step happens the moment a key goes down.
			_ramp_speed = minf(_ramp_speed + step_size, 1.0)
	_was_moving = moving

	_step_timer += real_delta
	if moving:
		while _step_timer >= step_interval:
			_step_timer -= step_interval
			_ramp_speed = minf(_ramp_speed + step_size, 1.0)
	else:
		while _step_timer >= drop_step_interval:
			_step_timer -= drop_step_interval
			_ramp_speed = maxf(_ramp_speed - drop_step_size, slow_speed)

	_bump_left = maxf(_bump_left - real_delta, 0.0)
	if _override_speed >= 0.0 and _override_left >= 0.0:
		_override_left -= real_delta
		if _override_left < 0.0:
			_override_speed = -1.0
	_apply_speed()


## Call every frame the player is holding a move key or the joystick.
func report_moving() -> void:
	_moving_reported = true


## Call when the player looks around. Only counts if look_counts_as_moving is on.
func report_looking() -> void:
	if look_counts_as_moving:
		_moving_reported = true


## A short burst of speed for an action, like throwing a knife.
func bump() -> void:
	_bump_left = bump_time


## Forces world speed to `forced_speed` for `seconds` real seconds, or until
## clear_override() if seconds is negative. Used for the victory slow-motion.
func set_override(forced_speed: float, seconds := -1.0) -> void:
	_override_speed = forced_speed
	# A negative timer would end the override straight away, so "until cleared" is a huge number.
	_override_left = seconds if seconds >= 0.0 else 1.0e9


func clear_override() -> void:
	_override_speed = -1.0


func _apply_speed() -> void:
	speed = _ramp_speed
	if _bump_left > 0.0:
		speed = maxf(speed, bump_speed)
	if not enabled:
		speed = 1.0
	if _override_speed >= 0.0:
		speed = _override_speed
	Engine.time_scale = speed
	AudioServer.playback_speed_scale = speed
