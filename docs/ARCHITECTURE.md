# Architecture

WorldGenerator -> WorldData -> Economy + War/AI -> rendering / UI.

## World and generation

`scripts/world/world_data.gd` is a scene-independent RefCounted model. A row-major tile array stores biome, elevation, moisture, temperature, terrain type and six resource potentials. The 480 x 336 grid uses 16-world-pixel cells. `DETAIL_SCALE` is 3: noise frequency is divided by it and lake/spawn/source distances scale with it. Spawn searches sample a coarser stride to keep costs bounded. Resource values are potential, not actual inventories.

`world_generator.gd` owns noise, falloff, biome assignment, ocean flood fill, coherent-noise lake shapes and river sources. `drainage.gd` uses a binary min-heap and priority flood from sea tiles; each land cell obtains a downstream parent already connected to the sea. River paths follow cardinal parents to an ocean tile and can pass through lakes. Spill heights are virtual; elevations are not physically eroded. Repeated seeds are deterministic in the same engine version, not guaranteed across engine or generator revisions.

## Gameplay model

WorldData also owns `players`, `ownership`, `buildings`, `next_entity_id` and `tick`. Ownership maps Vector2i cells to player IDs. Players own resource stocks, population, allocated workers, last-tick deltas and a shortage warning. Buildings contain stable IDs, owner IDs, location, kind, fixed site-dependent output and current operating status. Rivers and starting settlements remain separate collections.

`scripts/systems/economy.gd` has no Node or UI dependencies. `quote` is read-only: it computes validity, exact costs, claim cells and production. `execute` revalidates using current state before deducting costs and applying one claim/build action. Never trust a stale UI quote. `trade` validates a fixed batch transaction atomically. Rule failures do not mutate stocks or ownership. All public actions take player ID; the local UI selects player 1.

Starting territory is a cardinally connected flood from the settlement, limited to a Manhattan radius of 10 cells and non-water terrain. Expansion uses terrain-weighted frontier growth with a 20/40/80-cell budget. Neutral targets must touch the border; owned targets seed all neutral cardinal neighbors around the territory. It cannot jump across water or another owner's land. Mountains can be owned and mined; the older walkability flag remains for future unit movement, not construction authorization.

Production uses 5-second fixed simulation steps, driven by an accumulator in `main.gd`. Taxes and population consumption run first, then wells, farms, lumber, quarry, iron, oil and housing in stable insertion order per type. A building must afford its entire upkeep before any is deducted; otherwise it produces nothing. Stocks never go negative. Housing immediately raises population by 4. Construction is instantaneous; claims are queued and advanced at 0.15-second intervals and can occur while paused. UI displays net changes from the last completed tick; purchases/trades update stocks immediately but do not alter that historical delta.

## Presentation

`world_renderer.gd` generates one nearest-filtered color texture with slight elevation shading. No smoothing shader, decorative terrain icons or per-tile nodes are used. It redraws only when terrain changes. `territory_renderer.gd` is a separate cached overlay: translucent ownership, cardinal borders, and original 2×2 SVG building illustrations with shortage dots. The overlay refreshes after economic ticks without rebuilding terrain. Tile selection, prospective claims and green/red placement ghosts are drawn by the controller.

Building buttons forward native GUI drag data to `building_drop.gd`, a full-screen drop target underneath HUD panels, activated only during dragging. Hover quotes are read-only; a drop revalidates through `Economy.execute`. The camera cancels captured gestures at drag start. Release-based double-click signals expand only adjacent unclaimed land through the same validated economy API. Dragged map gestures never count as double-clicks. The click/confirm workflow remains available.

`strategy_camera.gd` uses left/right/middle dragging with a six-pixel threshold, release-based short clicks, focus-loss cancellation and cursor-centered zoom (0.08-2.5). UI-consumed presses cannot start map gestures; captured gestures release correctly over UI.

`main.gd` composes the world, simulation, camera and `scripts/ui/game_hud.gd`. The HUD emits intents (action, confirm, trade, pause, speed, navigation and new-world); the controller applies gameplay rules and supplies refreshed state. A compact bottom dock holds stocks, reserve/capacity, workers and four controls. The two right-side circles open construction and trade; military options live in the menu. Costs and confirmation appear only during a planned action. Long details live in tooltips, and toast messages expire after five seconds even while paused. Labels are Bosnian without changing model IDs. `hud_icons.gd` creates and caches original SVG interface icons; no external assets are used. Terrain artwork is unaffected. Generation remains synchronous (~2.3 seconds on the development machine). Pausing or the reset confirmation dialog stops simulation; camera/UI remain active.

## Future multiplayer and persistence

Route the current owner/action/cell API through a server command queue when networking is added. The authority must revalidate, tick and publish snapshots/deltas; clients remain views and input. Add schema versions and serialize Vector2i ownership keys explicitly, along with stocks, entities, tick and generator version. A seed alone cannot restore economic state. Currently there is no persistence, networking, transport simulation or rollback. Global per-player stocks are deliberately simpler than future local logistics.

