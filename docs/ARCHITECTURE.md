# Architecture

## Data flow

WorldGenerator -> WorldData -> gameplay systems -> renderer / UI.

`scripts/world/world_data.gd` is a RefCounted model, independent of the scene tree. Tiles use a flat row-major array (`y * WIDTH + x`). Every tile has biome ID, elevation, moisture, temperature, terrain type and six integer resource potentials. WorldData also owns the seed and settlement records with independent entity/owner IDs. A settlement is only a start marker, not a city simulation.

`scripts/world/world_generator.gd` owns seeded FastNoiseLite fields, continental falloff, biome classification, ocean flood fill, inland lake patches and strictly descending rivers. Rivers can terminate in single-tile sink lakes or existing river networks. Extra lake patches are an MVP approximation, not full depression filling. Each random phase has a separate seed offset. Repeatability is tested within the installed engine; cross-version noise identity is not promised.

`scripts/systems/resource_system.gd` maps biome IDs to six resource baselines, applies seeded bounded variation, and makes desert oil sparse. Resource order is Food, Wood, Stone, Iron, Oil, Water. Mountains and water are inaccessible; coast, plains, forest, desert, swamp and snow are accessible. Traversal costs and extraction are future systems.

## Presentation

`scripts/map/world_renderer.gd` uses Godot's cached CanvasItem draw commands to paint the grid and placeholder details. It is a tile-based renderer without TileMapLayer or an external atlas, using one Node2D for the entire map. It redraws only after generation. Selection is a separate lightweight drawing in `scripts/main.gd`, so clicks do not rebuild terrain. There is no Node per tile. At significantly larger map sizes, replace the renderer with chunked TileMapLayer instances and generated/imported atlases; the model does not change.

`scripts/camera/strategy_camera.gd` owns pan, cursor-centered zoom and world-center limits. It suppresses WASD when the seed field has focus. It accepts unhandled mouse events so UI clicks do not inspect terrain. The limits constrain the camera center, so the background can be visible near world edges.

`scripts/main.gd` composes model, renderer, camera and CanvasLayer inspector. Generation is synchronous for this bounded MVP map. Resource values are displayed only in the tile inspector. Pixel shapes are code-native placeholders; no external art is required.

## Future systems and multiplayer

Keep ownership and entities in WorldData, and keep gameplay rules out of renderer/UI. Future player actions should be commands containing player ID, action type, target and payload. A simulation layer validates commands, applies them on fixed ticks and emits model changes; rendering consumes those changes. Roads, factories, units, transport and territories should use separate model collections indexed by stable IDs/cells.

For server authority, run command validation and simulation only on the server, transmit snapshots plus ordered deltas, and treat clients as presentation/input. Use a versioned snapshot including resource values and ownership; a seed alone is insufficient once the world changes or generator versions differ. No networking, local-player singleton, transport abstraction or speculative server infrastructure is implemented now.

## Validation and limitations

`tests/smoke.gd` tests representative seeds, deterministic data, biome presence, ranges, spawn access and scene/camera operations. It is not exhaustive seed certification or a network determinism test. Future work should improve river lengths and watershed behavior, spawn fairness, screen-size adaptation and large-map rendering before scaling the world. There is no economy or claim system yet.
