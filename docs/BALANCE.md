# First playable economy

All quantities are integers. These are initial tuning values, not a final competitive balance. The source of truth is `scripts/systems/economy.gd`.

## Starting position

Money 350; Food 60; Wood 80; Stone 60; Iron 0; Oil 0; Water 50. Population 12, available workforce 12. One connected land area within Manhattan radius 10 of the starting settlement is free (up to 221 tiles, less near water). No buildings are prebuilt.

## Territory

Select Expand and unclaimed land touching your border. The preview contains up to 41 connected non-water cells within radius 4 of the target. Existing ownership, water and foreign ownership are excluded. Confirm charges only for the previewed cells, then updates the border. No recurring territory upkeep and no diagonal-only connections.

For N newly claimed cells and T currently owned cells:

- Money: `12 + N + floor(T / 150)`.
- Wood: `ceil(N / 12)`.
- Food: `ceil(N / 10)`.

Typical full 41-cell expansion from a 221-cell start costs $54, Wood 4, Food 5. Expansion cannot cross rivers/lakes/sea yet. Mountains can be claimed for mining.

## Buildings

One building per owned tile; the settlement tile is reserved. No construction time or demolition yet. `P` is the selected tile's relevant resource potential (1-5). Construction requires all listed resources and available workers. Assigned workers are not consumed each tick.

| Building | Construction cost | Terrain | Workers | Output / 5s | Upkeep / 5s |
| --- | --- | --- | ---: | --- | --- |
| Farm | $60, Wood 20, Stone 10 | Plains with Food | 2 | Food `3 + P` | $2, Water 2 |
| Lumber camp | $50, Wood 10 | Forest with Wood | 2 | Wood `3 + P` | $2, Food 1 |
| Quarry | $65, Wood 20 | Mountain with Stone | 2 | Stone `3 + P` | $3, Food 1 |
| Iron mine | $100, Wood 30, Stone 25 | Mountain with Iron | 3 | Iron `2 + P` | $4, Food 1, Water 1 |
| Well | $40, Wood 15, Stone 10 | Accessible land with water potential, or next to fresh water | 1 | Water `6 + P` | $1 |
| Housing | $80, Wood 25, Stone 20 | Accessible land | 0 | +4 population/workforce immediately | Population consumption |
| Oil pump | $150, Wood 30, Stone 40, Iron 20 | Desert with Oil | 3 | Oil `2 + P` | $5, Water 2 |

For wells, adjacency to a lake or river raises effective water potential to at least 4; sea does not count. Potential stays constant and is not depleted. Site output is captured when the building is created. No hidden adjacency bonuses.

## Population and cash flow

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

No save/load, construction timers, individual building pause/demolition, transport cost, storage limits, local inventories, depletion, combat or multiplayer. No win condition yet. Next balance work should measure time to first stable food/water chain, first mining operation and sustainable expansion before adding roads and local logistics.
