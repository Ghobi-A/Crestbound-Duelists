#!/usr/bin/env bash
set -euo pipefail
python3 -m pip install --target /tmp/crestbound-python Pillow
export PYTHONPATH=/tmp/crestbound-python
python3 tools/materialize_overworld_v2.py
mkdir -p /tmp/crestbound-godot "$HOME/.local/share/godot/export_templates/4.3.stable" build/web
curl -fsSL https://github.com/godotengine/godot/releases/download/4.3-stable/Godot_v4.3-stable_linux.x86_64.zip -o /tmp/crestbound-godot/editor.zip
unzip -oq /tmp/crestbound-godot/editor.zip -d /tmp/crestbound-godot
curl -fsSL https://github.com/godotengine/godot/releases/download/4.3-stable/Godot_v4.3-stable_export_templates.tpz -o /tmp/crestbound-godot/templates.zip
unzip -oq /tmp/crestbound-godot/templates.zip templates/web_release.zip -d /tmp/crestbound-godot
cp /tmp/crestbound-godot/templates/web_release.zip "$HOME/.local/share/godot/export_templates/4.3.stable/"
GODOT=/tmp/crestbound-godot/Godot_v4.3-stable_linux.x86_64
"$GODOT" --headless --path game --editor --import --quit
"$GODOT" --headless --path game --export-release Web ../build/web/index.html
test -s build/web/index.wasm
test -s build/web/index.pck
