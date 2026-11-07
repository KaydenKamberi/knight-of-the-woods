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
## Regular enemies' looks (D-1). Every wave mixes them. Apart from bandits they
## all fight exactly like the version 1 dummies; riders sit on a horse.
const ENEMY_LOOKS := ["bandit", "archer", "swordsman", "rider"]
const ENEMY_LOOK_COLORS := {
	"bandit": Color(0.33, 0.29, 0.27),
	"archer": Color(0.42, 0.53, 0.3),
	"swordsman": Color(0.56, 0.58, 0.62),
	"rider": Color(0.36, 0.43, 0.63),
}
const HORSE_COLOR := Color(0.5, 0.34, 0.22)
## Bandits (D-2 to D-5): touching the knight steals this many random materials
## (never weapons), once per bandit. The thief then runs for the nearest map
## edge this much faster than it walks, and is gone (with the loot) if it gets
## this far from the middle of the forest.
const BANDIT_STEAL_AMOUNT := 5
const BANDIT_FLEE_SPEED := 1.3
const BANDIT_ESCAPE_RADIUS := 32.5

# --- The big boss (wave 20, V-4, V-5, V-8) -----------------------------------------

const BIG_BOSS_NAME := "The Grand Effigy"
## 4,000 health: exactly 4 Ultra blaster hits.
const BIG_BOSS_HEALTH := 4000
## Heavy swing damage (E-4) and its wind-up in seconds (the warning before it lands).
const BIG_BOSS_DAMAGE := 30
const BIG_BOSS_SWING_WINDUP := 1.0
## Size compared to a regular dummy (mini bosses are 1.45 to 1.9).
const BIG_BOSS_SIZE := 2.8
const BIG_BOSS_SPEED := 1.8
const BIG_BOSS_COLOR := Color(0.32, 0.16, 0.12)
## Ground stomp: everyone within the radius takes damage and is knocked back.
## A red ring on the ground grows during the wind-up as a warning.
const BIG_BOSS_STOMP_RADIUS := 6.0
const BIG_BOSS_STOMP_DAMAGE := 20
## Knockback speed in metres per second.
const BIG_BOSS_STOMP_KNOCKBACK := 12.0
const BIG_BOSS_STOMP_WINDUP := 1.2
const BIG_BOSS_STOMP_COOLDOWN := 7.0
## Cryo dagger on the big boss: a frozen head doesn't shatter; the next dagger hit does this much.
const BIG_BOSS_HEAD_SHATTER_DAMAGE := 400

# --- Waves and breaks (V-1, R-3, R-4) ------------------------------------------

const DUMMIES_PER_WAVE := 2
## Seconds before the first wave.
const FIRST_BREAK := 10.0
## Break after wave 1, and after LAST_BREAK_WAVE. Breaks in between grow evenly.
const SHORTEST_BREAK := 30.0
const LONGEST_BREAK := 60.0
const LAST_BREAK_WAVE := 14
## The final wave (V-4): the big boss at the castle.
const LAST_WAVE := 20

# --- Wave 20, the final battle (V-4) -------------------------------------------------

## How many earlier mini bosses come back (picked at random from waves 1 to 19).
## Each keeps the health it had in its own wave.
const FINAL_MINI_BOSS_COUNT := 10
## The enemies arrive in this many groups, so nothing lags. The big boss comes with the last.
const FINAL_WAVE_GROUPS := 4
## The next group comes when this few enemies are left standing...
const FINAL_NEXT_GROUP_WHEN_ALIVE := 6
## ...or after this many seconds (world time), whichever comes first.
const FINAL_GROUP_MAX_WAIT := 45.0

# --- Winning (V-5) ---------------------------------------------------------------------

## Slow motion as the last enemy falls: world speed and real seconds.
const VICTORY_SLOW_SPEED := 0.15
const VICTORY_SLOW_TIME := 1.5
## Real seconds the camera takes to pan over to the castle.
const VICTORY_PAN_TIME := 3.5

# --- The castle (S-2) -------------------------------------------------------------------

## The middle of the courtyard. The castle stands at the south edge of the forest,
## with its gate facing the middle of the forest (towards -Z).
const CASTLE_CENTER := Vector3(0.0, 0.0, 22.0)
## Half the width of the square of walls (measured to the middle of the walls).
const CASTLE_HALF_SIZE := 8.0
const CASTLE_WALL_HEIGHT := 4.0
const CASTLE_WALL_THICKNESS := 1.0
const CASTLE_TOWER_SIZE := 3.0
const CASTLE_TOWER_HEIGHT := 6.5
## The gate is a full-height opening (no lintel), so even the big boss fits through.
const CASTLE_GATE_WIDTH := 4.0
## The stone posts either side of the gate stand a little taller than the walls.
const CASTLE_GATE_POST_HEIGHT := 5.2
## Trees, rocks and bushes keep this far outside the walls.
const CASTLE_TREE_MARGIN := 3.0
## Enemies never spawn closer than this to the middle of the courtyard.
const CASTLE_SPAWN_KEEP_OUT := 17.0
## Where the knight starts: in the courtyard, facing the gate.
const KNIGHT_START := Vector3(0.0, 0.0, 24.0)

