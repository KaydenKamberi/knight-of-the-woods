# Knight of the Woods

A 3D wave-survival game made in **Godot 4.7** (standard version, not .NET), using the
**Compatibility** renderer so the web build runs in iPhone Safari.
The full design is in `Knight of the Still Woods — PRD.md`.

## Folder layout

| Folder | What goes in it |
| --- | --- |
| `scenes/` | Godot scenes (`.tscn`). `scenes/forest.tscn` is the main scene. `scenes/test_scene.tscn` is the M0 spinning-cube check. |
| `scripts/` | GDScript files (`.gd`). |
| `assets/models/` | 3D models (for example CC0 packs from Kenney, Quaternius, Poly Pizza). |
| `assets/textures/` | Textures and images. |
| `assets/audio/` | Sound effects and music. |
| `ui/` | Menus, HUD and touch-control scenes. |
| `builds/` | Exported builds. Ignored by git, so builds are never committed. |

## Open the project

1. Download **Godot 4.7.x (standard)** from <https://godotengine.org/download>.
2. Start Godot. In the Project Manager, click **Import**, pick this repo's `project.godot`, then click **Import & Edit**.
3. The first time it opens, Godot imports the files and creates a `.godot/` cache folder (ignored by git).
4. Press **F5** (or the ▶ Play button). The title screen opens; press **Play** and the knight starts in his castle courtyard, facing the gate out to the forest. (To skip the title while testing, open `scenes/forest.tscn` and use **Run Current Scene** in the editor, the clapperboard button at the top right.)

## Controls

| Action | PC | Phone / tablet |
| --- | --- | --- |
| Move | WASD or arrow keys | Joystick: put your thumb anywhere on the left half of the screen |
| Look around | Mouse (click the game first to capture the mouse) | Drag on the right half of the screen |
| Attack, throw or shoot (equipped weapon) | Left click | Attack button, bottom right |
| Hammer ground slam (once per wave) | Right click | Slam button (hammer only) |
| Hammer spin | F | Spin button (hammer only) |
| Grab a knife, pick berries, tame an animal, open the trapdoor / stone / chest, climb up | E | Grab button (appears when something is in reach, labelled GRAB, PICK, TAME, OPEN, PUSH or CLIMB) |
| Switch weapon | 1 to 9, or the mouse wheel (slots past 9: wheel only) | Weapon button (cycles) |
| Crafting menu (breaks only) | C | Craft button (appears during breaks) |
| Shift-lock: the knight turns with the camera | Left Shift | Lock icon, under the camera icon |
| Switch view (over the shoulder / inside the helmet) | V | Camera icon, top right |
| Pause menu: resume, graphics, main menu (also closes the crafting or furnace menu) | Esc | Pause icon, left of the camera icon |

Touch controls appear automatically on touch screens and stay hidden on PC.
If a PC has a touch screen, the last thing you used wins: touching the screen shows them, and typing or clicking a mouse hides them.

## What's in the game so far

