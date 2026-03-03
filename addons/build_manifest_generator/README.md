# Build Manifest Generator Plugin

This editor plugin generates build-time manifests during export and injects them into the exported artifact.

## What it does
- Regenerates both manifests when the project is opened in the editor (plugin enabled).
- Runs automatically during export when the plugin is enabled.
- Scans the room scene folders and builds `res://scenes/rooms/room_manifest.json`.
- Injects the manifest into the export using `EditorExportPlugin.add_file()`.
- Optionally tries to write `res://scenes/rooms/room_manifest.json` for local use. If that write fails, it logs a warning and continues.
- Scans `res://assets/sfx` and builds `res://data/audio_tracks.generated.json` from naming conventions:
	- `(floor-<n>)...` -> floor music index `n-1`
	- `(floor-boss)...` -> `sfx_events.world.final_boss_room`
	- `(normal-fight)...` -> generic fight music pool
	- `(boss-<type>)...` -> boss pools under `music.combat_by_type.boss.<type>`
	- `(boss-room)...` -> mapped to `sfx_events.world.boss_room`
- Injects `audio_tracks.generated.json` into the export using `EditorExportPlugin.add_file()`.

## Why this exists
In exported builds, `DirAccess` cannot enumerate packed `res://` folders. The runtime loader in `MGIOModule` falls back to a manifest if a folder scan returns empty.

## Manifest format
`room_manifest.json` is a JSON dictionary with arrays of scene paths:

```
{
	"rooms": ["res://scenes/rooms/Rooms/room_11x11_4.tscn", ...],
	"closed_doors": ["res://scenes/rooms/Closed Doors/door_north.tscn", ...]
}
```

`audio_tracks.generated.json` currently uses schema version `1`:

```
{
	"schema_version": 1,
	"music": {
		"world_by_index": {
			"0": ["res://assets/sfx/(floor-1)..."],
			"1": ["res://assets/sfx/(floor-2)..."]
		},
		"combat_by_type": {
			"generic": ["res://assets/sfx/(normal-fight)..."],
			"boss": {
				"default": ["res://assets/sfx/(boss-room)..."],
				"plant": ["res://assets/sfx/(boss-plant)..."],
				"orc": ["res://assets/sfx/(boss-orc)..."],
				"necro": ["res://assets/sfx/(boss-necro)..."],
				"wendigo": ["res://assets/sfx/(boss-wendigo)..."]
			}
		}
	},
	"sfx_events": {
		"world": {
			"boss_room": ["res://assets/sfx/(boss-room)..."],
			"final_boss_room": ["res://assets/sfx/(floor-boss)..."]
		}
	}
}
```

Notes:
- Tracks are deduplicated while generating the manifest.
- Runtime loading in `AudioManager` still supports older manifest formats as fallback.



## Enabling the plugin
- Open Project Settings -> Plugins.
- Enable `build_manifest_generator`.
- Export normally (editor or CI). The manifest will be embedded in the export.

## Workflow guidance
- CI/CD: rely on the export plugin to embed the manifests. No manual pre-generation step is required.
- Opening the project in the editor refreshes both manifest files automatically while the plugin is enabled.
- Running the project from the editor also refreshes both manifest files at startup.
- Local runs: you can generate manifests via `tools/generate_manifests_editor.gd` (EditorScript) or `tools/generate_manifests_cli.gd` (headless `--script`).
- Committing `room_manifest.json` is optional if you export via CI. If you do commit it, keep it updated when rooms change.
- Committing `audio_tracks.generated.json` is optional if you export via CI. If you do commit it, keep it updated when SFX files change.

## Related code
- Export plugin: `addons/build_manifest_generator/build_manifest_export.gd`
- Runtime fallback: `scripts/Mapgenerator/helpers/mg_io.gd`
- Manual generator: `tools/generate_manifests_editor.gd`
- CLI generator: `tools/generate_manifests_cli.gd`
