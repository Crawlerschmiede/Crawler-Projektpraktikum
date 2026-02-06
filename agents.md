<!--
agents.md
Kurzanleitung für automatisierte Agents (Copilot, Bots, Skripte), die im Repository arbeiten.
Erstellt: Automatisch durch Copilot-Agent
-->

# Agents Guide — Projektübersicht & Arbeitsregeln

Kurz: Dieses Dokument beschreibt die Ordnerstruktur, Konventionen und sichere Arbeitsweisen für automatisierte Agents (z. B. Copilot-ähnliche Tools) im Projekt `Crawler-Projektpraktikum`.

**Zweck**: Agents sollen Änderungen konsistent, sicher und reproduzierbar vornehmen (Pfadkorrekturen, kleine Bugfixes, Refactorings). Dieses Dokument hilft, typische Quellen von Fehlern (falsche `ext_resource`-Pfade, fehlende Skripte, falsche Property-Zuweisungen) zu vermeiden.

---

**Top-Level Ordner (Kurzüberblick)**
- `scenes/`: Alle Szenen (.tscn). Unterordner strukturieren Räume, UI, Items, etc.
- `scripts/`: Alle GDScript-Dateien. Unterordner nach Domänen: `entity/`, `UI/`, `Mapgenerator/`, `Mapgenerator/helpers/`, `rooms/`, `Item/`, `Autoloadscripts/`, `...`.
- `assets/`: Bilder, Audio, Fonts, Icons, Import-Metadaten.
- `shaders/`: Godot Shader-Dateien.
- `addons/`: Projekt-Plugins.
- `data/`: JSON-Daten (z. B. `entityData.json`, `itemData.json`).
- `scenes/*/merchant/`, `scenes/rooms/` etc.: spezialisierte Ordner für Gameplay-Module.

---

**Wichtige Scripts / Einstiegspunkte**
- `project.godot`: Autoloads (siehe `SettingsManager`, `PlayerInventory`, `MerchantRegistry` etc.).
- `scripts/Autoloadscripts/*`: Globale Singletons (werden über `project.godot` registriert).
- `scripts/entity/player_character.gd`: Player-spezifische Logik — häufige Interaktionsstelle mit UI.
- `scripts/Mapgenerator/map_generator_modular.gd`: Mapgen-Top-Level; nutzt Module unter `scripts/Mapgenerator/helpers`.

---

Empfohlene Arbeitsweisen für Agents

- Dateien nur per `apply_patch` ändern (Atomic diffs). Jede Änderung minimal halten.
- Bevor ein `ext_resource`-Pfad in einer `.tscn`-Datei geändert wird, prüfen:
  - Existiert die Ziel-Datei (`file_search` / `grep_search`)?
  - Ist der Pfad semantisch passend (z. B. `res://scripts/...` für Skripte, `res://scenes/...` für Szenen)?
- In Szenen (`.tscn`) `ext_resource`-Einträge nur dann anpassen, wenn die referenzierte Ressource tatsächlich an einem anderen Ort liegt. Niemals UIDs verändern — ersetze nur den `path`-Wert.
- Bei Properties, die zu Laufzeit gesetzt werden (z. B. `slot.item_name = ...`, `self.is_player = true`):
  - Prüfe mit `has_method()`, `has_node()` oder `get()` ob die Property oder Methode existiert.
  - Wenn die Property an der Basisklasse fehlen kann, füge sie defensiv in der Basisklasse hinzu (z. B. `var is_player: bool = false` in `MoveableEntity`) statt in jedem Aufrufer Prüfungen zu duplizieren.

---

Konventionen im Repo

- Script-Pfade: `res://scripts/<Domäne>/...` — bevorzugt gegenüber `res://scenes/...` für Hilfs-Module.
- UI-Scripts: `res://scripts/UI/*` ; Entity-Logik: `res://scripts/entity/*` ; Map-Generator-Hilfen: `res://scripts/Mapgenerator/helpers/*`.
- Scene-Dateien (`.tscn`) sollten `ext_resource`-Pfad auf die Script-Datei zeigen, nicht auf eine nicht-existente Location. Falls `.bak`-Dateien oder temporäre `.tmp` vorhanden sind, ignoriere sie beim Patchen.

---

Tipps für automatische Korrekturen (sichere Patterns)

1. Validieren statt blind ersetzen:
   - Suche zuerst repository-weit nach `res://scripts/...` oder `res://scenes/...` Verweisen (`grep_search`).
   - Wenn ein `.tscn` einen `ext_resource`-Pfad zu `res://scripts/X` enthält, verifiziere mit `file_search` dass `scripts/X` existiert.

2. Wenn eine Script-Referenz fehlt, suche nach möglichen Alternativen:
   - Suche nach Dateien mit passendem Dateinamen unter `scripts/`.
   - Preferiere `scripts/<same-subfolder>` über `scenes/<...>` wenn Quelle ein Modul ist.

3. Property-Assignments (z. B. `slot.item_name = ...`):
   - Prüfe in der Ziel-Script-Datei (z. B. `merchant_item_buy_box.gd`), ob die Variable existiert.
   - Wenn die Szene instanziert wird und Root-Node ein Control ohne Script ist, instanziere stattdessen eine Scene-Version mit dem passenden Script oder erstelle das fehlende Script (minimal) — so wie in einem Bugfix-Beispiel im Repo geschehen.

4. Tests nach Änderung:
   - `grep_search` erneut laufen lassen, nach `res://scenes/testscene2/mg_` o.ä. Fehlern suchen.
   - Godot starten (`godot --path "C:\\DEV\\Neuer Ordner (2)\\test2\\test3"`) und auf `load_source_code` / `Failed loading resource` achten.

---

Beispiele aus aktuellen Fixes (Hinweis für Agents)
- Korrigierte Preload-Pfade in `scripts/Mapgenerator/*`: von `res://scenes/testscene2/mg_*.gd` → `res://scripts/Mapgenerator/helpers/mg_*.gd`.
- Ergänzung einer Basiseigenschaft `is_player` in `MoveableEntity` statt verteilter Prüfungen.
- Korrektur von `ext_resource`-Pfaden in `.tscn`-Dateien (z. B. `loading_screen.tscn`, `marker.tscn`, `player-character-scene.tscn`) auf die tatsächlichen Script-Pfade.

---

Checkliste bevor ein Agent eine Änderung vorschlägt/anstößt
- Führe `grep_search` nach dem betroffenen Pfad/Bezeichner aus.
- Verifiziere die Existenz der Ziel-Datei mit `file_search` oder `read_file`.
- Erstelle atomare Patches (eine Sache pro Patch, kleine Diff-Größen).
- Führe `grep_search` nach dem Patch erneut aus, um verbliebene veraltete Pfade zu finden.
- Aktualisiere die `manage_todo_list` mit einer verständlichen Kurzbeschreibung der Änderung.

---

Kontakt / Rückfragen
- Wenn ein Agent unsicher ist, eine Änderung automatisch vorzunehmen (mehrdeutige Treffer, mehrere mögliche Zielpfade), lege eine `todo` mit `status: not-started` an und warte auf menschliche Rückversicherung.

---

Dieses Dokument ist lebendig — passe es an, wenn neue Konventionen eingeführt werden oder neue Ordnerstrukturen entstehen.