- **`scenes/forest.tscn`**: the main scene. Sky, sunlight, ground, the forest, the knight and the HUD.
- **`scripts/forest.gd`**: builds the low-poly forest in code. Pines, leafy trees, rocks and bushes surround an open clearing, inside a thick ring of trees with an invisible wall so you can't walk out. Change the settings on the `Trees` node in the Inspector (seed, sizes, counts), then press **Rebuild Forest**. The forest is drawn in the editor too.
- **`scenes/knight.tscn`** + **`scripts/knight.gd`**: the knight, built from simple low-poly shapes, with walking, camera look, the view switch and shift-lock. The third-person camera sits over his right shoulder (`shoulder_offset`). Speed, mouse and touch sensitivity, and camera distance can be changed on the `Knight` node in the Inspector.
- **`ui/hud.tscn`** + **`scripts/hud.gd`** + **`scripts/touch_controls.gd`**: the on-screen joystick, drag-to-look, camera icon, and the PC controls hint.
- **`ui/helmet_eye_slit.gdshader`**: the dark helmet edges and eye slit shown in first person.
- **`scenes/wanted_poster.tscn`** + **`scripts/wanted_poster.gd`**: a wanted poster pinned to a tree with a knife. The forest generator puts them on trees around the clearing (set how many under **Wanted posters** on the `Trees` node). A new knife grows back a few seconds after you pull one out (`respawn_delay` on the poster, in world seconds).
- **`scenes/throwing_knife.tscn`** + **`scripts/throwing_knife.gd`**: a thrown knife. It spins, sticks in what it hits, and can be picked up again. Speed, drop, spin and damage (50) are set at the top of the script. A knife that hits nothing disappears after a few seconds.
- **`scenes/knife_model.tscn`**: the knife's low-poly model, shared by posters and thrown knives.
- **`scenes/dummy.tscn`** + **`scripts/dummy.gd`**: a straw training dummy that walks at the knight and swings at him. Health 100, so two knife hits. The first hit knocks it into a ragdoll; it lies there for a moment, then pulls itself back together. The second hit makes it fall apart. Speed, damage and timings are on the `Dummy` node in the Inspector. Its body is built in code, so in the editor you only see its collision capsule.
- **`scripts/crosshair.gd`**: the aiming dot in the middle of the screen.
- **`scripts/wave_manager.gd`** (the `WaveManager` node in `forest.tscn`): runs all 20 waves, including the final battle. See **Waves** below.
- **`scripts/castle.gd`** (the `Castle` node): the knight's castle, built from boxes in code (it shows in the editor too). See **The castle** below.
- **`scripts/furnace_site.gd`**, **`scripts/furnace.gd`**, **`scripts/furnace_menu.gd`**: the furnace hologram in the courtyard, the built furnace, and the smelting panel.
- **`scripts/victory.gd`** (the `Victory` node): the ending: slow motion, the camera pan to the castle, and the victory screen.
- **`scenes/title.tscn`** + **`scripts/title.gd`**: the title screen (the main scene).
- **`scenes/world_look.tscn`** + **`scripts/world_look.gd`**: the sky, sun, ground, fog and colour grade, shared by the game and the title screen.
- **`shaders/toon.gdshader`**, **`shaders/grass.gdshader`**: the toon shader used on everything solid, and the grass.
- **`scripts/art.gd`**: makes every material (toon shader + palette). **`scripts/fx.gd`**: particle effects. **`scripts/pool.gd`**: reuses knives, arrows and loot.
- **`scripts/graphics.gd`** (autoload `Graphics`): Low / Medium / High. **`scripts/ui_style.gd`**: the shared UI look. **`scripts/pause_menu.gd`**, **`scripts/graphics_picker.gd`**, **`scripts/orientation_hint.gd`**, **`scripts/floating_leaves.gd`**: the pause menu, the graphics buttons, the "turn your phone" message, and the drifting leaves.
- **`scripts/game_config.gd`**: **every number worth tuning, in one file**: health, damage, time ramp, breaks, army size, rescue count, soldier stats, loot drop rates, recipes, weapon stats and the hammer, blaster, dagger and armour values. Nodes' Inspector settings take their defaults from here.
- **`scripts/army.gd`** (the `Army` node) + **`scenes/soldier.tscn`** + **`scripts/soldier.gd`**: the knight's army. See **The army** below.
- **`scenes/arrow.tscn`** + **`scripts/arrow.gd`**: arrows shot by archers.
- **`scripts/debug_keys.gd`** (the `DebugKeys` node): testing shortcuts (see below).
- **`scripts/inventory.gd`** (the `Inventory` node): materials, crafted weapons, blaster shots, armour, and whether the furnace is built.
- **`scripts/loot.gd`** + **`scripts/loot_drops.gd`**: loot that pops out of defeated dummies, and the drop rolls.
- **`scripts/crafting_menu.gd`**: the crafting menu (built in code, shown by the HUD).
- **`scripts/knight_weapons.gd`** (the `Weapons` node on the knight): hotbar, every weapon's attack, the hammer's slam and spin.
- **`scripts/weapon_models.gd`**, **`scripts/blaster_round.gd`**, **`scripts/effects.gd`**: weapon models in the knight's hand, the blaster's exploding round, and blast effects.
- **`scripts/mini_bosses.gd`**: the 19 mini bosses: names, colours, headgear and stats. Mini bosses use the dummy scene and script, made bigger and tougher.
- **`scripts/world_time.gd`**: the time mechanic (autoload, reachable from any script as `WorldTime`). See below.
- **`scenes/swinging_log.tscn`** + **`scripts/swinging_log.gd`**: a log on two ropes in front of the start point, for checking that the world slows down.
- **Update 2:** **`scripts/bunker.gd`** (the `Bunker` node), **`scripts/bunker_passage.gd`**, **`scripts/bunker_chest.gd`**: the secret bunker, its entrances and its chest. **`scripts/animals.gd`** (the `Animals` node) + **`scripts/animal.gd`**: wild animals and taming. **`scripts/berry_bush.gd`**: pickable berry bushes. **`scripts/grenade.gd`**, **`scripts/musket_ball.gd`**: thrown grenades and musket balls. **`scripts/thief_arrows.gd`**: the screen-edge arrows pointing to thieving bandits. **`scripts/armor_icon.gd`**: the Cryo armour icon on the HUD.

