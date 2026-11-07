#!/usr/bin/env bash
# Exports the Windows, Linux and web builds into builds/ and zips each one
# (PRD P-1, P-2). Run it from the project folder, with Godot 4.7 and its export
# templates installed:
#
#   tools/export_all.sh /path/to/Godot_v4.7.2-stable
#
# Leave the path out if Godot is on your PATH as "godot".
set -euo pipefail
GODOT="${1:-godot}"
cd "$(dirname "$0")/.."
mkdir -p builds/windows builds/linux builds/web

"$GODOT" --headless --export-release "Windows Desktop" builds/windows/KnightOfTheWoods.exe
"$GODOT" --headless --export-release "Linux" builds/linux/KnightOfTheWoods.x86_64
"$GODOT" --headless --export-release "Web" builds/web/index.html

cd builds
rm -f KnightOfTheWoods-windows.zip KnightOfTheWoods-linux.zip KnightOfTheWoods-web.zip
(cd windows && zip -q -r ../KnightOfTheWoods-windows.zip KnightOfTheWoods.exe)
(cd linux && zip -q -r ../KnightOfTheWoods-linux.zip KnightOfTheWoods.x86_64)
# itch.io wants index.html at the top of the web zip.
(cd web && zip -q -r ../KnightOfTheWoods-web.zip . -x ".gitkeep")
ls -lh ./*.zip
