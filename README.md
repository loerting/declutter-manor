# Declutter Style Test

A throwaway Godot 4.7 scene to evaluate a fully procedural, stylized art direction.
Every prop is generated at runtime from primitives in `scripts/Props.gd`; no model files exist.

## Run
Open the folder in Godot and press F5, or run `godot --path .` from this directory.

Controls: hold right mouse button to look, WASD to move, Q/E down/up, Shift to go faster.

## Screenshots
`screenshots/overview.png` and `screenshots/closeup.png`. Regenerate with:

    godot --path . -- --screenshot=$PWD/screenshots/overview.png
    godot --path . -- --closeup --screenshot=$PWD/screenshots/closeup.png