## Time mechanic

The world nearly freezes (5% speed) when you stand still. Holding a move key ramps time up in steps: 5% → 15% → 25% → … → 100%, one step every 0.3 seconds. A quick tap barely moves time; holding W keeps speeding it up. Let go and it steps back down toward 5%. Throwing or grabbing a knife gives a short bump.

- **What ramps time:** holding WASD / the arrow keys, or holding the joystick. Camera look does **not** ramp time (so you can stop and look around), but `look_counts_as_moving` turns that back on.
- **What slows down:** everything on Godot's normal clock. That's physics, `delta` in `_process`/`_physics_process`, animations, tweens, timers, and sound speed. It works through `Engine.time_scale`, so new things follow world time without extra code. Particles aren't in the game yet: check they slow down too when the first ones are added, and if not, set their speed from `WorldTime.speed`.
- **What stays in real time:** the camera look, the first/third-person glide, and the HUD.
- **Dummies, knives and ragdolls** all run on world time: walking, swing wind-ups, the knife's flight and spin, ragdoll physics, getting back up, and posters regrowing knives.

**Tuning:** all the numbers are at the top of `scripts/world_time.gd`:

| Setting | Default | What it does |
| --- | --- | --- |
| `slow_speed` | `0.05` | World speed when standing still (0.05 = 5%) |
| `step_size` | `0.1` | How much each ramp step adds while a move key is held (+10%) |
| `step_interval` | `0.3` | Real seconds between ramp steps |
| `drop_step_size` | `0.1` | How much each step takes away after letting go |
| `drop_step_interval` | `0.1` | Real seconds between steps back down |
| `bump_speed` | `0.6` | Speed during a throw/grab bump (never lowers the current speed) |
| `bump_time` | `0.4` | Real seconds a bump lasts |
| `look_counts_as_moving` | `false` | Let camera look ramp time too |
| `enabled` | `true` | Set to `false` to turn the mechanic off |

The "World time" readout in the top-left corner shows the current speed. Turn it off with **Show World Time** on the `HUD` node.

## The castle

