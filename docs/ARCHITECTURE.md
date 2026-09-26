# Architecture

WorldGenerator -> WorldData -> Economy -> rendering / UI.

## World and generation

`scripts/world/world_data.gd` is a scene-independent RefCounted model. A row-major tile array stores biome, elevation, moisture, temperature, terrain type and six resource potentials. The 480 x 336 grid uses 16-world-pixel cells. `DETAIL_SCALE` is 3: noise frequency is divided by it and lake/spawn/source distances scale with it. Spawn searches sample a coarser stride to keep costs bounded. Resource values are potential, not actual inventories.

`world_generator.gd` owns noise, falloff, biome assignment, ocean flood fill, coherent-noise lake shapes and river sources. `drainage.gd` uses a binary min-heap and priority flood from sea tiles; each land cell obtains a downstream parent already connected to the sea. River paths follow cardinal parents to an ocean tile and can pass through lakes. Spill heights are virtual; elevations are not physically eroded. Repeated seeds are deterministic in the same engine version, not guaranteed across engine or generator revisions.

## Gameplay model

WorldData also owns `players`, `ownership`, `buildings`, `next_entity_id` and `tick`. Ownership maps Vector2i cells to player IDs. Players own resource stocks, population, allocated workers, last-tick deltas and a shortage warning. Buildings contain stable IDs, owner IDs, location, kind, fixed site-dependent output and current operating status. Rivers and starting settlements remain separate collections.

`scripts/systems/economy.gd` has no Node or UI dependencies. `quote` is read-only: it computes validity, exact costs, claim cells and production. `execute` revalidates using current state before deducting costs and applying one claim/build action. Never trust a stale UI quote. `trade` validates a fixed batch transaction atomically. Rule failures do not mutate stocks or ownership. All public actions take player ID; the local UI selects player 1.

Starting territory is a cardinally connected flood from the settlement, limited to a Manhattan radius of 10 cells and non-water terrain. Expansion starts only at unclaimed land directly touching the player's border, then floods unowned non-water cells within radius 4 (at most 41). It cannot jump across water or another owner's land. Mountains can be owned and mined; the older walkability flag remains for future unit movement, not construction authorization.

Production uses 5-second fixed simulation steps, driven by an accumulator in `main.gd`. Taxes and population consumption run first, then wells, farms, lumber, quarry, iron, oil and housing in stable insertion order per type. A building must afford its entire upkeep before any is deducted; otherwise it produces nothing. Stocks never go negative. Housing immediately raises population by 4. Construction and claims are instantaneous and can occur while paused. UI displays net changes from the last completed tick; purchases/trades update stocks immediately but do not alter that historical delta.

## Presentation

`world_renderer.gd` generates one nearest-filtered color texture with slight elevation shading. No smoothing shader, decorative terrain icons or per-tile nodes are used. It redraws only when terrain changes. `territory_renderer.gd` is a separate cached overlay: translucent ownership, cardinal border segments, and small letter markers for buildings. Changes to territory/buildings do not rebuild the terrain texture. Tile selection and prospective claim area are drawn by the controller.

`strategy_camera.gd` uses left/right/middle dragging with a six-pixel threshold, release-based short clicks, focus-loss cancellation and cursor-centered zoom (0.08-2.5). UI-consumed presses cannot start map gestures; captured gestures release correctly over UI.

`main.gd` composes the world, simulation, camera and views. The sidebar is scrollable, keeps real stocks distinct from tile potential, and contains market controls. The anchored bottom bar selects actions and shows a quote plus Confirm. The top bar offers pause, speed, map/home and a confirmation-protected world reset. Generation remains synchronous (~2.3 seconds on the development machine). No simulation work occurs while paused, but UI/camera remain active.

## Future multiplayer and persistence

Route the current owner/action/cell API through a server command queue when networking is added. The authority must revalidate, tick and publish snapshots/deltas; clients remain views and input. Add schema versions and serialize Vector2i ownership keys explicitly, along with stocks, entities, tick and generator version. A seed alone cannot restore economic state. Currently there is no persistence, networking, transport simulation or rollback. Global per-player stocks are deliberately simpler than future local logistics.

## Validation

`tests/smoke.gd`: six deterministic worlds, valid resources/spawn, complete non-looping sea-connected rivers, nearest rendering setup and click/drag/focus/zoom behavior.

`tests/economy.gd`: controlled terrain fixtures, rejection without spending, exact claim/build charges, duplicates, terrain/owner/workforce checks, all seven building tick balances, shortages/recovery, no negative inventories, market spread, and live scene confirmation/pause/speed/expansion. Visual mode captures full and smaller-window layouts. Tests are representative, not exhaustive fairness certification.
