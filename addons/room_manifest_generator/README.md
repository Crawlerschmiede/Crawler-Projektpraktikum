# Room Manifest Generator Plugin

This editor plugin generates the room manifest during export and injects it into the exported artifact.

## What it does
- Runs automatically during export when the plugin is enabled.
- Scans the room scene folders and builds `res://scenes/rooms/room_manifest.json`.
- Injects the manifest into the export using `EditorExportPlugin.add_file()`.
- Optionally tries to write `res://scenes/rooms/room_manifest.json` for local use. If that write fails, it logs a warning and continues.

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

## Enabling the plugin
- Open Project Settings -> Plugins.
- Enable `room_manifest_generator`.
- Export normally (editor or CI). The manifest will be embedded in the export.

## Workflow guidance
- CI/CD: rely on the export plugin to embed the manifest.
- Local runs: you can generate it manually via `tools/generate_room_manifest.gd` if needed.
- Committing `room_manifest.json` is optional if you export via CI. If you do commit it, keep it updated when rooms change.

## Related code
- Export plugin: `addons/room_manifest_generator/room_manifest_export.gd`
- Runtime fallback: `scripts/Mapgenerator/helpers/mg_io.gd`
- Manual generator: `tools/generate_room_manifest.gd`
