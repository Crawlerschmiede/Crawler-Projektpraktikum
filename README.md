# Crawler-Projektpraktikum

Godot 4 project for a small crawler-style game.

## Setup Instructions

### Prerequisites

- Install **Godot 4.6** (this is the version used in CI).
- Install Git (and ensure it is on your PATH).
- Install Git LFS.
- (Windows) Install the Visual C++ Redistributable (x64): https://aka.ms/vc14/vc_redist.x64.exe

### Clone + Git LFS

- Clone this repository.
- Enable Git LFS so large assets are pulled correctly:

  ```bash
  git lfs install
  git lfs pull
  ```

### Open and Run

- Open the project in Godot (open the folder containing `project.godot`).
- Press **F5 / Run Project**.

<div style="border:3px solid #e60000; background-color:#fff3f3; padding:16px; border-radius:6px; color:#b30000;">
<h2 style="margin:0 0 8px;">⚠️ IMPORTANT</h2>
<p style="margin:0 0 8px;">Before opening the project, ensure the required runtime and file handling are set up. Missing these steps can lead to missing assets, broken git history or editor errors.</p>
<ul style="margin:0 0 0 20px;">
	<li>Enable Git LFS for large assets: <code>git lfs install</code> (or <code>git lfs install --local</code> in the project directory).</li>
	<li>Install the Visual C++ Redistributable (x64).</li>
</ul>
</div>

## Building / Exporting

- Export presets are stored in `export_presets.cfg`.
- CI and releases use these export names:
  - `Windows Desktop` → produces `build/windows/Crawler-Projektpraktikum.exe` + `.pck`
  - `Linux` → produces `build/linux/Crawler-Projektpraktikum.x86_64` + `.pck`

To export locally, use the Godot Editor: **Project → Export…** and select the preset.

## Optional Addons

### GDScript Toolkit

- Install the GDScript Toolkit via uv or pip directly
  - uv: `uv tool install "gdtoolkit==4.*"`
  - pip: `pip install "gdtoolkit==4.*"`

```
# Format GDScript files
gdformat ./

# Lint GDScript files
gdlint ./
```

Linting Docs: https://github.com/Scony/godot-gdscript-toolkit/wiki/3.-Linter

### Pre Commit Hook

- Install pre-commit via uv or pip directly
  - uv: `uv tool install pre-commit`
  - pip: `pip install pre-commit`
- Install the git hooks
  - `pre-commit install`

## CI (GitHub Actions)

These workflows live in `.github/workflows/`:

- `gdscript-format.yml`
  - Runs on pushes to `dev`, and on PRs targeting `dev` (and can be run manually)
  - Auto-formats GDScript project-wide via `gdformat ./`
  - If formatting changes files, it commits them back to the same branch (uses `GITHUB_TOKEN`)
  - Safety: only runs with write permissions for branches in this repo (skips PRs from forks)
- `gdscript-lint.yml`
  - Runs on pushes to `dev`, and on PRs targeting `dev` (and can be run manually)
  - Runs `gdlint ./`
- `test-build.yml`
  - Runs on pushes to `dev`, and on PRs targeting `dev` (and can be run manually)
  - Exports Windows and Linux builds (build validation)
- `release.yml`
  - Runs when you push a tag matching `v*` (example: `v0.1.0`)
  - Also supports manual runs via **workflow_dispatch** with a `tag` input (for re-running the release process for an existing tag; **not** for creating new releases)
  - To create a new release, push a new tag as described in the Release Process section below.
  - Builds + packages Windows (`.zip`) and Linux (`.tar.gz`) and publishes a GitHub Release

## Branching Strategy

- Release branch is `release`
- Develop branch is `dev`
- Feature and other branches should be created from `dev` and merged back into `dev`
- Releases are merged from `dev` into `release`
- Hotfixes are created from `release` and merged back into both `release` and `dev`

## Release Process (dev → release → versioned release)

This is the current workflow:

1. Create a PR in GitHub to merge `dev` → `release`.
2. Merge the PR in GitHub after CI passes.
3. Create a versioned release by tagging `release`:

   ```bash
   git checkout release
   git pull
   git tag -a v0.1.0 -m "Release v0.1.0"
   git push origin v0.1.0
   ```

   This triggers the release workflow which builds and publishes a GitHub Release with downloadable artifacts.

4. Sync `dev` back with `release`:

   ```bash
   git checkout dev
   git pull origin release
   git push origin dev
   ```

### Interactive release helper (Git Bash)

If you want a guided CLI flow for the same process, use:

```bash
bash tools/release-assistant.sh
```

The script helps you:
- inspect current release status (latest tag, latest GitHub release, branch SHAs, open `dev -> release` PR)
- create/view and merge a `dev -> release` PR via `gh`
- create and push a `v<major>.<minor>.<patch>` tag on `release` (triggers `release.yml`)
- watch release workflow runs and optionally open related pages
- sync `dev` from `release` after publishing

Behavior:
- In an interactive terminal, it shows a menu.
- In non-interactive execution (no TTY), it automatically runs the full flow with defaults (no flags required).

**Adding Items**

- **Data location:** Item definitions are stored in `res://data/itemData.json`. Each entry is a JSON object keyed by the internal item name (ID).
- **Icon:** Add one icon per item under `res://assets/item_icons/`. The file name should exactly match the item key (for example `placeholder_sword.png` for item `placeholder_sword`).
- **Minimal example (JSON):**

