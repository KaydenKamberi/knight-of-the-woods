# Knight of the Still Woods — PRD

Nov 6, 2026 · @Kayden

## Sebas's version: the game in plain words

**What is it?** You're a knight. Your castle is hidden deep in a forest, and enemies are coming to attack it. You have to stop them.

**The big trick:** Time only moves when you move. Stand still and everything almost freezes, so you can stop and plan your next move.

**Your weapon:** Wanted posters are nailed to the trees with knives stuck through them. Pull a knife out and throw it at the enemies. The enemies are floppy dummies that tumble and fall apart when you hit them.

**The waves:**

1. Wave 1 has 2 enemies. Every wave adds 2 more.
2. At the end of every wave, a mini boss shows up. The wanted posters show who it is.
3. Wave 20 is the big one: a giant boss and 10 mini bosses attack your castle gates.
4. Beat the giant boss and you win the game!

**Your army:** You have 20 to 30 soldiers with bows, spears and swords. If your health drops to half, some of them run in to save you. If a soldier dies, he's gone forever. In wave 20, everyone who's still alive fights with you, so protect them!

**Crafting:** Loot materials from the dummies you beat: wood, stone, raw iron, coal, rare glowing Cryo Crystals, and super rare Ultra Crystals. Smelt raw iron into iron in a furnace you build. Between waves you get a break to craft new weapons, and the break gets longer as the waves get harder. From wave 15 on, there's no more crafting, so you fight with whatever you've made!

**Seeing the game:** Press a button to switch between looking from behind your knight and looking through his helmet.

**Where you can play:** On a computer, or on your iPhone from a link. A "potato mode" setting makes it run smoothly on slower phones.

**Questions for you, Sebas:** What's the game called? What do the bosses look like? The full list is at the bottom of this doc.

## Technical spec (for Claude Code)

Everything below is the detailed spec. Each rule has a code like T-1 so a task can point to it, and the Milestones section gives the build order.

## Overview

Knight of the Still Woods is a 3D wave-survival action game where time only moves when you move. You play a knight defending a castle hidden deep in a forest. You pull throwing knives out of wanted posters nailed to the trees and hurl them at floppy ragdoll enemies.

It borrows two ideas and makes them its own: the time mechanic from Superhot, and physics-driven ragdoll enemies like Bonelab's. The characters, art and setting are all original.

- **Game idea and design:** Sebas
- **Spec and code:** Kayden and Claude
- **Engine:** Godot 4
- **Platforms:** PC, plus iPhone through a web export
- **Working title:** "Knight of the Still Woods", until Sebas picks a name

## Goals and non-goals

Version 1 is done when a player can start at wave 1, fight through all 20 waves, and win the final castle battle, on both PC and an iPhone browser.

**Goals**

- The time-moves-when-you-move mechanic feels good and runs smoothly
- Throwing knives are fun: grab, throw, and hit, with satisfying ragdoll reactions
- 20 waves, a mini boss at the end of each, and a big final battle
- The army rescue mechanic, where fallen soldiers are gone for good
- Playable on a low-end iPhone with the Low graphics setting

**Non-goals for version 1**

- Multiplayer
- Native App Store iPhone app (needs a Mac and a paid Apple developer account)
- Story cutscenes, voice acting, or a level editor
- Multiple save slots

## Core mechanic: time and camera

Time runs at full speed while the player moves or acts, and slows to a crawl when they stand still. Every fight becomes a puzzle you can stop and think through.

**Time rules**

- **T-1:** Standing still sets world time to a near-freeze (starting value 5% speed, tunable).
- **T-2:** Holding a move key ramps time up gradually, about +10% per step, so a short tap barely moves time and holding W keeps speeding it up toward 100%. Letting go drops it back toward the near-freeze. Throwing or swinging gives a short time bump. Ramp step size and speed are tunable.
- **T-3:** Everything obeys world time: enemies, arrows, thrown knives, ragdolls, particles and sounds.
- **T-4:** The player's own camera look stays responsive even while time is slow.

**Camera**

- **C-1:** Third person, behind the knight, is the default.
- **C-2:** First person shows the view from inside the knight's helmet, with the edges of the eye slit framing the screen.
- **C-3:** One button switches views: a key on PC, a camera icon on mobile.
  - **C-4:** The third-person camera sits over the knight's shoulder, offset to the side and slightly up, so the aim reticle never sits on the knight's head. A shift-lock style toggle locks the cursor to the center and the knight turns with the camera.

## Combat and weapons

The signature weapon is the throwing knife, pulled from wanted posters nailed to the trees. The knife is always available; every other weapon is crafted (see Crafting).

**Wanted-poster knives**

