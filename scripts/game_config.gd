extends RefCounted
## Every number worth tuning, in one place.
##
## Other scripts read these with
## `const Config := preload("res://scripts/game_config.gd")` and then
## `Config.ARMY_SIZE` and so on. Change a number here, save, and run the game.
## (Exported settings on nodes take their defaults from here. A value typed into
## the Inspector overrides this file for that one node.)

# --- World time (T-1, T-2) -----------------------------------------------------

## World speed while standing still. 0.05 means 5%.
const TIME_SLOW_SPEED := 0.05
## Ramp step added while a move key is held (+10%), and real seconds between steps.
const TIME_STEP_SIZE := 0.1
const TIME_STEP_INTERVAL := 0.3
## Step taken away after letting go, and real seconds between those steps.
const TIME_DROP_STEP_SIZE := 0.1
const TIME_DROP_STEP_INTERVAL := 0.1
## World speed during a throw/attack bump, and how long it lasts (real seconds).
const TIME_BUMP_SPEED := 0.6
const TIME_BUMP_TIME := 0.4

# --- Knight (E-3, E-4) -----------------------------------------------------------

const PLAYER_HEALTH := 100
## How many throwing knives the knight can carry (R-15).
const MAX_KNIVES := 3
const KNIFE_DAMAGE := 50
## Seconds (world time) before a poster grows a new knife (W-6).
const POSTER_RESPAWN_DELAY := 5.0

# --- Dummies and mini bosses (E-4, V-1, V-7) -----------------------------------

const DUMMY_HEALTH := 100
const DUMMY_DAMAGE := 10

# --- Waves and breaks (V-1, R-3, R-4) ------------------------------------------

const DUMMIES_PER_WAVE := 2
## Seconds before the first wave.
const FIRST_BREAK := 10.0
## Break after wave 1, and after LAST_BREAK_WAVE. Breaks in between grow evenly.
const SHORTEST_BREAK := 30.0
const LONGEST_BREAK := 60.0
const LAST_BREAK_WAVE := 14

# --- The army (A-1, A-2, A-6) ----------------------------------------------------

## Soldiers at the start of a run, split evenly between the three roles.
const ARMY_SIZE := 25
## How many soldiers run in when the knight drops to RESCUE_HEALTH_FRACTION of his health.
const RESCUE_COUNT := 4
const RESCUE_HEALTH_FRACTION := 0.5
## How far from the knight rescuers appear, in metres.
const RESCUE_SPAWN_DISTANCE := 7.0
const SOLDIER_HEALTH := 60
const SOLDIER_SPEED := 4.0
## Soldiers farther than this from the knight use simpler AI that thinks less often (F-4).
const SOLDIER_FAR_DISTANCE := 25.0
## Seconds between soldier decisions, near and far.
const SOLDIER_THINK_NEAR := 0.25
const SOLDIER_THINK_FAR := 1.0
## Per role: damage per hit, attack range (m), seconds between attacks, wind-up (s).
## Archers also keep between keep_min and keep_max metres from their target.
const SOLDIER_STATS := {
	"archer": {"damage": 20, "range": 18.0, "cooldown": 1.8, "windup": 0.5, "keep_min": 8.0, "keep_max": 14.0},
	"spear": {"damage": 30, "range": 2.4, "cooldown": 1.3, "windup": 0.35},
	"sword": {"damage": 25, "range": 1.6, "cooldown": 0.9, "windup": 0.25},
}
const ARROW_SPEED := 30.0
