# TERRAFRONT — first war prototype

A single-player Godot strategy game: build a sustainable economy, train an army and capture a rival capital. One AI opponent follows the same costs, production and combat rules as the human player. This is a playable first balance, not a finished or difficulty-tuned game.

## Run

Double-click **TERRAFRONT** on the Windows desktop. The shortcut uses the installed Godot runtime and the project in Desktop/undergrid; keep that folder in place.

Import project.godot in Godot 4 stable and press F5, or run godot --path . in this directory. Validated with Godot 4.7.2 standard. No external dependencies or downloaded artwork.

## Web build

The project exports to the browser without gameplay changes. The renderer is already
GL Compatibility, no code uses threads, and there is no file or audio access, so the
export is single-threaded. That means no `SharedArrayBuffer`, no cross-origin isolation
and no COOP/COEP response headers: the result is plain static files that any host serves.

With Godot 4.7.2 and the matching web export templates installed:

~~~bash
godot --headless --path . --export-release "Web" builds/web/index.html
python3 -m http.server 8080 --directory builds/web
~~~

The first frame in a browser shows a splash while the 480x336 world generates, because
WebAssembly runs that pass slower than native. Desktop and headless runs keep the
original synchronous path, so the test suite is unaffected.

Desktop remains the only supported target. The window minimum is 1100x850 and every
control is mouse-button or drag based, so there is no touch or mobile support.

## Docker

The image builds the web export and serves it behind nginx on port 8080. It is fully
self-contained: the build stage fetches the engine and export templates itself, so a
clean checkout builds with no Godot installed on the host.

~~~bash
docker compose up --build
~~~

Then open http://localhost:8080. Without compose:

~~~bash
docker build -t terrafront .
docker run --rm -p 8080:8080 terrafront
~~~

The first build downloads roughly a gigabyte of export templates and takes several
minutes. Later builds reuse that layer. `/healthz` returns `ok` for container health
checks.

## First match

1. Green borders are yours; red borders belong to the opponent. Your first successful construction or expansion starts both players' clocks; before then, exploration does not consume supplies.
2. Click your empty land to open construction. Start with a well, farm and lumber camp. Most buildings occupy a real 2×2 footprint: all four cells must be owned, dry and vacant; terrain and resource potential are checked at the top-left anchor.
3. Drag a building onto a green placement preview, or select it and confirm the price. Invalid drops spend nothing. Every tick lasts 5 seconds at 1x.
4. Build a barracks. It trains up to 2 soldiers per tick for $4 and 2 Food. The army also consumes Food and Money; keep production running.
5. Expand toward the enemy: single-click previews the cost; double-click adjacent free land pays once and queues expansion at one tile per 0.15 simulation seconds. Only one expansion per player can run at a time.
6. Click an enemy border, select 25%, 50% or 75% of reserve troops and press Napadni. A forecast is an estimate, not a guarantee. The remaining reserve automatically defends.
7. Attacks push a widening wave along the shared border around the clicked origin, taking casualties. Individual cells transfer at most every 0.2 simulation seconds, depending on available attack strength. Povuci napad returns survivors. A fort is now a wall along five connected boundary cells. It follows the actual outline, adds defense on those cells, and stays where built. Forests and mountains resist more strongly.
8. Click a barracks to buy equipment with Iron and Money: two levels, +20% attack progress and defense each.
9. Capture any of the enemy capital's four cells to win. Losing your capital ends the match. Simulation and purchases stop after the result.

## Controls

Selecting a building puts its placement preview under the pointer. Click valid land to build immediately; it stays selected for repeated placements. Right-click/Escape cancels. Drag-and-drop remains supported. There is no separate build confirmation.

Start with 12 workers. Buildings permanently assign their listed workers; completed houses add 4 more. Production does not consume additional workers or require free workers. Normal resource upkeep still applies. The bottom worker count is free/total.

Each previously started building of the same type adds 10% of that type's base cost to subsequent construction, rounded up per resource. Counts are separate per player and type, include unfinished buildings and do not reset when a building is lost. The construction list shows the current price.

