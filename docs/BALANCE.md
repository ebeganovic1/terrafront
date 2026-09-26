# First playable economy

All quantities are integers. These are initial tuning values, not a final competitive balance. The source of truth is `scripts/systems/economy.gd`.

## Starting position

Money 350; Food 60; Wood 80; Stone 60; Iron 0; Oil 0; Water 50. Population 12, available workforce 12. One connected land area within Manhattan radius 10 of the starting settlement is free (up to 221 tiles, less near water). No buildings are prebuilt.

## Territory

Select Expand and unclaimed land touching your border. The preview contains up to 20, 40 (default) or 80 connected non-water cells, using terrain-weighted irregular growth rather than a fixed radius. Selecting owned land seeds neutral neighbors around the whole territory; neutral border targets direct the wave locally. Existing ownership, water and foreign ownership are excluded. Confirm charges for the previewed cells and enqueues a wave. One cell is claimed every 0.15 simulation seconds, only while still neutral, dry and connected to the owner. One wave per player is allowed; duplicate orders are rejected without spending. At completion, blocked cells receive a proportional refund (rounded down per resource). No recurring territory upkeep and no diagonal-only connections.

For N newly claimed cells and T currently owned cells:

- Money: `12 + N + floor(T / 150)`.
- Wood: `ceil(N / 12)`.
- Food: `ceil(N / 10)`.

Typical full 40-cell expansion from a 221-cell start costs $53, Wood 4, Food 5. Expansion cannot cross rivers/lakes/sea yet. Mountains can be claimed for mining.

## Buildings

Current pricing: cost per resource is ceil(base cost × (1 + 0.10 × previously started buildings of this type)). Counts are per player, include construction jobs and persist after destruction. Rejected placements do not increment counts.

Workers remain assigned from construction onward; completing construction does not release them. New construction requires enough free workers, but production never charges workers again or requires additional free workers. Houses add four population/workers only on completion. UI worker counts show free/total.

Buildings reserve four owned, dry cells in a 2×2 footprint. Both capital footprints are reserved. The top-left anchor determines terrain and production potential. Construction reserves costs, cells and workers immediately. Timers in simulation seconds: well 6, farm/lumber 10, house 12, quarry 14, fort 15, barracks 18, mine 20, oil 24. Pending buildings provide no output, housing population, training or military capacity. Pending forts provide no defense. No demolition yet. `P` is the selected tile's relevant resource potential (1-5). Construction requires all listed resources and available workers. Assigned workers are not consumed each tick.

| Building | Construction cost | Terrain | Workers | Output / 5s | Upkeep / 5s |
| --- | --- | --- | ---: | --- | --- |
| Farm | $60, Wood 20, Stone 10 | Plains with Food | 2 | Food `3 + P` | $2, Water 2 |
| Lumber camp | $50, Wood 10 | Forest with Wood | 2 | Wood `3 + P` | $2, Food 1 |
| Quarry | $65, Wood 20 | Mountain with Stone | 2 | Stone `3 + P` | $3, Food 1 |
| Iron mine | $100, Wood 30, Stone 25 | Mountain with Iron | 3 | Iron `2 + P` | $4, Food 1, Water 1 |
| Well | $40, Wood 15, Stone 10 | Accessible land with water potential, or next to fresh water | 1 | Water `6 + P` | $1 |
| Housing | $80, Wood 25, Stone 20 | Accessible land | 0 | +4 population/workforce on completion | Population consumption |
| Oil pump | $150, Wood 30, Stone 40, Iron 20 | Desert with Oil | 3 | Oil `2 + P` | $5, Water 2 |

For wells, adjacency to a lake or river raises effective water potential to at least 4; sea does not count. Potential stays constant and is not depleted. Site output is captured when the building is created. No hidden adjacency bonuses.

## Population and cash flow

Before the first successful construction or expansion, the game clock waits: no taxes, consumption or production are applied while exploring the starting map. After that action, both players use the normal recurring rules below. A stopped building exposes the exact missing upkeep quantities; construction does not waive upkeep.

A tick is 5 real seconds at 1x, 2.5 seconds at 2x. Pause stops ticks. Each player first pays `ceil(population / 6)` Food and the same amount of Water. With enough of both at the start of the tick, tax income is `$15 + $3 per housing building`. With a shortage, income falls to $4; available Food/Water is consumed down to zero. No deaths or debt in this version.

