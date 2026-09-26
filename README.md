# TERRAFRONT

Single-player Godot 4 prototype of a future 2D multiplayer strategy game: geography determines the economy. Explore a procedural continent and inspect its resource potential. This prototype has no economy simulation, units, construction, combat or networking.

## Run

Requires Godot 4.3+ stable (validated with 4.7.2), standard version; no .NET or external dependencies. Import `project.godot` in Godot and press F6 on the main scene or F5 for the project. Alternatively, open a new terminal in this directory and run:

```powershell
godot --path .
```

The Godot editor includes a GDScript editor. Git is initialized locally. Generated `.godot` cache and `logs` are ignored; `.gd.uid` files should be tracked.

## Controls

| Input | Action |
| --- | --- |
| Hold left/right/middle mouse + drag | Move camera |
| Mouse wheel | Zoom around cursor |
| Middle mouse drag | Pan |
| Short left click | Inspect tile (dragging does not select) |
| Home / return button | Center settlement |
| Seed + Generate continent | Rebuild deterministic world |
| View entire continent | Fit the map next to the inspector |

## Implemented

- 160 x 112 logical grid, 48-pixel tiles; crisp nearest-neighbor terrain colors with subtle elevation shading, no smoothing shader, per-tile nodes or decorative terrain icons.
- Sea, inland lakes, ocean-connected rivers, coast, plains, forest, mountain, desert, swamp and snow.
- Elevation, moisture, temperature and terrain access in an independent world model.
- Food, Wood, Stone, Iron, Oil, Water potential from 0 to 5; values are not stockpiles.
- One owner-identified settlement marker on accessible land, favoring diverse nearby biomes.
- Seed regeneration, muted cartographic colors, light interface, mouse camera controls and tile inspection. Forests use a darker green and mountains a muted gray; no tree, peak, grass, dune or wave symbols are drawn. Only the settlement marker and tile selection overlay remain. WASD is no longer used.

The map presentation takes inspiration from OpenFront's readable terrain-color approach, using original rendering and palette. Mountain Stone/Iron values remain available in the inspector; mining is not implemented yet.

## Generation

Three seeded FastNoiseLite fields supply elevation, moisture and temperature. An elliptical falloff creates an ocean around a connected-looking continent; latitude cools northern and southern regions. Boundary-connected low tiles become sea via flood fill, while enclosed low water stays lake. A few inland basin patches improve lake visibility. A priority flood starting at the sea computes an acyclic drainage route for every land tile. Up to nine spaced highland sources follow these routes all the way to the sea, merging naturally and continuing through lakes. Routing virtually fills local depressions; it does not change the displayed terrain elevation or simulate erosion, so a route can cross an original local rise. Every recorded river ends at a sea tile.

Elevation first selects water and mountains; temperature, coast elevation and moisture select the remaining biomes. Plains favor Food, forests Wood, mountains Stone/Iron, desert deposits Oil, and fresh water Water/Food. Seeded variations keep resources uneven. Sea does not provide freshwater. No single tile has all six resources; starting surroundings are not guaranteed balanced.

## Validation

```powershell
New-Item -ItemType Directory -Force logs
godot_console --headless --path . --editor --quit --log-file logs/import.log
godot_console --headless --path . --script tests/smoke.gd --log-file logs/test.log
godot_console --path . --script tests/smoke.gd --log-file logs/visual.log -- --visual
```

Smoke checks cover six seeds, required biome presence, deterministic tiles and river paths, legal spawn, resource bounds, river continuity and sea outlets, scene startup, inspection, regeneration, zoom, all three drag buttons, click/drag separation, release over UI and focus loss. The visual run writes `logs/preview.png` and `logs/overview.png`. Assertions require an editor/debug engine build. See `docs/ARCHITECTURE.md` for extension points and limitations.

## Roadmap

1. Territory claiming and a small farm/lumber camp loop reading the existing resource model.
2. Save/load with a generation version and explicit world snapshot.
3. Roads, transportation and local production/consumption.
4. Fog of war and diplomacy.
5. Server-authoritative multiplayer for 4-12 players, after command validation and simulation ticks exist.
