# BumbleJess

Bee Hive — Game Design Document (Rev B)
1) High-level

Genre: Calm real-time hive-builder roguelite
Engine: Godot 4.4.1 (2D, controller/keyboard only)
Core fantasy: Orchestrate a living hive. Shape comb, guide foragers, work magic, and marshal guards to withstand rising threats and a final industrial boss.

Pillars

Chill, not idle: Real-time flow, no hard APM or fail-by-micro—decisions compound.

Readable systems: Everything is data-driven, with small, visible cause→effect.

One input model: Arrows to move focus, Space confirm, Z back, Tab/Start open panels.

2) How it plays (the loop)

Choose a Queen (1 of 3 cards) → place at the center (Queen Seat).

Build specialized cells to form complexes (contiguous same-type groups).

Run harvests/quests from Gathering Huts; brew honey at Honey Vats; press comb at Wax Workshops; stack defense with Guard Posts; auto-gain abilities via Candle Halls.

Create Brood by enclosure (no cost). Eggs auto-assign; when ready, draft traits and hatch.

Survive rolling threats and the boss at 30:00.

Failure = hive destroyed; Success = boss phases defeated. Either way, learn, iterate, try new Queen builds.

3) Grid & complexes

Hex grid (flat-topped, axial q/r).

Complex = contiguous cluster of the same specialized cell type (visual shared outline).

The old generic adjacency speed bonus is removed. Only role-specific synergies apply.

4) Resources & items

Resources (cap-limited): Honey, Comb, Pollen, Nectar (Common).

Items (inventory): Royal Jelly (RJ). (Eggs are a Queen counter, not an item.)

Overflow rule: If production exceeds caps, excess is binned (no pause).

5) The Queen

Eggs: Lays +1 egg every 20/19/18/17/16s (tiers 1→5).

Tiering: Spend RJ to advance (T2..T5 costs 1/2/3/4 RJ).

Queen cards (total 3): Offered 3, pick 1 at run start and on each tier-up; no duplicates.

RareBias20 (+20% rare-family bias in trait drafts)

ExtraDraftCard (+1 card in drafts)

PickTwo (choose two traits on hatch)

HUD: small egg counter (used by Brood).

6) Brood (enclosure system)

Create: Any void hex fully enclosed by Specialized cells becomes Brood (no build cost).

Eggs & timer: If eggs exist, one auto-assigns to each new Brood; hatch timer starts (10s, configurable).

Ready → Draft: When done, cell shows READY; player selects to open a Trait Draft (3 cards base; +1 with card; PickTwo if owned).

Neighbor influence (edges only): Adjacent families bias the draft pool:

Guard Post→Guard, Gathering Hut→Gather, Wax Workshop→Construction, Honey Vat→Brewer, Candle Hall→Arcanist.

If ≥2 distinct families touch, 50% chance the entire draft is restricted to those families.

Break enclosure (future case): Brood → Damaged; egg lost.

7) Specialized cells (roles)
7.1 Wax Workshop — Comb production

Build: 2 Comb + 10 Pollen

Bee cap: 1 per cell

Output: Every 5s, 2 Pollen → 1 Comb (per cell)

Merge: Total output × (1 + 0.6·(size−1)) (per complex)

Synergies:

Wax↔Wax adjacency: +10% output per adjacent Wax edge (applies to each involved cell)

Trait — Construction: For the Wax complex, +5% output per assigned bee in that complex with the Construction trait (no cap)

7.2 Honey Vat — Honey & Royal Jelly

Build: 2 Comb + 5 Nectar

Bee cap: 1 per cell

Batch: 2 Nectar → 1 Honey

Batch time (size trade-off): 5s + 1s × (complex_size−1)

Local buffer: +5 Honey × complex_size (short-term spillover before caps)

Purity → Royal Jelly (per complex):

+1 Purity per batch; +10 more per batch if any Vat tile touches a Candle Hall

At 100 Purity ⇒ +1 RJ, then reset to 0

7.3 Storage — Per-producer caps

Build: 1 Comb

Rule: Each Storage edge gives +5 capacity to the linked resource(s) of an adjacent producer:

Wax Workshop → Comb

Honey Vat → Honey

Gathering Hut → Pollen and Nectar

Totals: Global cap for each resource = sum of all linked per-cell caps across producers.

7.4 Gathering Hut — Offers, auto-routing, virtual bees

Build: 2 Comb + 10 Honey

Use: Runs Harvests (trickled resources) and Item Quests (item rewards) — no passive output.

