# Architecture

## Data flow

WorldGenerator -> WorldData -> gameplay systems -> renderer / UI.

`scripts/world/world_data.gd` is a RefCounted model, independent of the scene tree. Tiles use a flat row-major array (`y * WIDTH + x`). Every tile has biome ID, elevation, moisture, temperature, terrain type and six integer resource potentials. WorldData also owns the seed and settlement records with independent entity/owner IDs. A settlement is only a start marker, not a city simulation.

`scripts/world/world_generator.gd` owns seeded FastNoiseLite fields, continental falloff, biome classification, ocean flood fill, inland lake patches and river source selection. `scripts/world/drainage.gd` runs a priority flood from sea tiles with a binary min-heap in O(N log N). Every discovered tile receives a downstream parent already connected to the sea; strictly increasing virtual spill heights resolve depressions and flat regions without cycles. Source paths follow cardinal parents to the ocean, preserving lake tiles and merging shared river segments. `WorldData.river_paths` stores complete source-to-sea paths. Virtual filling is for routing only: original elevations are not rewritten, and this is not erosion simulation. Each random phase has a separate seed offset. Repeatability is tested within the installed engine; cross-version noise identity is not promised.

`scripts/systems/resource_system.gd` maps biome IDs to six resource baselines, applies seeded bounded variation, and makes desert oil sparse. Resource order is Food, Wood, Stone, Iron, Oil, Water. Mountains and water are inaccessible; coast, plains, forest, desert, swamp and snow are accessible. Traversal costs and extraction are future systems.

## Presentation

`scripts/map/world_renderer.gd` builds a color texture from the logical grid, with restrained depth and elevation shading. Forests are darker green surfaces and mountains muted gray surfaces with slight height variation. A Sprite2D uses explicit nearest-neighbor filtering with no material or smoothing shader: biome boundaries remain sharp and match the logical cells. The grid now has 480 x 336 cells, each 16 world pixels wide, preserving the previous 7,680 x 5,376 extent with nine times the terrain samples. Decorative terrain icons are removed; the only cached draw commands mark settlements. Selection is drawn above terrain on the parent, so clicks do not rebuild terrain. There is no Node per tile. For much larger worlds, split presentation into visible chunks without changing the model. Resource rules and traversal rules remain unchanged; resources are assigned after river generation, and mining remains future gameplay.

`WorldData.DETAIL_SCALE` controls generation sampling density. Noise frequencies are divided by it; lake radii, source spacing and spawn neighborhood distances are multiplied by it. Spawn candidates and neighboring sample points use a matching stride to bound search work while preserving the physical search radius. Lake edge noise is spatially coherent. Rivers use the fine cardinal grid and remain connected to the sea. This changes seed output relative to earlier versions; no saved-world compatibility is promised yet. Rendering tests assert texture dimensions and nearest filtering without a smoothing material. Measured generation is about 2.3 seconds on the development machine, so regeneration remains synchronous for now.

`scripts/camera/strategy_camera.gd` owns mouse pan, cursor-centered zoom and world-center limits. Unhandled left/right/middle presses start a gesture only outside UI. Motion beyond six viewport pixels becomes a drag. A short left-button release emits a world-position inspection signal; a drag never selects. Once captured, motion/release use `_input`, including over UI, and window focus loss cancels the gesture. WASD bindings are removed. Zoom ranges from 0.12 to 2.5; an overview button fits the continent alongside the inspector. Limits constrain the camera center, so background can be visible at world edges.

`scripts/main.gd` composes model, renderer, camera and a light-themed CanvasLayer inspector. Generation is synchronous for this bounded MVP map. Resource values are displayed only in the tile inspector. Terrain details are code-native placeholders; no external art is required. The viewport uses canvas-item scaling and per-primitive antialiasing on curves/lines. Compatibility rendering does not support 2D MSAA, so it remains disabled. Minimum window size keeps the inspector readable.

## Future systems and multiplayer

Keep ownership and entities in WorldData, and keep gameplay rules out of renderer/UI. Future player actions should be commands containing player ID, action type, target and payload. A simulation layer validates commands, applies them on fixed ticks and emits model changes; rendering consumes those changes. Roads, factories, units, transport and territories should use separate model collections indexed by stable IDs/cells.

For server authority, run command validation and simulation only on the server, transmit snapshots plus ordered deltas, and treat clients as presentation/input. Use a versioned snapshot including resource values and ownership; a seed alone is insufficient once the world changes or generator versions differ. No networking, local-player singleton, transport abstraction or speculative server infrastructure is implemented now.

## Validation and limitations

`tests/smoke.gd` tests representative seeds, deterministic data, biome presence, ranges, spawn access and scene/camera operations. River validation checks highland sources, cardinal connectivity, water-only routes, no loops, sea endpoints and coverage of every river tile. It is not exhaustive seed certification or a network determinism test. Future work should improve physical riverbed erosion, spawn fairness, screen-size adaptation and large-map rendering before scaling the world. There is no economy or claim system yet.
