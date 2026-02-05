# Crawler-Projektpraktikum

Godot 4 project for a small crawler-style game.

## Setup Instructions

### Prerequisites

- Install **Godot 4.5.1** (this is the version used in CI).
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
gdformat scripts/

# Lint GDScript files
gdlint scripts/
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
  - Auto-formats GDScript in `scripts/` via `gdformat`
  - If formatting changes files, it commits them back to the same branch (uses `GITHUB_TOKEN`)
  - Safety: only runs with write permissions for branches in this repo (skips PRs from forks)
- `gdscript-lint.yml`
  - Runs on pushes to `dev` and on PRs targeting `dev` or `main`
  - Runs `gdlint scripts/`
- `test-build.yml`
  - Runs on pushes to `dev` and on PRs targeting `dev` or `main`
  - Exports Windows and Linux builds (build validation)
- `release.yml`
  - Runs when you push a tag matching `v*` (example: `v0.1.0`)
  - Also supports manual runs via **workflow_dispatch** with a `tag` input (for re-running the release process for an existing tag; **not** for creating new releases)
  - To create a new release, push a new tag as described in the Release Process section below.
  - Builds + packages Windows (`.zip`) and Linux (`.tar.gz`) and publishes a GitHub Release

## Branching Strategy

- Main branch is `main`
- Develop branch is `dev`
- Feature and other branches should be created from `dev` and merged back into `dev`
- Releases are merged from `dev` into `main`
- Hotfixes are created from `main` and merged back into both `main` and `dev`

## Release Process (dev → main → versioned release)

This is the current workflow:

1. Create a PR in GitHub to merge `dev` → `main`.
2. Merge the PR in GitHub after CI passes.
3. Create a versioned release by tagging `main`:

   ```bash
   git checkout main
   git pull
   git tag -a v0.1.0 -m "Release v0.1.0"
   git push origin v0.1.0
   ```

   This triggers the release workflow which builds and publishes a GitHub Release with downloadable artifacts.

4. Sync `dev` back with `main`:

   ```bash
   git checkout dev
   git pull origin main
   git push origin dev

**Items hinzufügen**
  - **Ort der Daten:** Die Item-Definitionen werden in `res://data/itemData.json` gepflegt. Jede Eigenschaft ist ein JSON-Objekt, dessen Schlüssel der interne Item-Name (ID) ist.
  - **Icon:** Lege für jedes Item ein Icon unter `res://assets/item_icons/` ab. Der Dateiname sollte genau dem Item-Key entsprechen (z. B. `placeholder_sword.png` für das Item `placeholder_sword`).
  - **Minimalbeispiel (JSON):**

  ```json
  "placeholder_sword": {
    "ItemCategory": "Weapon",
    "StackSize": 1,
    "Description": "Ein einfaches Schwert.",
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
    "bound_skills": ["Slash"]
  }
  ```

  - **Wichtige Felder (Erklärung):**
    - `ItemCategory`: Kategorie (z. B. `Weapon`, `Consumable`).
    - `StackSize`: Maximale Stapelgröße im Inventar.
    - `Description`: Tooltip / Beschreibungstext.
    - `group`: Gruppierung/Typ, wird teilweise für UI/Logik verwendet.
    - `weight`: (optional) Wird von Loot-/Pool-Generatoren benutzt.
    - `loot_stats`: (optional) Alternativstruktur mit `weight`, `chance`, `max_stack`.
    - `merchant`: (optional) Objekt mit Verkaufs-/Vorrats-Parametern (`min_count`, `max_count`, `min_price`, `max_price`, `buy_amount`, `chance`, `weight`). Händler-Logik liest diese Felder, um Shops zu füllen.
    - `bound_skills`: (optional) Liste an Skill-Namen, die beim Equippen gebunden werden (wird von `item.gd` gelesen).
    - `use_effects`: (optional) Für Verbrauchsgegenstände: Liste der Effekte, die beim Benutzen ausgelöst werden (z. B. `Heal`).

  - **Icon laden:** Die UI-Komponente `item.gd` erwartet die Icon-Datei unter `res://assets/item_icons/<item_key>.png`. Falls kein Icon gefunden wird, wird eine Warnung geloggt.

  - **Daten neu laden:** Die JSON-Datei wird beim Start über `JSONData.gd` geladen. Nach Änderungen an `itemData.json` die Szene/Editor neu laden oder das Spiel neu starten, damit die Änderungen wirksam werden.

  - **Händler / Registry:** Zur Laufzeit verwaltet `scripts/merchant_registry.gd` Items für Händler. Standardmäßig werden Händlerdaten aus dem `merchant`-Block in `itemData.json` genutzt, aber du kannst Items zur Laufzeit mit `MerchantRegistry.set_items(reg_key, items_array)` setzen.

  - **Tipps:**
    - Verwende als Schlüssel (Item-ID) keine Leerzeichen oder Sonderzeichen, damit Dateinamen und Referenzen sauber funktionieren.
    - Falls du größere Assets hinzufügst, denke an Git LFS (`git lfs install` / `git lfs track`) für Binärdateien.

Wenn du möchtest, kann ich ein kleines Script ergänzen, das neue Items per Template in `data/itemData.json` einträgt und ein Icon-Placeholder erzeugt — möchtest du das? 

**Räume hinzufügen**