| Input | Action |
| --- | --- |
| Hold left/right/middle mouse and drag | Pan map |
| Wheel | Zoom |
| Click owned empty land | Open contextual construction |
| Click a building | Inspect production, shortage or military function |
| Drag building from menu | Construct on a valid 2×2 owned site |
| Single / double-click adjacent free land | Preview / pay for expansion |
| Click enemy land | Attack panel; only adjacent enemy cells can be attacked |
| Right click / Escape | Cancel selection and close action panels |
| Naselje / Home | Center home capital |
| Front | Fit both capitals and the intervening front |
| Protivnik | Center enemy capital |
| Obuka: DA / NE | Enable / pause recruitment, not existing army upkeep |
| Povuci napad | Recall surviving attacking troops |
| II / play, 1x / 2x | Pause both players / change simulation speed |
| … menu | Help, seed and confirmed new match |

Construction opens in a scrollable right sidebar. Every building lists each resource as owned / required with shortages in red and exact missing amounts in tooltips. The attack panel states committed troops and the reserve left to defend; the reserve defends automatically.

The rival starts at least 95 land-route steps and 70 straight-line cells away, and considers expansion every 30 simulation seconds instead of every 15.

The compact bottom bar shows inventories, reserve/max soldiers and workers. Four icons provide home, all-direction expansion, pause and the menu; the right-hand circles open construction and trade. There is no minimap or top bar. Production and consumption are different: a farm's gross output can exceed the final inventory increase. A gold dot on a building indicates a production shortage; click to see the missing inputs. The countdown explicitly identifies paused production. Circular letter badges have been replaced with original, cached building illustrations.

## Construction and expansion

Buildings reserve costs, space and workers immediately, but only operate after their visible timer completes. Wells take 6s; farms/lumber 10s; houses 12s; quarries 14s; forts 15s; barracks 18s; mines 20s; oil pumps 24s. Pause freezes construction and 2x accelerates it.

Expansion uses a terrain-weighted, irregular frontier with a budget of 20, 40 or 80 cells (default 40), rather than a fixed shape. The bottom expansion icon previews growth around all sides; confirm in the bottom bar. Double-click adjacent neutral land for directed growth. Both sides lose actual soldiers in combat; moving dots from completed barracks are cosmetic supply-of-troops visuals, not extra units.

## Current scope

- Crisp 480×336 terrain, ten biomes, rivers connected to the sea and deterministic seed generation.
- Human plus one rival on the same land-connected component, separate starting stocks and territory.
- Nine building types: well, farm, lumber, quarry, mine, housing, oil, barracks and fort.
- Connected paid expansion, automatic economic production, workforce and market.
- Troop capacity, recruitment, upkeep/desertion, reserve, allocation, retreat, fort/terrain defense and equipment.
- Gradual attacks, destruction of captured buildings, capital victory/defeat and final-state purchase lock.
- AI sustains a basic economy, trades at normal prices, expands toward the player and attacks connected borders.
- Context controls, 2×2 previews, home/front/enemy navigation and pause.

## Validation

Run these from the project directory with the Godot console executable:

~~~powershell
godot_console --headless --path . --script tests/smoke.gd
godot_console --headless --path . --script tests/economy.gd
godot_console --headless --path . --script tests/hud.gd
godot_console --headless --path . --script tests/placement.gd
godot_console --headless --path . --script tests/production_live.gd
godot_console --headless --path . --script tests/war.gd
godot_console --headless --path . --script tests/fronts.gd
godot_console --headless --path . --script tests/compact_game.gd
~~~

Non-headless tests with -- --visual save screenshots to logs/. Placement's native drag test moves the actual cursor inside its own test window. Tests cover six seeded maps and connected rival spawns, 2×2 overlap/cost rejection, all production types, real-time inventory growth, UI bindings/layout, training and equipment charges, retreat, terrain/fort effects, victory/defeat and AI expansion/attack on the default map.

## Limits

No save/load: closing or resetting loses progress. One active attack per player; no individual units, bridges, naval combat, fog of war, diplomacy or multiplayer. Water blocks movement and expansion. Supply is global, deposits do not deplete and the market still uses unlimited fixed-price batches. Oil remains an economic placeholder rather than a military input. Equipment and forts use simple global/local modifiers, not unit classes. AI is rule-based, and long-match balance and additional seeds need more playtesting.

See docs/BALANCE.md for prices and combat formulas, and docs/ARCHITECTURE.md for implementation boundaries.
