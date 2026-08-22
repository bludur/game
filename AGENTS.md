# Mage Prototype — Codex Instructions

## Product direction

- Engine: Godot 4.7.2, Forward+ renderer.
- Language: statically typed GDScript.
- Perspective: player-relative third-person 3D camera with mouse orbit and collision avoidance.
- Current scope: single-player vertical slice only.
- Explicitly out of scope until approved: multiplayer, procedural world generation, live services, and open-world streaming.

## GodotPrompter

Before implementing a Godot system, load the matching `godot-prompter:*` skill and follow it. Common mappings:

- Project scaffolding: `godot-project-setup`
- Scene trees: `scene-organization`
- GDScript: `gdscript-patterns`
- Player movement: `player-controller`, `input-handling`, `physics-system`
- Camera: `camera-system`
- Game data: `resource-pattern`
- Spell effects: `particles-vfx`, `shader-basics`, `tween-animation`
- Tests: `godot-testing`
- Review: `godot-code-review`

## Architecture rules

- One scene owns one concept. Prefer composition over deep inheritance.
- Children emit signals upward; parents call methods downward.
- Use typed custom Resources for spell, item, enemy, and level definitions.
- Treat shared Resources as immutable definitions. Duplicate them before storing mutable per-instance state.
- Gameplay input must use Input Map actions; never hard-code keys in gameplay scripts.
- All movement and collision changes belong in `_physics_process`.
- Avoid Autoloads until a truly global lifetime is required.
- Keep authored scenes and Resources in text formats (`.tscn`, `.tres`).

## Code quality

- Explicitly type variables, parameters, return values, arrays, and dictionaries.
- Use `snake_case` for files, variables, functions, and Input Map actions.
- Use `PascalCase` only for `class_name` types.
- Expose tuning values with typed `@export` properties and sensible ranges.
- Do not introduce warnings, orphaned nodes, missing resources, or cyclic dependencies.
- Add or update automated checks for every non-visual behavior.

## Required checks

Run before handing off a change:

```powershell
.\tools\godot.ps1 -Console --headless --path . --log-file .godot/qa_main.log --quit-after 2
.\tools\godot.ps1 -Console --headless --path . --log-file .godot/qa_smoke.log --script res://tests/qa/project_smoke_test.gd
```

If GUT is installed, also run:

```powershell
.\tools\godot.ps1 -Console --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gexit
```