# --- The secret bunker (B-1 to B-4) ------------------------------------------------

## The bunker room. It sits far outside the forest, where nothing outside can see
## or reach it; the trapdoor and the hidden castle door take the knight there.
const BUNKER_CENTER := Vector3(0.0, 0.0, -160.0)
## Inside size: width (x), height (y) and depth (z), in metres.
const BUNKER_SIZE := Vector3(12.0, 3.6, 9.0)
## The trapdoor, half hidden by leaves and bushes at the edge of the clearing.
const TRAPDOOR_SPOT := Vector3(-4.2, 0.0, -1.0)
## The hidden door, measured from the middle of the courtyard: a loose stone on
## the inside of the left (west) wall.
const CASTLE_DOOR_OFFSET := Vector3(-7.47, 0.0, 2.0)
## What the chest holds (B-3). It's never refilled during a run.
const BUNKER_CHEST := {"diamond": 6, "titanium": 3}
## How close the knight has to be to use an entrance, a ladder or the chest, in metres.
const PASSAGE_USE_RANGE := 1.8
## Real seconds the trapdoor or the stone takes to open before the fade, the
## fade itself (each way), and how long an entrance stays open afterwards.
const PASSAGE_OPEN_TIME := 0.4
const BUNKER_FADE_TIME := 0.3
const PASSAGE_CLOSE_DELAY := 1.5
## Torch light: brightness, how far it reaches (m), and how much it flickers.
const TORCH_ENERGY := 1.7
const TORCH_RANGE := 6.5
const TORCH_FLICKER := 0.3

# --- The army (A-1, A-2, A-6) ----------------------------------------------------

## Soldiers at the start of a run, split evenly between the three roles.
const ARMY_SIZE := 25
## How many soldiers run in when the knight drops to RESCUE_HEALTH_FRACTION of his health.
const RESCUE_COUNT := 4
const RESCUE_HEALTH_FRACTION := 0.5
## How far from the knight rescuers appear, in metres, when he's far from the castle.
const RESCUE_SPAWN_DISTANCE := 7.0
## Rescuers run out of the castle gate if the knight is within this many metres of
## it; farther away they appear near him, so they arrive in time.
const RESCUE_FROM_GATE_RANGE := 20.0
## How many idle soldiers stand in the courtyard between waves (all of them by
## default; lower it if phones struggle).
const IDLE_SOLDIERS_SHOWN := 25
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
const MATERIALS := ["wood", "stone", "raw_iron", "iron", "coal", "string", "gunpowder",
		"cryo", "ultra", "diamond", "titanium", "meat", "berries"]