Dieses Projekt benutzt einen Map-Generator (`scenes/testscene2/map_generator.gd`), der Raum-Szenen aus `res://scenes/rooms/Rooms/` lädt und Türen verbindet. Damit ein Raum korrekt vom Generator verarbeitet wird, beachte bitte die folgende Struktur und Konventionen.

- **Ordner:** Lege neue Raum-Szenen als `.tscn` im Ordner `res://scenes/rooms/Rooms/` ab. Geschlossene Tür-Szenen (zum Backen) kommen in `res://scenes/rooms/Closed Doors/`.
- **Root-Node:** Verwende `Node2D` als Root des Raum-Scenes. Optional kann das Root-Node das Script `scenes/rooms/Scripts/RoomTemplate.gd` erweitern / ähnliche Export-Variablen anbieten.
- **Wichtige Kinder-Nodes:**
  - `TileMapLayer` (ein `TileMapLayer`-Node): Boden/Tiles des Raums. Wird vom Generator gelesen und in die Welt-Karte gebacken.
  - `TopLayer` (optional, `TileMapLayer`): Oberer Layer (Überlagertes Dekor), wird separat gebacken.
  - `Doors` (ein `Node2D`): enthält Kinder-Node(s), die Türen markieren (siehe unten).

- **Door-Objekte:** Jede Tür im Raum sollte als Child unter `Doors` liegen. Der Map-Generator erwartet, dass Tür-Objekte folgende Eigenschaften/Benennung haben:
  - Exportierte/Eigenschaft `direction` (z. B. `"U"/"D"/"L"/"R"` oder `"up"/"down"/...`); der Generator liest `direction` um passende Closed-Door-Szenen zu finden.
  - Property `used` (bool), Standard `false`. Der Generator setzt `used = true`, wenn die Tür verbunden oder gebacken wurde.
  - Positioniere die Tür-Node genau dort, wo die Tür im Raum liegen soll (global_position wird später an die Welt-Tiles angepasst).

- **Room-Metadaten / Export-Variablen:** Um das Verhalten des Generators zu steuern, definiere Export-Variablen am Root (oder nutze `RoomTemplate.gd`):
  - `spawn_chance` (float): Wahrscheinlichkeit, dass der Raum gewählt wird.
  - `max_count` (int): Max. wie oft der Raum pro Map vorkommt.
  - `min_rooms_before_spawn` (int): Mindestanzahl bereits platzierter Räume, bevor dieser erscheinen darf.
  - `is_corridor` (bool): Ob der Raum als Korridor gilt (wichtig für den GA)
  - `required_min_count` (int): Wenn >0, wird dieser Raum als 'required' betrachtet und der Generator sorgt dafür, dass er vorkommt.

- **Raum-Key / Gruppierung:** Der Generator kann die erste Group des Root-Nodes als `room_key` nutzen. Füge bei Bedarf eine Scene-Group hinzu (`Node -> Groups` im Editor), z. B. `treasure_room`, um Räume zu kategorisieren.

- **Closed Doors:** Falls du spezielle Tür-Grafiken/-Tiles brauchst, lege passende Closed-Door-Scenes im `Closed Doors`-Ordner ab. Diese Szenen sollten ebenfalls eine exportierte `direction` haben oder `Doors`-Children mit `direction`.

- **Minimaler Door-Script (Beispiel)**
  Erstelle eine kleine Tür-Node ohne komplexes Script; das folgende reicht oft:

```gdscript
extends Node2D

@export var direction: String = "U"
var used: bool = false

func _ready():
    # optional: Darstellung/Collision oder Area2D als Kind
    pass
```

- **Room Template (Beispiel)**
  Du kannst das vorhandene Template `scenes/rooms/Scripts/RoomTemplate.gd` verwenden — es stellt `get_free_doors()` bereit, das der Generator erwartet.

- **Testen:**
  1. Speichere die neue Room-Scene in `res://scenes/rooms/Rooms/`.
  2. Öffne `scenes/testscene2/map_generator.gd` im Editor und stelle sicher, dass `rooms_folder` auf `res://scenes/rooms/Rooms/` zeigt (Standard-Export ist so gesetzt).
  3. Starte die Map-Generierung (im Editor ist meist ein Button/Scene-Runner vorhanden) oder rufe `get_random_tilemap()` / `generate_with_genome(...)` über den Generator an.
  4. Prüfe die Debug-Ausgabe: Wenn eine Room-Scene kein `get_free_doors()` liefert, wird der Generator eine Fehlermeldung ausgeben. Nutze `debug_print_free_doors()` zum Debuggen.

- **Fehlerquellen / Tipps:**
  - Stelle sicher, dass `TileMapLayer` und optional `TopLayer` existieren und korrekt TileSets verwenden.
  - Türen müssen korrekt positioniert und mit `direction` versehen sein — sonst kann der Generator sie nicht verbinden oder passende Closed-Door-Szenen finden.
  - Wenn dein Raum nach dem Backen nicht sichtbar ist, prüfe `placed_rooms` und ob `visible` auf `false` gesetzt wurde (Generator blendet Räume manchmal aus, nachdem die TileMap gebacken wurde).

Wenn du möchtest, kann ich für dich ein kleines Beispiel-Raum-Template (`res://scenes/rooms/Rooms/example_room.tscn`) erzeugen (inkl. `TileMapLayer`, `TopLayer` und zwei Türen). Soll ich das anlegen? 
   ```