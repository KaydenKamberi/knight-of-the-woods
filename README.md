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
4. Press **F5** (or the ▶ Play button). The knight starts in a clearing in the middle of the forest.

## Controls

| Action | PC | Phone / tablet |
| --- | --- | --- |
| Move | WASD or arrow keys | Joystick: put your thumb anywhere on the left half of the screen |
| Look around | Mouse (click the game first to capture the mouse) | Drag on the right half of the screen |
| Throw a knife at the crosshair | Left click (once the mouse is captured) | Throw button, bottom right |
| Pull a knife from a poster, or pick up a thrown one | E | Grab button (appears when a knife is in reach) |
| Shift-lock: the knight turns with the camera | Left Shift | Lock icon, under the camera icon |
| Switch view (over the shoulder / inside the helmet) | V | Camera icon, top right |
| Free the mouse (also turns shift-lock off) | Esc | — |

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
- **`scripts/world_time.gd`**: the time mechanic (autoload, reachable from any script as `WorldTime`). See below.
- **`scenes/swinging_log.tscn`** + **`scripts/swinging_log.gd`**: a log on two ropes in front of the start point, for checking that the world slows down.

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

## Physics layers

| Layer | Name | Used by |
| --- | --- | --- |
| 1 | world | Ground, trees, rocks, the swinging log |
| 2 | player | The knight |
| 3 | boundary | The invisible wall at the forest edge (stops the knight and dummies, not knives) |
| 4 | dummies | Walking dummies |
| 5 | debris | Ragdoll pieces (knives hit them; the knight walks through them) |

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