- The knight's castle stands at the south edge of the forest: stone walls around a square courtyard, a tower at each corner, battlements, green-and-gold banners, and a wide gate facing the middle of the forest. The gate has no door or lintel, so everyone can walk through it, even the big boss.
- The knight starts each game in the courtyard, facing the gate.
- Walls and towers block the knight, enemies and soldiers, and the third-person camera stops at them instead of passing through.
- No trees, rocks or bushes grow on the castle grounds or on the lane from the gate to the clearing. Wanted posters stay on forest trees.
- Enemies never attack the castle, and they never spawn near it: only out in the forest.
- Between waves (and before wave 1) the army stands around in the courtyard.
- Sizes and spots are in `scripts/game_config.gd` (`CASTLE_*`, `KNIGHT_START`).

## The furnace

- A see-through blue **hologram** of the furnace pulses in the courtyard's back-right corner, labelled "Furnace: 10 stone".
- Walk up to it: **[E] Build furnace (10 stone)**, or **Need 10 stone (you have X)** if you're short. Building takes exactly 10 stone and turns the hologram into a solid furnace with a puff of dust. It stays for the rest of the game.
- At the built furnace, **[E] Smelt** opens the furnace panel: your coal, raw iron and iron, with **Smelt 1** (1 coal + 1 raw iron makes 1 iron) and **Smelt all** (as many as the smaller of the two). Both grey out without at least 1 of each. Each smelt makes the fire flare up. **Close (E)**, or Esc, closes it.
- Smelting follows the crafting rules: before wave 1 and during breaks, never during a wave, and not at all from wave 15 on. Trying at the wrong time says why.
- On touch screens the Grab button reads BUILD or SMELT at the furnace.

## Waves

- **Mini boss hits** do 15 + 1 per wave (E-4).
- **Wave n** sends in 2 × n dummies from spawn points around the forest edge, a few at a time.
- When they're all down, **that wave's mini boss** appears, with a health bar at the top of the screen. Its health is 300 + 100 × (wave − 1), so 2,100 at wave 19. Mini bosses are bigger, hit harder, wear headgear, and only flinch when hit until they fall apart.
- Beating the mini boss ends the wave. Then comes a **break** with a countdown: 30 seconds after wave 1, growing evenly to 60 seconds after wave 14. From wave 15 on there's no break: the next wave starts straight away.
- **Wanted posters** show the current (or next) wave's mini boss: a little portrait, its name and its wave.
- **Wave 20 is the final battle**: 40 dummies, **10 of the earlier mini bosses** (picked at random, each with the health it had in its own wave) and **the big boss**, The Grand Effigy. They arrive in 4 groups so nothing lags: the next group comes once only a few are left standing, or after 45 seconds. The big boss comes with the last group. The wave 20 posters show him.
- **The big boss** has 4,000 health and a big health bar across the top. He only goes for the knight. He has two attacks, each with a warning: a heavy two-armed **swing** (his arms rise slowly first) and a **ground stomp** (a red ring grows on the ground, then everyone inside is hurt and knocked back). He never staggers. The Ultra blaster does exactly 1,000 to him, so **4 blaster hits** finish him. The Cryo dagger freezes his head; the next dagger hit does 400 instead of shattering it.
- **The whole army** marches out of the gate when wave 20 starts: every soldier still alive. Those who died earlier stay gone.
- **Winning:** when every enemy in wave 20 is down, time slows as the last one falls, the camera pans over to the castle where the surviving soldiers cheer in front of the gate, and then the victory screen shows "The castle is safe!" with your time, enemies defeated, mini bosses defeated and soldiers who survived, plus **Play Again** and **Quit** (Quit is hidden in the web build). Dying in wave 20 shows the normal game-over screen.
- Breaks count down in **world time**, like everything else. Standing still stretches a break out, so walk around to make it pass. To count breaks in real seconds instead, untick **Breaks Use World Time** on the `WaveManager` node.
- Defeated dummies' pieces shrink away after 10 seconds of world time (`debris_lifetime` on the dummy), so big waves don't pile up.

**Testing later waves:**

- Select the `WaveManager` node in `forest.tscn` and set **Start Wave** in the Inspector (1 to 20). The game then begins at that wave.
- Or use the testing shortcuts below (F2, F3, F6).

