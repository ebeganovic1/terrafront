# Architecture

## Data flow

WorldGenerator -> WorldData -> gameplay systems -> renderer / UI.

`scripts/world/world_data.gd` is a RefCounted model, independent of the scene tree. Tiles use a flat row-major array (`y * WIDTH + x`). Every tile has biome ID, elevation, moisture, temperature, terrain type and six integer resource potentials. WorldData also owns the seed and settlement records with independent entity/owner IDs. A settlement is only a start marker, not a city simulation.

`scripts/world/world_generator.gd` owns seeded FastNoiseLite fields, continental falloff, biome classification, ocean flood fill, inland lake patches and strictly descending rivers. Rivers can terminate in single-tile sink lakes or existing river networks. Extra lake patches are an MVP approximation, not full depression filling. Each random phase has a separate seed offset. Repeatability is tested within the installed engine; cross-version noise identity is not promised.

`scripts/systems/resource_system.gd` maps biome IDs to six resource baselines, applies seeded bounded variation, and makes desert oil sparse. Resource order is Food, Wood, Stone, Iron, Oil, Water. Mountains and water are inaccessible; coast, plains, forest, desert, swamp and snow are accessible. Traversal costs and extraction are future systems.

## Presentation

`scripts/map/world_renderer.gd` builds a color texture from the logical grid, with depth and elevation shading. A Sprite2D and `assets/terrain.gdshader` interpolate colors, perturb edges and add fine texture. Cached CanvasItem commands draw detailed antialiased trees, peaks, dunes and water marks over that surface. Logical tiles are now 48 pixels wide, while the 160 x 112 simulation grid is unchanged. This is higher visual detail, not additional simulation cells. It redraws only after generation. Selection is drawn above terrain on the parent, so clicks do not rebuild terrain. There is no Node per tile. For much larger worlds, split presentation into visible chunks without changing the model. Soft visual boundaries are decorative; the selected logical tile remains authoritative.

`scripts/camera/strategy_camera.gd` owns mouse pan, cursor-centered zoom and world-center limits. Unhandled left/right/middle presses start a gesture only outside UI. Motion beyond six viewport pixels becomes a drag. A short left-button release emits a world-position inspection signal; a drag never selects. Once captured, motion/release use `_input`, including over UI, and window focus loss cancels the gesture. WASD bindings are removed. Zoom ranges from 0.12 to 2.5; an overview button fits the continent alongside the inspector. Limits constrain the camera center, so background can be visible at world edges.

`scripts/main.gd` composes model, renderer, camera and a light-themed CanvasLayer inspector. Generation is synchronous for this bounded MVP map. Resource values are displayed only in the tile inspector. Terrain details are code-native placeholders; no external art is required. The viewport uses canvas-item scaling and per-primitive antialiasing on curves/lines. Compatibility rendering does not support 2D MSAA, so it remains disabled. Minimum window size keeps the inspector readable.

## Future systems and multiplayer

Keep ownership and entities in WorldData, and keep gameplay rules out of renderer/UI. Future player actions should be commands containing player ID, action type, target and payload. A simulation layer validates commands, applies them on fixed ticks and emits model changes; rendering consumes those changes. Roads, factories, units, transport and territories should use separate model collections indexed by stable IDs/cells.

For server authority, run command validation and simulation only on the server, transmit snapshots plus ordered deltas, and treat clients as presentation/input. Use a versioned snapshot including resource values and ownership; a seed alone is insufficient once the world changes or generator versions differ. No networking, local-player singleton, transport abstraction or speculative server infrastructure is implemented now.

## Validation and limitations

`tests/smoke.gd` tests representative seeds, deterministic data, biome presence, ranges, spawn access and scene/camera operations. It is not exhaustive seed certification or a network determinism test. Future work should improve river lengths and watershed behavior, spawn fairness, screen-size adaptation and large-map rendering before scaling the world. There is no economy or claim system yet.