- **W-1:** Wanted posters are pinned to trees with a knife stuck through them, spread around the forest.
- **W-2:** Walking up to a poster and pressing interact pulls the knife out.
- **W-3:** The player can throw a held knife where they aim. It spins through the air, slowed with world time.
- **W-4:** A thrown knife sticks in what it hits and can be picked up again.
  - **W-6:** After a knife is taken, a new knife respawns in its poster after a short delay (tunable).
- **W-5:** Each poster shows the mini boss for the current wave, so the posters double as the target to hunt.

**Enemies and hits**

- **E-1:** Regular enemies are floppy ragdoll dummies, original designs.
- **E-2:** A hit knocks the dummy into ragdoll physics; a defeated dummy tumbles and falls apart.
- **E-3:** The player has a health bar. Enemy hits lower it, and reaching zero ends the run.

* **E-4:** Starting values (tunable): player health 100; a dummy hit does 10 damage, a mini boss hit 15 plus 1 per wave, and a big boss hit 30. Player health refills to full when a wave ends.

## Waves and bosses

There are 20 waves. Each one adds two more dummies and ends with a mini boss. Wave 20 is a big boss battle at the castle gates.

- **V-1:** Wave *n* spawns 2 × *n* dummies: 2 in wave 1, 4 in wave 2, and so on up to 38 in wave 19.
- **V-2:** When every dummy in a wave is down, that wave's mini boss appears. Beating it starts the next wave.
- **V-3:** Each wave has its own mini boss, 20 in total, each one stronger than the last.
- **V-4:** Wave 20 takes place at the castle gates. The big boss attacks with half of the mini bosses (10) from earlier waves. Default: no regular dummies in wave 20, only the bosses, unless Sebas changes it.
- **V-5:** Beating the big boss wins the game.
- **V-6:** Between waves 1 and 14, a crafting break lets the player pick up knives and craft (see Crafting).

* **V-7:** Mini boss health starts at 300 in wave 1 and goes up by 100 each wave, so the wave 19 mini boss has 2,100.
* **V-8:** The big boss has 4,000 health, so 4 Ultra blaster hits (1,000 each) defeat it.

| Wave | Dummies | Then |
| --- | --- | --- |
| 1 | 2 | Mini boss 1 |
| 5 | 10 | Mini boss 5 |
| 10 | 20 | Mini boss 10 |
| 19 | 38 | Mini boss 19 |
| 20 | 0 (bosses only) | Big boss + 10 mini bosses at the castle |

## The army

The knight has an army of 20 to 30 soldiers, and any soldier who dies is gone for good. Playing badly in early waves means a smaller army in the final battle.

- **A-1:** The army starts at 25 soldiers (tunable, 20 to 30), split roughly evenly among archers (bows and arrows), spearmen and sword fighters.
- **A-2:** When the player drops to half health in any wave, 4 soldiers (tunable) from the remaining army run in to help. Only one rescue per wave; survivors rejoin the army when the wave ends.
- **A-3:** A soldier who dies is removed from the army permanently for the rest of the run.
- **A-4:** In the wave 20 battle, every surviving soldier fights alongside the player.
- **A-5:** The screen shows how many soldiers are left.
- **A-6:** Soldiers are AI-controlled. Archers keep their distance, spearmen and sword fighters close in.

## Crafting

Players loot materials from defeated dummies and craft weapons during breaks between waves. Crafting stops from wave 15 on.

- **R-1:** There are seven materials: wood, stone, iron (dropped as raw iron), coal, string, Cryo Crystal (rare, glowing icy blue) and Ultra Crystal (super rare).
- **R-2:** Defeated dummies drop materials to loot. Iron drops as raw iron, which the player smelts into usable iron in a furnace they craft. The furnace is built from a large amount of stone and burns coal, which enemies also drop. Cryo Crystals come from mini bosses.
- **R-3:** After each of waves 1 to 14 there is a crafting break: 30 seconds after wave 1, scaling evenly up to 60 seconds after wave 14. A countdown shows on screen.
- **R-4:** No crafting breaks from wave 15 through wave 20. Waves run back to back.
- **R-5:** During a break the player opens a crafting menu, spends materials, and gets new weapons.
- **R-6:** The Cryo Crystal hammer has a ground-slam attack: hitting the ground sets off a big icy explosion that freezes some nearby enemies and kills others. The slam can be used once per wave. Starting values (tunable): about 6 m radius, 150 damage to every enemy inside, survivors frozen for 3 seconds, and regular dummies already under half health shatter instantly.

