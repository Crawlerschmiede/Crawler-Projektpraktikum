<!--
agents.md
Quick guide for automated agents (Copilot, bots, scripts) working in this repository.
Created automatically by Copilot Agent
-->

# Agents Guide — Project Overview & Working Rules

In short: This document describes folder structure, conventions, and safe workflows for automated agents (e.g., Copilot-like tools) in `Crawler-Projektpraktikum`.

**Purpose**: Agents should make consistent, safe, and reproducible changes (path fixes, small bug fixes, refactorings). This document helps avoid common error sources (wrong `ext_resource` paths, missing scripts, incorrect property assignments).

---

**Top-level folders (quick overview)**
- `scenes/`: All scenes (`.tscn`). Subfolders organize rooms, UI, items, etc.
- `scripts/`: All GDScript files. Domain folders include `entity/`, `UI/`, `Mapgenerator/`, `Mapgenerator/helpers/`, `rooms/`, `Item/`, `Autoloadscripts/`, `...`.
- `assets/`: Images, audio, fonts, icons, import metadata.
- `shaders/`: Godot shader files.
- `addons/`: Project plugins.
- `data/`: JSON data (e.g. `entityData.json`, `itemData.json`).
- `scenes/*/merchant/`, `scenes/rooms/`, etc.: specialized gameplay module folders.

---

**Important scripts / entry points**
- `project.godot`: Autoload definitions (see `SettingsManager`, `PlayerInventory`, `MerchantRegistry`, etc.).
- `scripts/Autoloadscripts/*`: Global singletons registered via `project.godot`.
- `scripts/entity/player_character.gd`: Player-specific logic; frequent interaction point with UI.
- `scripts/Mapgenerator/map_generator_modular.gd`: Top-level map generation script; uses modules under `scripts/Mapgenerator/helpers`.

---

Recommended working practices for agents

- Always respect SOLID, DRY, KISS, and YAGNI: design for clarity and maintainability, avoid duplication, keep implementations simple, and do not add functionality that is not required.

- Change files only via `apply_patch` (atomic diffs). Keep each change minimal.
- Before changing an `ext_resource` path in a `.tscn` file, check:
  - Does the target file exist (`file_search` / `grep_search`)?
  - Is the path semantically correct (e.g. `res://scripts/...` for scripts, `res://scenes/...` for scenes)?
- In scenes (`.tscn`), update `ext_resource` entries only if the referenced resource is actually located elsewhere. Never change UIDs; update only the `path` value.
- For runtime property assignments (e.g. `slot.item_name = ...`, `self.is_player = true`):
  - Verify the property/method exists with `has_method()`, `has_node()`, or `get()`.
  - If a property may be missing in callers, add it defensively in the base class (e.g. `var is_player: bool = false` in `MoveableEntity`) instead of duplicating checks in multiple call sites.

---

Repository conventions

- Script paths: `res://scripts/<domain>/...` — preferred over `res://scenes/...` for helper modules.
- UI scripts: `res://scripts/UI/*`; entity logic: `res://scripts/entity/*`; map generation helpers: `res://scripts/Mapgenerator/helpers/*`.
- Scene files (`.tscn`) should point `ext_resource` paths to real script files, not non-existent locations. Ignore `.bak` and temporary `.tmp` files when patching.

---

Tips for automated fixes (safe patterns)

1. Validate instead of blind replacement:
   - Search repository-wide for `res://scripts/...` or `res://scenes/...` references first (`grep_search`).
   - If a `.tscn` contains an `ext_resource` path to `res://scripts/X`, verify `scripts/X` exists with `file_search`.

2. If a script reference is missing, search for likely alternatives:
   - Search for matching filenames under `scripts/`.
   - Prefer `scripts/<same-subfolder>` over `scenes/<...>` when the target is a module.

3. Property assignments (e.g. `slot.item_name = ...`):
   - Check in the target script (e.g. `merchant_item_buy_box.gd`) whether the variable exists.
   - If a scene is instantiated but the root node is a `Control` without script, instantiate a scene variant with the correct script or create the missing script minimally (as done in an existing bugfix pattern in this repo).

4. Checks after changes:
   - Run `grep_search` again for stale or invalid `res://scenes/...` and `res://scripts/...` references (especially old helper paths like `mg_*.gd`).
   - Start Godot (`godot --path "<repo-root>"`) and watch for `load_source_code` / `Failed loading resource` errors.

---

Examples from recent fixes (agent note)
- Fixed preload paths in `scripts/Mapgenerator/*`: `res://scenes/.../mg_*.gd` → `res://scripts/Mapgenerator/helpers/mg_*.gd`.
- Added base property `is_player` in `MoveableEntity` instead of scattering checks across callers.
- Corrected `ext_resource` paths in `.tscn` files (e.g. `loading_screen.tscn`, `marker.tscn`, `player-character-scene.tscn`) to real script locations.

---

Checklist before proposing/applying a change
- Run `grep_search` for the affected path/identifier.
- Verify target file existence with `file_search` or `read_file`.
- Create atomic patches (one concern per patch, small diffs).
- Run `grep_search` again after patching to catch remaining stale paths.
- Update `manage_todo_list` with a clear short description of the change.

---

Contact / clarification
- If an agent is not sure whether to apply a change automatically (ambiguous matches, multiple valid target paths), create a `todo` with `status: not-started` and wait for human confirmation.

---

This document is living guidance — update it when new conventions or folder structures are introduced.