Offer slots: 2 Harvest + 2 Item Quests, +1 of each per extra Hut complex.

Start job UX: Player selects an offer; the system auto-picks the smallest eligible Hut complex (ties → earliest built).

Complex reservation: That complex is reserved until the job completes; simultaneous jobs must use different complexes.

Virtual bees: +⌊complex_size / 2⌋ to the requirement (min 0 workers after virtuals).

Trickle: 5% delay, then even per-second; overflow is binned.

7.5 Guard Post — Per-cell stored defense

Build: 3 Comb + 2 Honey + 5 Pollen

Bee cap: 1 per cell

Tick: every 5s add floor(1 × (1 + 0.10 × adj_guard_neighbors)) to this cell’s Stored Defense

Cap (per cell): max(20, 200 − 20 × adj_guard_neighbors)

Global Defense: sum of all Stored Defense (no decay)

7.6 Candle Hall — Auto rituals & rarity shaping

Build: 1 Comb + 1 Honey + 1 Pollen (configurable)

Bee cap: 1 per cell (required; reserves the bee)

Rituals: Automatic every 20s, no cost → add 1 single-use Ability to the shared list

Adjacency A (Hall↔Hall): If touching ≥1 Hall, ritual interval −5s (min 10s; no stacking)

Adjacency B (diversity): +4% rare-ability chance per unique non-Hall neighbor type (Wax, Vat, Guard, Gathering, Storage, Brood, QueenSeat)

8) Abilities (single-use)

Listed in Abilities Panel (right slide).

Each shows cost (resources/items) and effect.

Space to activate → validate → spend → apply immediately → consume the card.

Example effects: Honey +50% for 10s, Summon Common Bee, Replenish active harvest +50%.

9) Offers: Harvests & Item Quests

Visible offers: base 2 Harvest + 2 Item Quests, scaled by Hut complexes (+1 each per extra complex).

Start: select an offer → auto-assign smallest eligible Hut complex and required workers (after virtual bees).

Harvests: totals trickle in after a 5% delay, evenly over time; undelivered remainder is lost.

Item Quests: pay costs → after duration, grant Items (e.g., contract ingredients).

Replacement: on completion, the used offer disappears and is replaced by a different one.

10) Threats & boss

Regular threats: 1:00 warning, 3:00 minimal gap, power ×2 per reappearance (per threat ID).

Resolve: compare Global Defense vs Threat Power → Defended or Destroyed.

Boss: 30:00 cap, 3:00 warning, phases 1000 / 1300 / 1700 one minute apart.

UI: Bottom panel slides up on resolve, shows result + next threat countdown, slides down.

11) UI & controls

Controls: Arrows move selection focus; Space confirm/context; Z back; Tab/Start open slide-out panels (Resources, Inventory, Abilities, Offers).

Selection: Hex cursor outlines cells; panels are fully keyboard-navigable.

Tooltips: Per-cell show caps, complex size, adjacency bonuses, Purity, Stored/Cap Defense, bee assignment.

HUD: Global Defense, boss timer, active jobs cards, Queen egg count.

12) Progression & meta

RJ economy: Honey Vat Purity → Royal Jelly → Queen tiers (egg speed) and extra Queen cards.

Buildcraft: Storage placement shapes caps; complex sizing trades Vat speed for buffer; Hall placement shapes ability quality and cadence.

Run goals: Stabilize economy → grow defense → time abilities and harvests → clear boss phases.

13) Balancing knobs (data)

All tunable in JSON:

Queen: tier times, RJ costs, card pool.

Brood: hatch_seconds, neighbor restrict chance.

Wax: tick seconds, IO, merge mult, adjacency %, Construction %.

Vat: batch seconds per size, local buffer, Purity values, Hall bonus, RJ threshold.

Storage: +per-edge value; linked resources per producer type.

Hut: virtual-bee per size rule, offer slots per complex, trickle delay, pools.

Guard: build cost, tick seconds, base/adjacency cap & speed multipliers.

Hall: interval, Hall adjacency reduction, diversity rare bonus, floor.

Threats/Boss: timings, gaps, powers, phase layout.

14) Glossary

Cell: any hex tile.

Specialized Cell: a cell with a role (Wax, Vat, Storage, Gathering, Guard, Hall, Brood, QueenSeat).

Complex: contiguous group of same-type specialized cells.

Local buffer (Vat): honey held in a complex before caps apply.

Virtual bees: free requirement reduction from Hut complex size.

Stored Defense: per-Guard-cell accumulator; summed into Global Defense.