## The army

- The army starts with **25 soldiers** (`ARMY_SIZE`), split evenly: archers, spearmen and sword fighters. All wear bright blue tabards with gold trim.
- Between waves the army stands in the castle courtyard.
- In waves 1 to 19, the first time the knight drops to **half health**, **4 soldiers** (`RESCUE_COUNT`) run out of the castle gate to help. If he's more than 20 m from the gate they appear near him instead, so they arrive in time. Only one rescue per wave.
- In **wave 20**, every soldier still alive marches out to fight.
- **Archers** keep 8 to 14 m from their target and shoot arrows. **Spearmen** and **sword fighters** close in. Soldiers can't hurt the knight, and his knives fly through them.
- Dummies attack whoever is nearest, the knight or a soldier. A soldier who dies is **gone for the rest of the run**.
- When the wave is cleared, survivors go back to the courtyard.
- Soldiers more than 25 m from the knight think less often and skip their walk animation.
- The counter in the top-left shows how many are left, by role.

## Loot and crafting

- **Loot:** each regular enemy drops 1 or 2 random materials (wood, stone, raw iron, coal, gunpowder, string, meat; string and meat are the rarest, gunpowder is as common as coal). Each mini boss drops 1 Cryo Crystal plus 3 random materials, with a 1 in 20 chance of an Ultra Crystal. Loot pops out of the body; walk over it to pick it up. What you carry shows under the health bar.
- **Crafting** opens with **C** (Craft button on touch) before wave 1 and during the breaks after waves 1 to 14. "Press C to craft" shows at the top while it's open.
- **Iron** comes from the furnace in the castle (see **The furnace**), not from the crafting menu.
- **Berries** are picked from the red berry bushes around the forest (E / Pick). A picked bush grows its berries back when a wave is cleared. Meat and berries are for taming (see **Animals and taming**).
- **Diamond and titanium** are only in the bunker chest (see **The secret bunker**). Enemies never drop them.
- **Weapons** go on the hotbar at the bottom (knives are always slot 1). Melee weapons, the bow and the musket never break. The Ultra blaster runs out (3 shots per crafted blaster) and grenades are used up (one per craft).

