# Knight of the Still Woods — Update 2 PRD

## Sebas's version: what's new in Update 2

**The musket:** A new gun that shoots a big ball. It does 90 damage, has unlimited shots, and takes 3 seconds to reload. The reload keeps going at normal speed even when time is slowed, so you can stand still and reload while you plan. Craft it with 3 titanium and 4 gunpowder.

**New materials:** Gunpowder, diamond and titanium. Enemies drop gunpowder. Diamond and titanium are hidden in a chest in a secret underground bunker. You can get in through a trapdoor in the middle of the forest or a hidden door in the castle wall.

**The secret bunker:** You can go in any time, during breaks or waves, as many times as you want. But the chest only has 6 diamonds and 3 titanium, and they never come back. You get one haul per game, so choose carefully!

**Diamond weapons:** Diamond sword (65 damage, 3 diamonds), diamond axe (85 damage, 3 diamonds) and diamond dagger (25 damage, 2 diamonds). The bunker only has enough diamond for two of them, never all three.

**Critical hits:** The musket and diamond weapons have a 1 in 12 chance to do double damage. A musket crit does 180!

**More new weapons:** A regular dagger (20 damage, stone and wood), a bat (10 damage, just wood), and grenades (gunpowder and iron). Grenades are used up when thrown, and they destroy every regular enemy in the blast. Bosses are tougher: a mini boss takes its wave number times 2 grenades, so the wave 10 mini boss takes 20, and the big boss takes 40.

**New enemies:** The enemies now look like bandits, archers, swordsmen and horseback riders. They fight the same way as before. But watch out for bandits: they can steal 5 of your materials (never weapons) and run for the edge of the map. Kill them to get your stuff back. If they escape, it's gone forever!

**Taming animals:** Tame bears (90 damage), wolves (50), deer (20) and bunnies (5) to fight for you. Feed meat (dropped by enemies) to bears and wolves, and berries (picked from bushes) to bunnies and deer. You can have 2 animals at once. If one dies, it comes back after the wave ends.

**Fixes:** The Cryo armor shows up in the crafting menu, and you can actually see it on your knight.

## Technical spec (for Claude Code)

This builds on the version 1 PRD and the finished game. Every version 1 rule still applies unless this doc changes it. Rule codes continue from version 1, and all numbers are starting values that can be tuned in game\_config.gd.

## Fixes

- **X-1:** Cryo armor appears in the crafting menu with its recipe (3 iron + 3 stone + 2 Cryo Crystals) and can be crafted.
- **X-2:** Wearing Cryo armor visibly changes the knight: icy blue armor pieces with a light frost glow, in both camera views.

## New materials

- **N-1:** Three new materials: gunpowder, diamond and titanium. They show in the HUD and crafting menu like the others.
- **N-2:** Gunpowder drops from regular enemies, about as often as coal.
- **N-3:** Diamond and titanium are only found in the bunker chest (B-3). Enemies never drop them.
- **N-4:** Two taming foods: meat (dropped by enemies) and berries (picked from berry bushes with the grab key; bushes regrow after a wave).

## The secret bunker

- **B-1:** A hidden underground bunker, with two secret entrances: a hidden trapdoor in the middle of the forest, and a hidden door in one of the castle walls. Both lead to the same bunker.
- **B-2:** It can be entered any time, during breaks or waves, as many times as the player wants. Time rules work inside it the same as outside.
- **B-3:** Inside is one chest holding 6 diamonds and 3 titanium. The contents never respawn during a run. Restarting the game refills it.
- **B-4:** The bunker is a small low-poly underground room with torches, in the same art style as the rest of the game.

## New weapons

| Weapon | Damage | Recipe | Notes |
| --- | --- | --- | --- |
| Musket | 90 | 3 titanium + 4 gunpowder | Unlimited shots; 3 s reload at real time |
| Diamond sword | 65 | 3 diamond + 1 wood | Crits |
| Diamond axe | 85 | 3 diamond + 2 wood | Crits |
| Diamond dagger | 25 | 2 diamond + 1 wood | Crits |
| Dagger | 20 | 1 stone + 1 wood |  |
| Bat | 10 | 2 wood |  |
| Grenade | One-shots regular enemies | 2 gunpowder + 1 iron | Used up when thrown |

- **G-1:** The musket fires a heavy ball where the player aims. It never runs out of ammo. After each shot it takes 3 seconds to reload, counted in real time, not world time, so it reloads at full speed while time is slowed. A reload bar shows on screen.
- **G-2:** Critical hits: the musket and the three diamond weapons have a 1 in 12 chance per hit to do double damage, shown with a big flash and a "CRIT!" pop-up. No other weapon can crit.
- **G-3:** Grenades are thrown in an arc and explode on impact. Every regular enemy in the blast dies instantly. Each grenade does 1/(wave × 2) of a mini boss's health, so the wave n mini boss takes 2 × n grenades, and the big boss takes 40. Grenades never hurt the player, soldiers or tamed animals.
- **G-4:** All new weapons go on the hotbar, follow world time (except the musket reload), and follow the crafting break rules (no crafting from wave 15 on).

## New enemy looks and bandits

- **D-1:** Regular enemies get four new looks: bandits, archers, swordsmen and horseback riders. Each wave mixes all four. Apart from bandits, they behave and fight exactly like the version 1 dummies.
- **D-2:** Bandits can steal. When a bandit touches the player, it takes 5 random materials (never weapons), shows a "Stolen!" warning, then runs for the nearest map edge.
- **D-3:** A thieving bandit carries a sack and is marked on screen. Killing it drops everything it stole.
- **D-4:** If it reaches the map border, it disappears and the materials are gone for good.
- **D-5:** Only one theft per bandit.

## Taming animals

- **H-1:** Wild bears, wolves, bunnies and deer roam the forest. They're peaceful until tamed (bears and wolves fight back if attacked).
- **H-2:** To tame one, walk up holding the right food and press grab: meat for bears and wolves, berries for bunnies and deer. Each tame uses 1 food.
- **H-3:** The player can have up to 2 tamed animals at once. Taming a third asks which one to release.
- **H-4:** Tamed animals follow the player and attack enemies. Starting stats: bear 300 health, 90 damage; wolf 150 health, 50 damage, fast; deer 120 health, 20 damage (charges); bunny 50 health, 5 damage, very fast. Health values are starting guesses to tune.
- **H-5:** A tamed animal that dies comes back next to the player when the wave ends.
- **H-6:** Tamed animals join the wave 20 battle.

## Milestones

- **U1: Fixes** — Cryo armor in the crafting menu and visible on the knight (X-1, X-2).
- **U2: Materials and new basic weapons** — gunpowder, meat, berries, the dagger, bat and grenade (N-1, N-2, N-4, G-3, G-4).
- **U3: The bunker and diamond weapons** — the bunker, chest, diamond weapons and crits (B-1 to B-4, N-3, G-2).
- **U4: The musket** — musket with real-time reload and crits (G-1, G-2).
- **U5: New enemy looks and bandits** — four new looks and bandit stealing (D-1 to D-5).
- **U6: Taming** — wild animals, taming and animal companions (H-1 to H-6).
- **U7: Balance and release** — playtest, tune numbers, check iPhone performance, and update the itch.io and PC builds.

## Open questions

- How are the two bunker entrances hidden (bushes over the trapdoor, a loose stone in the castle wall)? Default: Claude picks.
- Should tamed animals also come back after a game over? Default: no, a new game starts with none.
- Are the new recipes and damage numbers fun? Tune after playtesting.
