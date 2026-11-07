# Knight of the Woods

A 3D wave-survival game made in **Godot 4.7** (standard version, not .NET), using the
**Compatibility** renderer so the web build runs in iPhone Safari.
The full design is in `Knight of the Still Woods — PRD.md`.

## Folder layout

| Folder | What goes in it |
| --- | --- |
| `scenes/` | Godot scenes (`.tscn`). `scenes/test_scene.tscn` is the current main scene. |
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
4. Press **F5** (or the ▶ Play button). You should see a red cube spinning on a green ground.

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