const MATERIAL_NAMES := {
	"wood": "Wood", "stone": "Stone", "raw_iron": "Raw iron", "iron": "Iron", "coal": "Coal",
	"string": "String", "cryo": "Cryo Crystal", "ultra": "Ultra Crystal",
	"gunpowder": "Gunpowder", "meat": "Meat", "berries": "Berries",
	"diamond": "Diamond", "titanium": "Titanium",
}
## What a regular enemy can drop, and how likely each is (bigger = more common).
## Gunpowder drops about as often as coal (N-2); meat is a taming food (N-4).
const DROP_WEIGHTS := {"wood": 3, "stone": 3, "raw_iron": 2, "coal": 2, "gunpowder": 2, "string": 1, "meat": 1}
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
## Berry bushes the knight can pick with E / Grab (N-4). Each gives this many
## berries, then grows them back when a wave is cleared.
const BERRY_BUSH_COUNT := 10
const BERRIES_PER_BUSH := 2

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
	"dagger": {"stone": 1, "wood": 1},
	"bat": {"wood": 2},
	"grenade": {"gunpowder": 2, "iron": 1},
	"diamond_sword": {"diamond": 3, "wood": 1},
	"diamond_axe": {"diamond": 3, "wood": 2},
	"diamond_dagger": {"diamond": 2, "wood": 1},
	"musket": {"titanium": 3, "gunpowder": 4},
	"cryo_armor": {"iron": 3, "stone": 3, "cryo": 2},
}
## Items that can be crafted again and again: each craft adds more uses.
const REPEAT_CRAFTS := ["ultra_blaster", "grenade"]
## The furnace is built once, at its spot in the castle courtyard, and unlocks smelting (R-14).
const FURNACE_COST := {"stone": 10}
const SMELT_COST := {"raw_iron": 1, "coal": 1}
## The furnace's spot, measured from the middle of the courtyard (the back-right corner).
const FURNACE_OFFSET := Vector3(4.5, 0.0, 4.5)
## How close the knight has to be to build or use it, in metres.
const FURNACE_USE_RANGE := 3.0

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
	"dagger": {"name": "Dagger", "kind": "melee", "damage": 20, "reach": 1.7, "cooldown": 0.3, "sweep": false},
	"bat": {"name": "Bat", "kind": "melee", "damage": 10, "reach": 2.0, "cooldown": 0.45, "sweep": false, "push": 7.0},
	"grenade": {"name": "Grenades", "kind": "grenade", "cooldown": 0.8},
	"diamond_sword": {"name": "Diamond sword", "kind": "melee", "damage": 65, "reach": 2.1, "cooldown": 0.4,
			"sweep": false, "crit": true},
	"diamond_axe": {"name": "Diamond axe", "kind": "melee", "damage": 85, "reach": 2.1, "cooldown": 1.0,
			"sweep": true, "crit": true},
	"diamond_dagger": {"name": "Diamond dagger", "kind": "melee", "damage": 25, "reach": 1.7, "cooldown": 0.3,
			"sweep": false, "crit": true},
	"musket": {"name": "Musket", "kind": "musket", "damage": 90, "cooldown": 0.2, "crit": true},
}
## Musket (G-1): unlimited shots, but every shot needs MUSKET_RELOAD_TIME seconds
## to reload. The reload counts real seconds, not world time, so it reloads at
## full speed while the world is slowed. The ball flies (and drops a little) on world time.
const MUSKET_RELOAD_TIME := 3.0
const MUSKET_BALL_SPEED := 60.0
## Critical hits (G-2): weapons marked "crit" have this chance per hit (1 in 12)
## of doing CRIT_MULTIPLIER times their damage.
const CRIT_CHANCE := 1.0 / 12.0
const CRIT_MULTIPLIER := 2
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
## Grenades (G-3): thrown in an arc, they explode where they land. Every regular
## enemy in the blast is destroyed. A mini boss loses 1 / (its wave × 2) of its
## health per grenade, so wave n's mini boss takes 2 × n grenades; the big boss
## takes BIG_BOSS_GRENADES. They never hurt the knight, soldiers or tamed animals.
const GRENADE_BLAST_RADIUS := 3.5
const GRENADE_THROW_SPEED := 14.0
const GRENADES_PER_WAVE_OF_BOSS := 2
const BIG_BOSS_GRENADES := 40
## Cryo armour (R-10): share of melee damage reflected, and how much the attacker slows and for how long.
const ARMOR_REFLECT := 0.25
const ARMOR_SLOW := 0.5
const ARMOR_SLOW_TIME := 1.0


# --- Animals and taming (H-1 to H-6) -------------------------------------------------

## How many of each wild animal roam the forest. Missing ones (killed, or tamed)
## are topped back up whenever a wave is cleared.
const WILD_ANIMALS := {"bear": 2, "wolf": 3, "deer": 3, "bunny": 4}
## Per animal, once tamed: health, damage per hit, running speed (m/s), attack
## reach (m), seconds between attacks, wind-up before a hit lands (s), and the
## taming food (H-2, H-4). Health values are starting guesses to tune.
const ANIMALS := {
	"bear": {"name": "Bear", "health": 300, "damage": 90, "speed": 4.2, "range": 1.9,
			"cooldown": 1.6, "windup": 0.45, "food": "meat"},
	"wolf": {"name": "Wolf", "health": 150, "damage": 50, "speed": 6.5, "range": 1.5,
			"cooldown": 1.0, "windup": 0.25, "food": "meat"},
	"deer": {"name": "Deer", "health": 120, "damage": 20, "speed": 5.0, "range": 1.6,
			"cooldown": 1.2, "windup": 0.2, "food": "berries"},
	"bunny": {"name": "Bunny", "health": 50, "damage": 5, "speed": 8.0, "range": 1.0,
			"cooldown": 0.6, "windup": 0.1, "food": "berries"},
}
## The most animals the knight can have tamed at once (H-3).
const MAX_TAMED := 2
## How close the knight has to be to an animal to tame it, in metres.
const TAME_RANGE := 2.6
## Wild animals amble about at this speed.
const WILD_WANDER_SPEED := 1.2
## A wild bear or wolf that's hit chases the knight for this long (world-time
## seconds), hitting for this share of its tamed damage. Deer and bunnies run away.
const ANIMAL_ANGRY_TIME := 12.0
const WILD_DAMAGE_SHARE := 0.3
## Tamed animals go for enemies within this many metres of the knight, and
## otherwise stay this close to him.
const ANIMAL_GUARD_RANGE := 16.0
const ANIMAL_FOLLOW_DISTANCE := 3.5
## A deer charges (at this many times its speed) at enemies closer than this.
const DEER_CHARGE_SPEED := 2.0
const DEER_CHARGE_DISTANCE := 6.0