## Validation

`tests/smoke.gd`: six deterministic worlds, valid resources/spawn, complete non-looping sea-connected rivers, nearest rendering setup and click/drag/focus/zoom behavior.

`tests/economy.gd`: controlled terrain fixtures, rejection without spending, exact claim/build charges, duplicates, terrain/owner/workforce checks, all nine building tick balances, shortages/recovery, no negative inventories, market spread, and live scene confirmation/pause/speed/expansion. Visual mode captures full and smaller-window layouts. Tests are representative, not exhaustive fairness certification.

`tests/hud.gd`: actual control signals for every build action, no spending on selection, exclusive popup opening, localized dropdown-to-resource mapping, exact market transactions, Escape, pause/speed and toast expiry. Visual runs assert viewport containment at the minimum window size and capture the clean dock, build palette and market.

`tests/placement.gd`: construction previews and charges, duplicate/outside rejection, lumber output reaching visible inventory, double-click expansion and pan rejection. A non-headless run additionally drives native button-to-map dragging; `-- --visual` saves a screenshot. The native test moves the cursor inside its test window because Godot drop coordinates use the real pointer.

## War and 2×2 placement

WorldData now also stores armies, battles, winner, war_started and the connected enemy_route. War.setup uses cardinal BFS on dry terrain to find a rival capital at least 95 land steps and 70 straight-line cells away, initializes the second player with normal starting resources, and records the route back to the human capital. Failure to find a suitable rival is exposed in the HUD rather than fabricating disconnected combat. Six test seeds currently pass.

Economy.footprint is the authoritative four-cell occupancy helper. Construction rejects water, unowned cells, map-edge overflow, any existing building and both capitals across all four cells. Walls instead validate five connected, vacant owned boundary cells. Only the top-left anchor determines biome/potential. building_at supports inspection on any of the four cells. Capturing any occupied cell destroys the building and frees its workers; completed housing loss reduces population.

Each controller tick snapshots stocks, runs Economy.step, War.step, then War.ai_step, and recomputes net resource deltas. War owns reserve/deployed troop counts, military upkeep/desertion, capped recruitment, equipment purchases, attack validation, terrain/fort defense, gradual progress and casualties. Commit and retreat move troops between reserve and battles without duplication. Ownership is revalidated during combat. Victory stops simulation and rejects subsequent economic purchases.

AI uses the same Economy.quote/execute/trade and War.attack APIs. It prioritizes a well, farm, lumber, barracks, a second farm and a fort, buys missing materials only at normal market prices, sells surplus, follows its connected land route and attacks a weak neighboring enemy cell. There are no hidden resource grants. The default map simulation test verifies expansion and an actual attack; this is not a general difficulty or strategy guarantee.

HUD attack fraction, retreat, training, equipment and navigation emit intents to main. Context clicks replace explicit inspection/expansion mode selection. Building art is generated from local SVG strings in building_art.gd. The legacy minimap script is no longer instantiated. No external assets or network are required.

tests/war.gd validates 2×2 occupancy/capital protection, paid training/equipment, bounded upgrades, troop allocation, rejection, retreat, fort/terrain multipliers, both victory outcomes, post-game locks and AI solvency/expansion/attack. tests/production_live.gd waits for actual engine frames and verifies inventory/HUD growth including military food consumption.

## Animated fronts and construction sidebar

WorldData stores expansion jobs plus wall ownership and original edge geometry. Economy.execute charges an expansion once and queues it; Economy.advance_expansion(delta) claims one neutral connected cell per 0.15 simulation seconds and refunds proportional blocked-cell costs on completion. Duplicate owner jobs are rejected. War.step handles upkeep, recruitment and casualties every five seconds, setting an attack rate. War.advance_front(delta) accrues progress and captures eligible border cells at most every 0.2 seconds in radial order around the attack origin. The controller calls both only while unpaused and before game end, at the selected game speed. Capture destroys walls. Repeated animations do not duplicate economic charges.

The right construction sidebar uses a scrollable list of original building art and per-resource owned/required/shortage labels. Tests/fronts.gd checks asynchronous growth, blocked duplicate orders, contour walls, broad rather than tunnel-like capture, victory freeze, distant spawn and visible resource deficits. tools/create_icon.gd generates the native .ico used by the desktop shortcut.

## Compact UI and continuous construction

`compact_layout.gd` builds the bottom-only resource/army/workforce HUD, four controls and the two right-side popup buttons. No minimap is instantiated. Construction entries use two rows; exact shortages are available as tooltips. Military and navigation options live in the scrollable menu.

`Economy.advance_construction` advances reserved building and wall jobs using simulation delta. Production and barracks capacity ignore pending jobs; population is granted once housing completes. `claim_cells` uses a bounded terrain-weighted frontier with directional or all-border seeds. `army_renderer.gd` draws cosmetic moving dots along connected friendly routes from completed barracks; model troop counts are only changed by military logic. Pause freezes these animations along with construction and fronts.
