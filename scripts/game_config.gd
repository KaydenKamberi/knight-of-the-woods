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
## Mini boss health: base + per_wave × (wave − 1). 300 in wave 1, 2,100 in wave 19 (V-7).
const MINI_BOSS_BASE_HEALTH := 300
const MINI_BOSS_HEALTH_PER_WAVE := 100
## Mini boss hit: base + per_wave × wave. 16 in wave 1, 34 in wave 19 (E-4).
const MINI_BOSS_BASE_DAMAGE := 15
const MINI_BOSS_DAMAGE_PER_WAVE := 1
## For the big boss in wave 20 (M6).
const BIG_BOSS_DAMAGE := 30

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

# --- Materials and loot (R-1, R-2, R-11, R-13) ------------------------------------

## Every material, in the order the HUD and crafting menu list them.
const MATERIALS := ["wood", "stone", "raw_iron", "iron", "coal", "string", "cryo", "ultra"]
const MATERIAL_NAMES := {
	"wood": "Wood", "stone": "Stone", "raw_iron": "Raw iron", "iron": "Iron", "coal": "Coal",
	"string": "String", "cryo": "Cryo Crystal", "ultra": "Ultra Crystal",
}
## What a regular dummy can drop, and how likely each is (bigger = more common).
const DROP_WEIGHTS := {"wood": 3, "stone": 3, "raw_iron": 2, "coal": 2, "string": 1}
## A regular dummy drops between these many materials.
const DUMMY_DROPS_MIN := 1
const DUMMY_DROPS_MAX := 2
## A mini boss always drops this many Cryo Crystals plus this many random materials...
const MINI_BOSS_CRYO_DROPS := 1
const MINI_BOSS_RANDOM_DROPS := 3
## ...and has this chance (0.05 = 1 in 20) of an Ultra Crystal.
const ULTRA_DROP_CHANCE := 0.05
## How close the knight has to walk to loot to pick it up, in metres.
const LOOT_PICKUP_RANGE := 1.3

# --- Crafting (R-5 to R-14, weapon stats table) -----------------------------------

## Weapon and armour recipes. Weapons are listed in hotbar order.
const RECIPES := {
	"spear": {"wood": 3, "stone": 2},
	"sword": {"iron": 3, "wood": 1},
	"axe": {"iron": 3, "wood": 2},
	"bow": {"wood": 3, "string": 2},
	"cryo_dagger": {"cryo": 1, "stone": 2, "string": 1},
	"cryo_hammer": {"cryo": 2, "iron": 3},
	"ultra_blaster": {"ultra": 1},
	"cryo_armor": {"iron": 3, "stone": 3, "cryo": 2},
}
## The furnace is built once and unlocks smelting (R-14).
const FURNACE_COST := {"stone": 15}
const SMELT_COST := {"raw_iron": 1, "coal": 1}
## Where the furnace goes in the clearing.
const FURNACE_SPOT := Vector3(4.5, 0.0, 2.5)

# --- Weapons (weapon stats table, R-6, R-8, R-12, R-15 to R-17) --------------------

## kind: "throw" (knives), "melee", "bow" or "blaster".
## reach: melee range in metres. cooldown: seconds (world time) between attacks.
## sweep: melee weapons that hit everyone in front instead of just the nearest.
const WEAPONS := {
	"knife": {"name": "Knives", "kind": "throw", "damage": KNIFE_DAMAGE, "cooldown": 0.25},
	"spear": {"name": "Spear", "kind": "melee", "damage": 60, "reach": 3.2, "cooldown": 0.75, "sweep": false},
	"sword": {"name": "Sword", "kind": "melee", "damage": 50, "reach": 2.1, "cooldown": 0.4, "sweep": false},
	"axe": {"name": "Axe", "kind": "melee", "damage": 75, "reach": 2.1, "cooldown": 1.0, "sweep": true},
	"bow": {"name": "Bow", "kind": "bow", "damage": 40, "cooldown": 0.6},
	"cryo_dagger": {"name": "Cryo dagger", "kind": "melee", "damage": 30, "reach": 1.8, "cooldown": 0.4, "sweep": false},
	"cryo_hammer": {"name": "Cryo hammer", "kind": "melee", "damage": 100, "reach": 2.3, "cooldown": 1.4, "sweep": true},
	"ultra_blaster": {"name": "Ultra blaster", "kind": "blaster", "damage": 1000, "cooldown": 0.8},
}
## Cryo dagger (R-8): a frozen head shatters on the next dagger hit and defeats a
## regular dummy. A mini boss takes this much damage instead (shattering one
## outright would make the dagger beat every boss in two hits).
const DAGGER_SHATTER_BOSS_DAMAGE := 300
## Cryo hammer ground slam (R-6), once per wave.
const HAMMER_SLAM_RADIUS := 6.0
const HAMMER_SLAM_DAMAGE := 150
const HAMMER_SLAM_FREEZE_TIME := 3.0
## Regular dummies below this share of their health shatter instantly.
const HAMMER_SLAM_SHATTER_BELOW := 0.5
## Cryo hammer spin (R-9, R-16).
const HAMMER_SPIN_RADIUS := 3.0
const HAMMER_SPIN_DAMAGE := 50
const HAMMER_SPIN_COOLDOWN := 5.0
## Ultra blaster (R-12, R-17): shots per crafted blaster, and blast radius.
const BLASTER_SHOTS := 3
const BLASTER_BLAST_RADIUS := 4.0
## Cryo armour (R-10): share of melee damage reflected, and how much the attacker slows and for how long.
const ARMOR_REFLECT := 0.25
const ARMOR_SLOW := 0.5
const ARMOR_SLOW_TIME := 1.0