* **R-7:** Craftable weapons: spear, axe, sword, bow and arrows, Cryo Crystal dagger, and Cryo Crystal hammer. Recipes: spear = wood + stone; sword = iron + wood; axe = iron + wood; bow = wood + string. Some enemies drop string as loot. Cryo hammer = 2 Cryo Crystals + iron (for the handle); Cryo dagger = 1 Cryo Crystal + stone + string. Exact amounts are in the Weapon stats table.

- **R-8:** Cryo Crystal dagger: a slash freezes the enemy's head in ice. Hitting the frozen head again shatters it and defeats the enemy.

* **R-9:** Cryo Crystal hammer also has a spinning attack that hits every enemy around the player.
* **R-10:** Cryo armor is a craftable item that works like a thorns effect: any enemy that hits the player in melee takes damage back and is briefly frosted, slowing it for about a second. Recipe for the whole set: iron + stone + 2 Cryo Crystals (starting amounts: 3 iron + 3 stone + 2 Cryo Crystals). It reflects 25% of the melee damage taken back to the attacker and slows it by 50% for 1 second.

- **R-11:** Ultra Crystal is the super rare material. Each mini boss has about a 1 in 20 (5%) chance to drop one.
- **R-12:** The Ultra Crystal weapon is crafted from one Ultra Crystal and has only 3 uses, then breaks. Four hits from it defeat the big boss, so a player needs two of these weapons to beat the boss with it alone. It works like a grenade launcher: each of its 3 shots lobs a round that explodes where it lands, hitting every enemy in the blast area.

* **R-13:** Drops (tunable): each regular dummy drops 1 to 2 random materials from wood, stone, raw iron, coal and string (string is the least common). Each mini boss always drops 1 Cryo Crystal plus 3 random regular materials, and has the 1 in 20 Ultra Crystal chance. Loot pops out of the body; walking over it picks it up.
* **R-14:** Furnace: built once from the crafting menu for 15 stone and placed in the forest clearing. Once built, the crafting menu gains Smelt: 1 raw iron + 1 coal makes 1 iron.
* **R-15:** Inventory: crafted weapons go on a hotbar. Melee weapons and the bow never break; only the Ultra blaster has limited uses. The player carries up to 3 throwing knives (tunable).
* **R-16:** Cryo hammer spin: hits every enemy within about 3 m for 50 damage each, with a 5-second cooldown (tunable).
* **R-17:** Ultra blaster does 1,000 damage per hit, which defeats any regular dummy or mini boss in one hit.

**Weapon stats** (a regular dummy has 100 health; values are a starting point to tune)

| Weapon | Damage | Style | Recipe |
| --- | --- | --- | --- |
| Throwing knife | 50 | Thrown, picked up again | Pulled from wanted posters |
| Spear | 60 | Long reach, hits before enemies get close | 3 wood + 2 stone |
| Sword | 50 | Fast swings | 3 iron + 1 wood |
| Axe | 75 | Slower, heavy swings | 3 iron + 2 wood |
| Bow and arrows | 40 | Ranged | 3 wood + 2 string (unlimited arrows) |
| Cryo dagger | 30 | Slash freezes the head; next hit shatters it | 1 Cryo Crystal + 2 stone + 1 string |
| Cryo hammer | 100 | Slowest; spin does 50 per hit; ground slam once per wave | 2 Cryo Crystals + 3 iron |
| Ultra blaster | 1,000 per hit (big boss dies in 4) | Grenade-style exploding shots, 3 uses | 1 Ultra Crystal |

## World and art style

The game is set in a low-poly forest with sunlight through the trees and the knight's castle hidden deep inside. Low-poly keeps big battles fast on phones.

- **S-1:** The forest is the arena for waves 1 to 19, with wanted-poster trees spread through it.
- **S-2:** The castle and its gates are the arena for wave 20.
- **S-3:** All characters are low-poly: the knight, the dummies, the mini bosses, the big boss and the army.
- **S-4:** Assets either come from free CC0 packs (Kenney, Quaternius, Poly Pizza) or are made in code by Claude. Packs are downloaded by Kayden and added to the repo, because Claude can't fetch them directly.
- **S-5:** No characters, art or names from Superhot, Bonelab or other existing games.

## Platforms, performance and graphics

The game exports as a downloadable PC build and as a web build hosted on itch.io, which is how Sebas plays it on his iPhone. Performance work is built in from the start, not added later.

**Platforms**

- **P-1:** PC export for Windows and Linux, sent to players as a standalone build. No Godot install needed.
- **P-2:** Web export hosted on itch.io, playable in iPhone Safari from a link.
- **P-3:** The project uses Godot's Compatibility renderer, which the web export requires.

**Performance**

