#!/usr/bin/env python3
"""
Sync `data/itemData.json` with `assets/item_icons`.
- Adds missing items for icons like `arm_a1.png` by copying the base item `arm`.
- Removes item entries that have no corresponding icon (neither base nor any `_aN` variant).

Run from project root (Windows Powershell):
python tools\sync_itemdata_with_icons.py

It writes a backup `data/itemData.json.bak` before modifying.
"""
import json
import os
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
ITEMDATA = ROOT / "data" / "itemData.json"
ICONS_DIR = ROOT / "assets" / "item_icons"

if not ITEMDATA.exists():
    pass # print("itemData.json not found at", ITEMDATA)
    raise SystemExit(1)
if not ICONS_DIR.exists():
    pass # print("icons dir not found at", ICONS_DIR)
    raise SystemExit(1)

with open(ITEMDATA, "r", encoding="utf-8") as f:
    data = json.load(f)

# list icon basenames (without extension)
icon_files = [p.name for p in ICONS_DIR.glob("*.png")]
icon_basenames = set([os.path.splitext(n)[0] for n in icon_files])

pass # print(f"Found {len(icon_basenames)} icon names in {ICONS_DIR}")

# helper: detect base from name (strip _aN suffix)
def base_name(name: str) -> str:
    m = re.search(r"_a(\d+)$", name)
    if m:
        return name[: - (len(m.group(0)))]
    return name

# ensure we have templates for bases that exist in data
existing_keys = set(data.keys())

# 1) Create missing entries for icon-only names
added = []
for icon in sorted(icon_basenames):
    if icon in existing_keys:
        continue
    base = base_name(icon)
    if base in data:
        # copy and insert
        data[icon] = json.loads(json.dumps(data[base]))
        added.append(icon)
    else:
        # create minimal entry
        data[icon] = {
            "ItemCategory": "Misc",
            "StackSize": 1,
            "Description": "",
            "group": base_name(icon),
            # default: write loot_stats and merchant as plain dicts (no '0' wrapper)
            "loot_stats": {"weight": 1, "chance": 1.0, "max_stack": 1},
            "merchant": {"min_count": 1, "max_count": 1, "min_price": 1, "max_price": 1, "buy_amount": 1, "chance": 1.0, "weight": 1},
            "bound_skills": []
        }
        added.append(icon)

pass # print(f"Added {len(added)} item entries for icons (examples): {added[:10]}")

# 2) Remove entries that have no icon and no variant icon
removed = []
all_icons = icon_basenames
for key in list(data.keys()):
    if key in all_icons:
        continue
    # check variants: key_aN
    pattern = key + "_a"
    has_variant = any(n.startswith(pattern) for n in all_icons)
    if has_variant:
        continue
    # if no icon and no variant, remove
    # don't remove if key looks like a special system item (heuristic): keep if uppercase first letter is not alpha
    if re.match(r"^[A-Za-z0-9_]+$", key):
        removed.append(key)
        del data[key]

pass # print(f"Removed {len(removed)} item entries without icons (examples): {removed[:10]}")

# backup
bak = ITEMDATA.with_suffix(".json.bak")
with open(bak, "w", encoding="utf-8") as f:
    json.dump(data, f, indent=4, ensure_ascii=False)
pass # print("Backup written to", bak)

# Post-process: if loot_stats or merchant are dicts with only key '0', unwrap them
for k, v in list(data.items()):
    if not isinstance(v, dict):
        continue
    if "loot_stats" in v and isinstance(v["loot_stats"], dict):
        ls = v["loot_stats"]
        if set(ls.keys()) == {"0"} and isinstance(ls["0"], dict):
            v["loot_stats"] = ls["0"]
    if "merchant" in v and isinstance(v["merchant"], dict):
        m = v["merchant"]
        if set(m.keys()) == {"0"} and isinstance(m["0"], dict):
            v["merchant"] = m["0"]

with open(ITEMDATA, "w", encoding="utf-8") as f:
    json.dump(data, f, indent=4, ensure_ascii=False)
pass # print("Wrote updated", ITEMDATA)

pass # print("Done.")