| Weapon | Damage | Recipe | What it does |
| --- | --- | --- | --- |
| Throwing knife | 50 | From posters | Thrown, picked up again |
| Spear | 60 | 3 wood + 2 stone | Long reach (3.2 m) |
| Sword | 50 | 3 iron + 1 wood | Fast swings |
| Axe | 75 | 3 iron + 2 wood | Slow, heavy swings that hit everyone in front |
| Bow | 40 | 3 wood + 2 string | Unlimited arrows |
| Cryo dagger | 30 | 1 Cryo + 2 stone + 1 string | A slash freezes the head; the next dagger hit shatters it. That defeats a regular dummy outright; a mini boss takes 300 instead |
| Cryo hammer | 100 | 2 Cryo + 3 iron | Slowest. Right click: ground slam, once per wave: 150 damage within 6 m, survivors frozen for 3 s, weakened dummies (under half health) shatter. F: spin, 50 damage within 3 m, 5 s cooldown |
| Ultra blaster | 1,000 | 1 Ultra Crystal | Lobs exploding rounds that hit everything in the blast. One hit defeats any dummy or mini boss; the big boss takes exactly 1,000 (4 hits). 3 shots, then it breaks |
| Dagger | 20 | 1 stone + 1 wood | Very fast stabs |
| Bat | 10 | 2 wood | Knocks enemies far back |
| Grenade | One-shots regular enemies | 2 gunpowder + 1 iron | Thrown in an arc, explodes on impact. Every regular enemy in the blast is destroyed; a mini boss loses 1 / (wave × 2) of its health (wave 10's takes 20 grenades), the big boss 1 / 40. Never hurts the knight, soldiers or tamed animals. Used up |
| Diamond sword | 65 | 3 diamond + 1 wood | Fast swings. Crits |
| Diamond axe | 85 | 3 diamond + 2 wood | Slow, hits everyone in front. Crits |
| Diamond dagger | 25 | 2 diamond + 1 wood | Very fast. Crits |
| Musket | 90 | 3 titanium + 4 gunpowder | Fires a heavy ball at the crosshair. Unlimited shots; 3 s reload counted in real time, so it reloads at full speed in slow motion (a bar shows under the crosshair). Crits |
| Cryo armour | — | 3 iron + 3 stone + 2 Cryo | Has its own section at the top of the crafting menu. Reflects 25% of melee damage back and slows the attacker by half for 1 s. The knight wears icy blue armour pieces with a frost glow, the eye slit frosts over in first person, and the HUD shows an armour icon |

- **Critical hits:** the musket and the three diamond weapons have a 1 in 12 chance per hit of double damage, with a golden flash and a "CRIT!" pop-up. No other weapon crits.
- The bunker only has 6 diamonds, enough for two of the three diamond weapons, never all three.

- The knight's **health refills** when a wave is cleared.
- Every number above (damage, ranges, cooldowns, recipes, drop rates) is in `scripts/game_config.gd`.

## The secret bunker

- Two hidden entrances lead to the same torch-lit room under the forest: a trapdoor at the edge of the clearing, half hidden under bushes and leaves ("[E] Open trapdoor"), and a loose stone on the inside of the castle's left wall ("[E] Push stone"). The prompts only show up close.
- Inside, "[E] Climb up" by the ladder goes back to the trapdoor, and "[E] Climb up" by the stairs goes to the castle. Going through fades the screen; it works any time, during breaks or waves, as often as you like.
- The chest holds 6 diamonds and 3 titanium. "[E] Open chest" takes everything at once. It never refills during a run; Try Again refills it.
- Enemies don't follow the knight down. While he's inside during a wave, the wave waits (no new enemies walk in). Breaks still count down. Tamed animals come along.
- The room really sits far outside the forest (`BUNKER_CENTER` in `game_config.gd`), so nothing outside can see or reach it.

## Enemies: looks and bandits

- Regular enemies come in four looks, mixed in every wave: **bandits** (hood, face mask, patched clothes, a sack), **archers** (leather armour, quiver, bow in hand), **swordsmen** (chainmail, helmet, sword and shield) and **riders** on a horse. They all fight exactly like the version 1 dummies. A knocked-down rider climbs back on its horse; a beaten rider's horse gallops off. Mini bosses and the big boss look the same as before.
- **Bandits steal:** the first time one touches the knight it takes 5 random materials (never weapons; fewer if he has fewer, and it just attacks if he has none), with a red "Stolen!" warning listing them. It then runs for the nearest map edge, a little faster than normal. Its sack glows, it gets a red THIEF marker, and red arrows at the screen edge point to it when it's off screen.
- Kill it to get everything back as loot. If it reaches the edge, "The bandit escaped!" and the materials are gone for good. One theft per bandit. The wave only ends when every enemy, running bandits included, is dead or gone.

## Animals and taming

- Wild bears, wolves, deer and bunnies roam the forest. They're peaceful. Hit a bear or a wolf and it chases you for a while; deer and bunnies run. A killed wild animal drops meat.
- **Taming:** walk up holding the right food and press E / Tame: meat for bears and wolves, berries for deer and bunnies. Each tame uses 1 food. You can keep 2 at a time; taming a third asks which one to let go.
- Tamed animals wear a green collar, follow you and attack enemies near you. Bear 300 health / 90 damage, wolf 150 / 50 (fast), deer 120 / 20 (charges), bunny 50 / 5 (very fast). Who's with you shows under the health bar.
- A tamed animal that falls comes back next to you when the wave ends. They fight in the wave 20 battle too. A new game starts with none.

## Testing shortcuts

These work when running from the editor (debug builds only):

| Key | What it does |
| --- | --- |
| F2 | Skip to the next wave straight away (in wave 20, win straight away) |
| F3 | End a break early, remove this wave's dummies so the mini boss comes out, or in wave 20 send the next group |
| F4 | Drop the knight to half health (during waves 1 to 19 this brings in the army) |
| F6 | Jump straight to wave 20, the final battle |
| F7 | Get 20 stone, 10 coal, 10 raw iron and 2 Cryo Crystals (to test the furnace, then the Cryo armour) |
| F8 | Get a pile of everything: 10 of each regular material, 10 gunpowder, 5 iron, 4 Cryo Crystals, 1 Ultra Crystal, 3 meat, 3 berries |
| F9 | Let crafting and smelting open at any time (press again to turn off) |
| F10 | Get the bunker chest's haul (6 diamonds, 3 titanium) without going down, to test the diamond weapons and the musket |

You can also start at a later wave: select the `WaveManager` node in `forest.tscn` and set **Start Wave**.

## The look

- **One toon shader** (`shaders/toon.gdshader`) on everything solid: 3 light bands (2 on Low), shadows tinted blue-green (never black), and a soft rim light on characters. Its settings (`TOON_*`) and the one shared **palette** (`PALETTE`) are in `game_config.gd`.
- **World** (`scenes/world_look.tscn`): a soft teal sky gradient, matching distance fog, gentle sky ambient light, and a light colour grade (warm highlights, teal shadows).
- **Forest**: leafy trees with 2 or 3 leaf clumps in different greens, stacked-cone pines, berry bushes, rocks, flowers, sandy paths, and about 9,000 grass blades. Grass and leaves sway in the wind, which follows world time. No grass in the castle, on the paths or in the clearing.
- **Effects** (`scripts/fx.gd`): dust when running and landing, hit sparks and a white flash on enemies, frost on frozen enemies, an icy ring for the hammer slam, an ice burst when a frozen head shatters, the blaster's glowing trail and explosion, furnace sparks, and leaves drifting in the air. All are CPU particles, so they slow down with world time.
- **UI**: dark wood panels, rounded corners and a gold accent everywhere, one font.

## Graphics settings

Pick **Low**, **Medium** or **High** from the pause menu (Esc, or the pause icon on touch) or the title screen's Settings. It applies straight away and is saved (`user://settings.cfg`). The first launch picks Low on phones and touch devices, High on PC. Each level's numbers are in `GRAPHICS_LEVELS` in `game_config.gd`.

| | Low | Medium | High |
| --- | --- | --- | --- |
| Shadows | Off | Knight and bosses | Everything |
| Render resolution | 60% | 80% | 100% |
| View distance | 38 m | 55 m | 80 m |
| Grass | Off | Half, gentle sway | Full |
| Leaf sway | Off | On | On |
| Toon shading | 2 bands, no rim | Full | Full |
| Colour grade | Off (fog only) | On | On |
| Particles | 35% | 65% | Full |
| Floating leaves | None | 12 | 30 |
| Defeated enemies' pieces kept | 3 | 8 | 20 |

Debug builds show an FPS counter in the bottom-left corner.

## Performance

- **F-1 culling**: the forest is drawn in 24 m chunks, so chunks off screen aren't drawn and far ones are cut off at the view distance. The castle walls are occluders, so whatever is behind them isn't drawn. (Occlusion culling only works on PC; the web build relies on chunking and view distance instead.)
- **F-2 level of detail**: dummies, soldiers and mini bosses lose their small details (eyes, trims, straw) beyond 22 m. The knight and the big boss always keep full detail.
- **F-3 fading**: trees, rocks, bushes, flowers and grass dissolve out near the view distance.
- **F-4 far-away AI**: enemies more than 30 m away think every 4th physics frame (catching up on the time they skipped, so they still follow world time). Soldiers far away think less often and skip animation.
- **Ragdoll pieces**: only the newest few defeated enemies' pieces stay on the ground (per graphics level); the oldest are cleared first.
- **Pooling**: knives, arrows, loot and particle effects are reused instead of made and thrown away. Enemies aren't pooled: their cost is the ragdoll, which is rebuilt each time anyway; the ragdoll cap keeps that in check.

## Releasing

**Export everything** (with Godot 4.7.2 and its export templates installed):

```bash
tools/export_all.sh /path/to/Godot_v4.7.2-stable
```

This writes `builds/windows/`, `builds/linux/` and `builds/web/`, plus `KnightOfTheWoods-windows.zip`, `-linux.zip` and `-web.zip` in `builds/` (ignored by git).

**Upload the web build to itch.io:**

1. On itch.io, go to **Dashboard → Create new project**.
2. Set **Kind of project** to **HTML**.
3. Under **Uploads**, upload `builds/KnightOfTheWoods-web.zip` and tick **This file will be played in the browser**.
4. Under **Embed options**, pick **Click to launch in fullscreen** (best on phones), or set a viewport size of 1280 × 720 and tick **Fullscreen button**.
5. Leave **SharedArrayBuffer support** **unticked**: the web build is exported without threads, so it doesn't need it (and works in iPhone Safari).
6. Tick **Mobile friendly** and set the orientation to **Landscape**.
7. Save, open the page on the iPhone in Safari, and tap to start.

**Share the PC build:** send `KnightOfTheWoods-windows.zip` (or `-linux.zip`). Players unzip it and double-click the game; no Godot needed. Windows may warn about an unknown publisher the first time: "More info → Run anyway".

## Physics layers

| Layer | Name | Used by |
| --- | --- | --- |
| 1 | world | Ground, trees, rocks, the swinging log |
| 2 | player | The knight |
| 3 | boundary | The invisible wall at the forest edge (stops the knight and dummies, not knives) |
| 4 | dummies | Walking enemies, and wild animals (so knives, arrows and musket balls hit them) |
| 5 | debris | Ragdoll pieces (knives hit them; the knight walks through them) |
| 6 | allies | Soldiers and tamed animals (dummies bump into them; knives and arrows fly through) |

## Install export templates first

Godot can't export anything until its export templates are installed. You only need to do this once per Godot version:

1. In the editor, open **Editor → Manage Export Templates**.
2. Click **Download and Install**. Wait for it to finish.

The templates must match your editor version exactly (for example 4.7.2 templates for the 4.7.2 editor).

## Export the builds

Both presets are already set up in `export_presets.cfg`. In the editor, open **Project → Export**, choose a preset, and click **Export Project** (untick **Export With Debug** for a release build).

### Windows Desktop

- Exports to `builds/windows/KnightOfTheWoods.exe`.
- The game data is embedded in the `.exe`, so you can send just that one file. Players don't need Godot installed.

From the command line (replace `godot` with the path to your Godot executable):

```bash
godot --headless --export-release "Windows Desktop" builds/windows/KnightOfTheWoods.exe
```

### Web (itch.io and iPhone Safari)

- Exports to `builds/web/index.html`, plus the `.js`, `.wasm` and `.pck` files next to it.
- **Thread support is off**, so the build works on iPhone Safari and on itch.io without special server headers.

From the command line:

```bash
godot --headless --export-release "Web" builds/web/index.html
```

To test it:

- **On your PC:** in the editor, click the **Remote Deploy** button (top right) and pick the Web preset. Godot starts a local server and opens the game in your browser. Opening `index.html` straight from the file system won't work.
- **On itch.io / iPhone:** zip the *contents* of `builds/web/` (so `index.html` sits at the top of the zip). On itch.io, create a project with kind **HTML**, upload the zip, and tick **This file will be played in the browser**. Leave **SharedArrayBuffer support** off. Then open the itch.io link in Safari on the iPhone.