- **F-1:** Anything off screen or hidden behind trees isn't drawn (occlusion and frustum culling).
- **F-2:** Faraway characters swap to simpler models (level of detail).
- **F-3:** Faraway trees, grass and leaves fade out.
- **F-4:** Distant enemies and soldiers run simpler AI that updates less often.
- **F-5:** Target is a steady 30 fps on iPhone at Low during the wave 20 battle, and 60 fps on PC at High.

**Graphics settings**

| Setting | Low (potato) | Medium | High |
| --- | --- | --- | --- |
| Shadows | Off | Knight and bosses only | All characters and trees |
| Render resolution | 60% | 80% | 100% |
| View distance | Short | Medium | Long |
| Grass and leaves | Off | Reduced | Full |
| Ragdoll pieces kept | Few, cleared quickly | Some | Many |

## Controls

PC uses keyboard and mouse. Mobile uses on-screen touch controls, which only appear on touch devices.

| Action | PC | Mobile |
| --- | --- | --- |
| Move | WASD | Left virtual joystick |
| Look and aim | Mouse | Drag on the right half of the screen |
| Attack, throw or shoot | Left click | Attack button |
| Hammer ground slam | Right click | Slam button (hammer only) |
| Hammer spin | F | Spin button (hammer only) |
| Grab knife or pick up | E | Grab button (appears when near) |
| Switch weapon | 1 to 9 or mouse wheel | Weapon button (cycles) |
| Shift-lock aim | Left Shift | Lock icon |
| Switch camera view | V | Camera icon |
| Crafting menu (breaks only) | C | Craft button |
| Pause and settings | Esc | Pause icon |

- **K-1:** Touch controls appear automatically on touch devices and are hidden on PC.
- **K-2:** Moving the joystick or dragging to look counts as moving for the time mechanic (T-2).

## Milestones

Build in this order, one milestone at a time. A milestone is done only when every box under it is ticked, and each one ends with a playable build Sebas can try.

**M0: Setup**

- [x] Godot 4 project in a GitHub repo, Compatibility renderer selected (P-3)
- [x] PC and web export presets work, and a test build opens on PC and in iPhone Safari

**M1: Knight in the forest**

- [x] Knight moves in a small low-poly forest with PC and touch controls (K-1)
- [x] Camera switches between third and first person, over-the-shoulder with shift-lock (C-1 to C-4)

**M2: Time mechanic**

- [x] Time slows when standing still and ramps up gradually when moving (T-1 to T-4)
- [x] A test object, like a swinging log, visibly obeys world time

**M3: Knives and dummies**

- [x] Knives can be pulled from posters, thrown, picked up again, and respawn in posters (W-1 to W-4, W-6)
- [x] Dummies walk at the player, deal damage, and ragdoll when hit (E-1 to E-3)

**M4: Waves and mini bosses**

- [x] Waves 1 to 19 spawn 2 × wave dummies and end with a mini boss (V-1 to V-3, V-6, V-7, R-3, R-4)
- [x] Posters show the current mini boss (W-5)

**M5: The army**

- [ ] Soldiers arrive at half health and permadeath works (A-1 to A-3, A-5, A-6)

**M5.5: Loot and crafting**

- [ ] Dummies and mini bosses drop materials, including raw iron, coal, string, Cryo Crystals and rare Ultra Crystals (R-1, R-2, R-11, R-13)
- [ ] Furnace can be built and smelts raw iron into iron (R-2)
- [ ] Crafting menu works during breaks for every weapon and the Cryo armor, with each weapon's stats and special attacks from the weapon table (R-5 to R-10, R-12, R-14 to R-17, E-4)

**M6: Final battle**

- [ ] Wave 20 at the castle with the big boss, 10 mini bosses and the surviving army, ending in a win screen (V-4, V-5, A-4, S-2)

**M7: Performance and release**

- [ ] Culling, level of detail and simple far-away AI are in (F-1 to F-4)
- [ ] Low, Medium and High settings work from the pause menu, and wave 20 hits the frame-rate targets (F-5)
- [ ] A title screen with Play and Settings, and a game-over screen that restarts at wave 1 with a fresh army
- [ ] Web build is live on itch.io, and a PC build is shared

## Open questions

Each question has a default, so building never has to stop. Sebas can change any of them.

- [ ] What's the game called? Default: "Knight of the Still Woods".
- [ ] Does the knight start with a weapon of his own? Default: knives only, everything else is crafted.
- [ ] What do the mini bosses and the big boss look like? Default: Claude designs a different low-poly look for each.
- [ ] Should wave 20 also have regular dummies? Default: bosses only (V-4).
- [ ] Does losing restart at wave 1? Default: yes, with a fresh army.
- [ ] Are the recipe amounts, drop rates and damage numbers fun? Tune after playtesting M5.5.