```json
"placeholder_sword": {
  "ItemCategory": "Weapon",
  "StackSize": 1,
  "Description": "A simple sword.",
  "group": "Weapon",
  "weight": 3,
  "merchant": {
    "min_count": 1,
    "max_count": 2,
    "min_price": 6,
    "max_price": 9,
    "buy_amount": 2,
    "chance": 1.0,
    "weight": 1
  },
  "bound_skills": ["Slash"],
	"range":"short"
}
```

- **Key fields (explanation):**
  - `ItemCategory`: Category (for example `Weapon`, `Consumable`).
  - `StackSize`: Maximum stack size in inventory.
  - `Description`: Tooltip / description text.
  - `group`: Group/type, used by some UI and gameplay logic.
  - `weight`: (optional) Used by loot/pool generators.
  - `loot_stats`: (optional) Alternative structure with `weight`, `chance`, `max_stack`.
  - `merchant`: (optional) Object with shop stock/pricing parameters (`min_count`, `max_count`, `min_price`, `max_price`, `buy_amount`, `chance`, `weight`). Merchant logic reads these fields to populate shops.
  - `bound_skills`: (optional) List of skill names bound when equipping the item (read by `item.gd`).
  - `range`: (optional) `short|medium|long`, depending on weapon range behavior.
  - `use_effects`: (optional) For consumables: list of effects triggered when used (for example `Heal`).

- **Loading icons:** The UI component `item.gd` expects icons at `res://assets/item_icons/<item_key>.png`. If no icon is found, a warning is logged.

- **Reloading data:** The JSON file is loaded at startup via `JSONData.gd`. After changing `itemData.json`, reload the scene/editor or restart the game so the changes take effect.

- **Merchant / registry:** At runtime, `scripts/rooms/merchant/merchant_registry.gd` manages merchant items. By default merchant data comes from the `merchant` block in `itemData.json`, but you can override items at runtime with `MerchantRegistry.set_items(reg_key, items_array)`.

- **Tips:**
  - Do not use spaces or special characters in keys (item IDs) so file names and references stay clean.
  - If you add larger assets, remember to use Git LFS (`git lfs install` / `git lfs track`) for binaries.

**Adding Rooms**

This project uses a map generator (`scripts/Mapgenerator/map_generator_modular.gd`) that loads room scenes from `res://scenes/rooms/Rooms/` and connects doors. To ensure a room is processed correctly, follow this structure and conventions.

- **Folder:** Add new room scenes as `.tscn` files under `res://scenes/rooms/Rooms/`. Closed-door scenes (used for baking) go in `res://scenes/rooms/Closed Doors/`.
- **Root node:** Use `Node2D` as the room scene root. Optionally, the root can extend `scenes/rooms/Scripts/RoomTemplate.gd` (or expose equivalent exported variables).
- **Important child nodes:**
  - `TileMapLayer` (a `TileMapLayer` node): room floor/tiles. Read by the generator and baked into the world tilemap.
  - `TopLayer` (optional, `TileMapLayer`): upper overlay/decor layer, baked separately.
  - `Doors` (a `Node2D`): contains child nodes that mark door positions.

- **Door objects:** Each room door should be a child of `Doors`. The map generator expects:
  - Exported/property `direction` (currently `"north"`, `"south"`, `"east"`, `"west"`); used to match closed-door scenes.
  - Property `used` (bool), default `false`. The generator sets `used = true` once a door is connected or baked.
  - Correct node positioning where the door should be in the room (`global_position` is used later during tile placement).

- **Room metadata / exported vars:** To control generator behavior, define exported vars on the room root (or use `RoomTemplate.gd`):
  - `spawn_chance` (float): Probability that this room is selected.
  - `max_count` (int): Maximum number of times this room can appear per map.
  - `min_rooms_before_spawn` (int): Minimum number of already placed rooms before this one can appear.
  - `is_corridor` (bool): Whether this room is considered a corridor (important for GA constraints).
  - `required_min_count` (int): If >0, the room is treated as required and the generator ensures it appears.

- **Room key / grouping:** The generator can use the first group on the root node as `room_key`. Add a scene group (`Node -> Groups` in the editor), for example `treasure_room`, when you want categorization.

- **Closed doors:** If you need custom closed-door visuals/tiles, add matching closed-door scenes in the `Closed Doors` folder. These scenes should also expose `direction` or include `Doors` children with `direction`.

- **Minimal door script (example)**
  Use a lightweight door node; this is typically enough:

```gdscript
extends Marker2D

@export_enum("north", "south", "east", "west") var direction: String
var used := false
```

- **Room template (example)**
  You can use the existing template `scenes/rooms/Scripts/RoomTemplate.gd` — it provides `get_free_doors()`, which the generator expects.

- **Testing:**
  1. Save your new room scene in `res://scenes/rooms/Rooms/`.
  2. Open `scripts/Mapgenerator/map_generator_modular.gd` in the editor and confirm that `rooms_folder` points to `res://scenes/rooms/Rooms/` (this is the default export value).
  3. Start map generation (usually via an editor button/runner) or call `get_random_tilemap()` / `generate_with_genome(...)` on the generator.
  4. Check debug output: if a room scene does not provide `get_free_doors()`, the generator logs an error. Also verify that `Doors` contains only Door nodes and that each door has a valid `direction`.

- **Common pitfalls / tips:**
  - Ensure `TileMapLayer` and optional `TopLayer` exist and use valid TileSets.
  - Door nodes must be positioned correctly and provide `direction`; otherwise the generator cannot connect them or find matching closed-door scenes.
  - If a room is not visible after baking, inspect `placed_rooms` and whether `visible` has been set to `false` (the generator may hide rooms after baking tilemaps).