# --- The look: palette and toon shading (M7 art pass) -----------------------------

## One shared palette, used by every material in the game.
const PALETTE := {
	"sky_top": Color("8fc0b8"),
	"sky_horizon": Color("c4dccf"),
	"fog": Color("b7d3c6"),
	"ground": Color("7fae6a"),
	"sand": Color("e6d3a3"),
	"leaf_1": Color("5f9e5a"),
	"leaf_2": Color("7cbf6b"),
	"leaf_3": Color("3f7a4f"),
	"pine": Color("4f8c63"),
	"trunk": Color("6b4a35"),
	"rock": Color("9aa3a0"),
	"stone": Color("a9aeab"),
	"dark_stone": Color("7f8784"),
	"courtyard": Color("b6ad98"),
	"roof": Color("5d6f86"),
	"wood": Color("7a5236"),
	"berry": Color("c0392b"),
	"flower_1": Color("f2d16b"),
	"flower_2": Color("e88fb4"),
	"flower_3": Color("f4f1e8"),
	"grass_base": Color("4f8a4c"),
	"grass_tip": Color("a8d07a"),
	"knight_green": Color(0.16, 0.38, 0.22),
	"knight_gold": Color(0.86, 0.68, 0.22),
	"steel": Color(0.66, 0.7, 0.74),
}
## Toon shading: the tint of the shadow side, how much light reaches it, the
## brightness of the middle band, where the bands start, how soft their edges
## are, and the rim light on characters.
const TOON_SHADOW_TINT := Color(0.22, 0.4, 0.46)
const TOON_SHADOW_FILL := 0.55
const TOON_MID_LEVEL := 0.68
const TOON_THRESHOLD_LOW := 0.08
const TOON_THRESHOLD_HIGH := 0.45
const TOON_SOFTNESS := 0.03
const TOON_RIM_COLOR := Color(1.0, 0.97, 0.88)
## Rim light strength on characters (the knight, enemies, soldiers).
const CHARACTER_RIM := 0.35

# --- Graphics settings (M7, F-3, F-5) ----------------------------------------------

## The three graphics levels. Changing a number here changes that level.
## shadows: "off", "important" (knight and bosses) or "all".
## view_distance: metres; scenery fades out over the last FADE_BAND metres.
## grass: share of grass blades drawn (0 = flat painted ground).
## effects: share of particles (1 = full). floating_leaves: how many drift around.
## ragdolls_kept: defeated enemies whose pieces stay on the ground at once.
const GRAPHICS_LEVELS := {
	"low": {"shadows": "off", "render_scale": 0.6, "view_distance": 38.0, "grass": 0.0,
			"grass_wind": 0.0, "leaf_sway": 0.0, "toon_steps": 2.0, "rim": 0.0,
			"color_grade": false, "effects": 0.35, "floating_leaves": 0,
			"ragdolls_kept": 3, "debris_lifetime": 4.0},
	"medium": {"shadows": "important", "render_scale": 0.8, "view_distance": 55.0, "grass": 0.5,
			"grass_wind": 0.6, "leaf_sway": 1.0, "toon_steps": 3.0, "rim": 1.0,
			"color_grade": true, "effects": 0.65, "floating_leaves": 12,
			"ragdolls_kept": 8, "debris_lifetime": 8.0},
	"high": {"shadows": "all", "render_scale": 1.0, "view_distance": 80.0, "grass": 1.0,
			"grass_wind": 1.0, "leaf_sway": 1.0, "toon_steps": 3.0, "rim": 1.0,
			"color_grade": true, "effects": 1.0, "floating_leaves": 30,
			"ragdolls_kept": 20, "debris_lifetime": 12.0},
}
const GRAPHICS_ORDER := ["low", "medium", "high"]
const FADE_BAND := 10.0
## Grass blades across the forest on High, and the size of each MultiMesh chunk
## (trees, rocks, grass), in metres. Chunks let the camera skip what it can't see.
const GRASS_BLADES := 9000
const SCENERY_CHUNK := 24.0

# --- Performance (F-2, F-4) ---------------------------------------------------------

## Dummies, soldiers and mini bosses farther than this lose their small details (F-2).
const LOD_DETAIL_DISTANCE := 22.0
## Enemies and soldiers farther than this think every FAR_AI_FRAME_SKIP physics frames (F-4).
const FAR_AI_DISTANCE := 30.0
const FAR_AI_FRAME_SKIP := 4

# --- Title screen (M7) --------------------------------------------------------------

## Working title, shown on the title screen.
const GAME_TITLE := "Knight of the Still Woods"
