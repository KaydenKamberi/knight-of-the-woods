extends Node
## World time: the game's core mechanic (PRD T-1 to T-4).
##
## Time runs at full speed while the player moves, looks around or acts, and
## slows to a crawl when they stand still. This is an autoload, so any script
## can reach it as `WorldTime`.
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
## Anything the player does that should wake time up (moving, looking, and later
## throwing or swinging) calls WorldTime.report_activity().

# --- Tuning: change these numbers to adjust how the mechanic feels ----------

## World speed while the player stands still. 0.05 means 5% speed (T-1).
var slow_speed := 0.05
## Real seconds to blend from slow up to full speed once the player acts (T-2).
var speed_up_time := 0.15
## Real seconds to blend from full speed down to slow once the player stops.
var slow_down_time := 0.35
## How long one bit of activity (a mouse twitch, a tap) keeps time running, in real seconds.
var activity_hold := 0.1
## Set to false to turn the mechanic off and keep time at full speed (handy for testing).
var enabled := true

# -----------------------------------------------------------------------------

## The current world speed, from slow_speed (standing still) up to 1.0 (full speed).
var speed := 1.0
## Real seconds since the last frame, not affected by world speed.
var real_delta := 0.0

## 0 means fully slowed, 1 means full speed. Moves at a steady rate and is eased into speed.
var _blend := 0.0
## Real seconds of activity left before time starts slowing down.
var _active_time_left := 0.0
var _last_frame_usec := 0


func _ready() -> void:
	# Keep running even if the game is paused later, so time can still blend.
	process_mode = Node.PROCESS_MODE_ALWAYS
	_last_frame_usec = Time.get_ticks_usec()
	_apply_speed()


func _process(_delta: float) -> void:
	# The delta passed in is already scaled by world speed, so measure real time ourselves.
	var now := Time.get_ticks_usec()
	real_delta = minf((now - _last_frame_usec) / 1_000_000.0, 0.1)
	_last_frame_usec = now

	_active_time_left = maxf(_active_time_left - real_delta, 0.0)
	var target := 1.0 if _active_time_left > 0.0 or not enabled else 0.0
	if _blend < target:
		_blend = minf(_blend + real_delta / maxf(speed_up_time, 0.001), target)
	elif _blend > target:
		_blend = maxf(_blend - real_delta / maxf(slow_down_time, 0.001), target)
	_apply_speed()


## Tells world time the player is doing something, so it should run at full speed.
## hold is how many real seconds this keeps time awake; leave it out to use activity_hold.
func report_activity(hold := -1.0) -> void:
	_active_time_left = maxf(_active_time_left, activity_hold if hold < 0.0 else hold)


func _apply_speed() -> void:
	speed = lerpf(slow_speed, 1.0, smoothstep(0.0, 1.0, _blend))
	Engine.time_scale = speed
	AudioServer.playback_speed_scale = speed
