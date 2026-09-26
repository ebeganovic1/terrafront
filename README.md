# TERRAFRONT

A single-player strategy prototype in Godot: geography determines your economy. Claim connected territory, build on suitable biomes, manage money and six resources, and trade to cover shortages. Terrain is a crisp 480 x 336 grid without decorative tree or mountain icons.

## Run

Import `project.godot` in Godot 4 stable and press F5, or run `godot --path .` in this directory. Validated with Godot 4.7.2 (standard, no .NET). No external dependencies. The included GDScript editor is sufficient.

## First five minutes

1. The green tint and border mark your territory. Drag with any mouse button to pan; scroll to zoom.
2. Click an owned tile, choose **Well**, check the cost and output, then **Confirm**. Use a tile with water potential or next to a lake/river.
3. Build a **Farm** on owned plains. A well and farm establish food/water supply.
4. Choose **Expand**, click unclaimed land directly touching your border, inspect the gold preview and price, then **Confirm**. Water cannot be claimed or crossed.
5. Expand toward forests and mountains. Build a lumber camp for wood, a quarry for stone and an iron mine for iron.
6. Use the sidebar market to buy/sell batches of 10. Housing adds population/workers and taxes, but increases food/water demand.

Every claim or building requires explicit confirmation; dragging never spends resources. Terrain potential is not your inventory: actual stocks are in **Treasury & Stores**. The right-hand change column shows the most recent tick's net change, not a forecast.

## Controls and interface

| Input | Action |
| --- | --- |
| Hold left/right/middle mouse + drag | Pan camera |
| Mouse wheel | Zoom |
| Short left click | Select tile, preview chosen action |
| Bottom action bar + Confirm | Claim or construct |
| Escape | Return to Inspect mode |
| Home / Home button | Center starting settlement |
| Map | View the whole continent |
| Pause / Resume | Stop / resume simulation, camera stays usable |
| 1x / 2x | Change simulation speed |
| New + seed | Reset world after confirmation |
| Help / costs, or hover a building button | Rules and prices |

## Economy

Start: $350, Food 60, Wood 80, Stone 60, Iron 0, Oil 0, Water 50; population/workforce 12.

A simulation tick is 5 seconds at 1x. A supplied starting settlement earns $15 and consumes 2 Food + 2 Water per tick. Production depends on the selected tile's resource potential, while upkeep and construction costs depend on building type. Buildings stop automatically if their full upkeep cannot be paid and resume when supplies recover. No stock goes negative. See **[docs/BALANCE.md](docs/BALANCE.md)** for all prices and formulas.

## Implemented

- Seeded continent, sea, lakes, nine candidate rivers routed to the sea, ten biome types and resource potential.
- 161,280 logical cells and sharp nearest filtering; no blur shader or per-tile nodes.
- Connected initial territory, paid boundary expansion with preview, tint and outline.
- Farm, lumber camp, quarry, iron mine, well, housing and oil pump.
- Stockpiles, taxes, upkeep, production, population, workforce and fixed-price market.
- Pause, 2x speed, responsive scrollable sidebar and bottom action bar.
- Independent world state, simulation rules and presentation; owner/entity IDs are retained for future multiplayer.

## Generation

Elevation, moisture and temperature noise plus continental falloff produce the biomes. Sampling is three times finer per axis than the original prototype, preserving a 7,680 x 5,376 world area. Priority-flood drainage computes complete river routes to the sea, including through lakes. Depression filling is virtual, not physical erosion. Source spacing, lake sizes and spawn search scale with resolution. Generation takes approximately 2.3 seconds on the development machine and remains synchronous.

## Validation

```powershell
godot_console --headless --path . --editor --quit
godot_console --headless --path . --script tests/smoke.gd
godot_console --headless --path . --script tests/economy.gd
```

Add `-- --visual` to a non-headless test run to save screenshots in `logs/` (create that folder first). Smoke tests cover six seeds, determinism, resources, river connectivity, spawn, rendering setup and camera input. Economy tests check rejected operations, exact spending, every building's output/upkeep, workforce, shortages/recovery, trade, confirmation, pause and speed. `.godot/` and `logs/` are ignored by Git; Godot UID files are tracked.

## Prototype limits and next steps

No save/load yet: closing the game or confirming New loses the current session. No demolition, construction timers, roads, transport, combat, competing players or networking. Stocks are global per player, deposits do not deplete, buildings complete immediately, market supply is unlimited and workers are allocated automatically. Mountains can be claimed and mined even though the future unit traversal flag marks them impassable. Water currently blocks expansion; bridges and shipping are future work. This is a first playable balance, not a tuned 30-60 minute match.

Next: save/load, building management, then roads and resource transport before multiplayer.