Then buildings run in order: wells, farms, lumber, quarries, iron mines, oil pumps, housing. If an individual building cannot afford its full upkeep, it spends nothing and produces nothing that tick; it resumes automatically when supplies recover. Wells can supply farms during the same tick. Population consumption happens before production. Building inspection reports its last status.

Starting example: a Food-potential-5 farm produces 8 Food; a water-potential-2 well produces 8 Water. Together they require 3 workers and, including population, net +12 Money, +6 Food and +4 Water per tick. Housing adds +3 tax and 4 workers, but can increase the rounded population consumption.

## Market

Trade batches are always 10 units. Buying costs two more Money per unit than selling earns. No free round-trip arbitrage. Supply is unlimited for this single-player prototype; prices do not react to demand.

| Resource | Sell 10 for | Buy 10 for |
| --- | ---: | ---: |
| Food | $20 | $40 |
| Wood | $30 | $50 |
| Stone | $30 | $50 |
| Iron | $60 | $80 |
| Oil | $80 | $100 |
| Water | $10 | $30 |

Trades fail without enough money/stock and change nothing. Market recovery is intentionally possible even when local resource geography is poor. The minimum tax of $4 prevents permanent insolvency, though recovery can take multiple ticks.

## What is deliberately absent

No save/load, individual building demolition, transport cost, storage limits, local inventories, depletion or multiplayer. Military balance is an initial prototype; measure match length and sustainable army sizes before adding more opponents or unit classes.

## First war balance

Each player starts with 12 reserve soldiers and identical economic stocks. The first successful human construction or expansion starts the shared clock. The rival spawns on the same dry-land component, at least 95 route steps and 70 straight-line cells away. AI expansion is considered every sixth economic tick (30 simulation seconds). Pause stops both players.

- Barracks: $100, Wood 30, Stone 15; two assigned workers. Each trains up to two soldiers per tick, $2 and one Food per recruited soldier. Training can be paused globally.
- Capacity: population × 2 + 12 per barracks, counting reserve plus deployed soldiers. Above-cap survivors remain alive but no additional soldiers train.
- Army upkeep: ceil(total / 12) Food and ceil(total / 15) Money per tick. If the full cost is unavailable, one soldier deserts instead; no negative stocks.
- Fort: $90, Wood 15, Stone 35; builds a connected five-cell wall on the owned boundary, using eight-neighbor continuity to follow staircase corners. Each wall cell adds 8 defense only on that cell. The footprint must contain five vacant boundary cells. Walls retain their original physical edge segments after further expansion and are destroyed when captured.
- Equipment: level 1 costs $80 and Iron 15; level 2 costs $160 and Iron 30. Each adds 20% to attack progress and defense, maximum two levels. Requires a barracks.
- Attacks commit floor(reserve × chosen share), share 25/50/75%, minimum four soldiers. One active attack per player. No resources are charged just to preview.
- Base defense: 3 + 0.25 × reserve, plus 14 on capital cells, plus 8 on a wall cell. Multiply by 1.25 in forest or 1.7 in mountains, then by equipment.
- Each combat tick: attacker loses at least one soldier (ceil(defense / 8)); defender loses at least one (floor(attacking troops / 10)), clamped to available troops, drawing from reserve first and then deployed forces. Both armies track cumulative losses.
- Every economic tick sets a continuous attack rate of surviving troops × 1.8 × equipment modifier / 5 per second. Progress accumulates between ticks; a cell costs defense × 1.5 and at most one cell transfers per 0.2 simulation seconds. Candidates are enemy cells adjacent to the attacker, ordered radially around the original clicked point, producing a widening front rather than a capital-directed tunnel. Animation does not reapply recruitment or casualty charges.
- Attacks under two surviving soldiers return survivors. Manual retreat returns all survivors. Loss of adjacency or a changed target owner also returns the force.
- Captured buildings are destroyed, not duplicated or inherited. Workers are released; lost completed housing removes its four population.
- Capturing any capital footprint cell immediately wins. Economy, AI and combat freeze and further purchases are rejected.

Army and AI costs are included in the controller's tick delta; model-only economy tests intentionally exclude military costs. Market prices remain fixed in this iteration. No 20–30 minute duration guarantee has been established.
