# Sprouts — Design Document (Developer Summary + Full Design)

## Developer Summary

### Repository Layout

```
sprouts/
├─ seeds/
│  └─ demo_forest_seed.json
godot/
├─ project.godot
├─ autoload/
├─ data/
├─ scenes/
│  ├─ main.tscn
│  ├─ world/
│  ├─ battle/
│  └─ ui/
├─ scripts/
│  ├─ world/
│  ├─ tiles/
│  ├─ battle/
│  ├─ sprouts/
│  └─ ui/
├─ assets/
├─ tests/
└─ addons/
ci/
└─ github/
```

### Core Gameplay Overview
* **Genre:** Turn-based forest regrowth roguelite
* **Goal:** Restore the forest by placing life-giving tiles, nurturing Sprouts, and defeating Decay Totems.
* **Core Loop:** Place → World Updates → Every 3 Turns: Totem Generates New Tiles → Manage Sprouts → Battle Decay.
* **Victory:** All Decay Totems destroyed.
* **Defeat:** Totem consumed by Decay or deck exhausted.

### Key Systems at a Glance

* **Tiles:** 7 primary categories (Harvest, Build, Refine, Storage, Guard, Upgrade, Chanting).

  * Placed adjacent to existing tiles.
  * Enclosed spaces become Overgrowth → Groves (spawns Sprouts).
* **Totem:** Central life anchor; generates tile packs every 3 turns. Evolves with Life Essence.
* **Sprouts:** Global roster; battle automatically, level via resources or Soul Seeds.
* **Decay Totems:** Spread corruption every 3 turns and launch up to 3 attacks per global turn.
* **Resources:** Nature, Earth, Water, and Life Essences used for evolution and upgrades.

### Core Data Structure

All systems are data-driven and reference content by ID for modular updates.

| Module            | Description                                       |
| ----------------- | ------------------------------------------------- |
| **tiles.json**    | Tile types, adjacency rules, and pack definitions |
| **totems.json**   | Totem data, upgrades, and generation behavior     |
| **sprouts.json**  | Sprout IDs, stats, passives, attacks              |
| **attacks.json**  | Cooldowns, target rules, effects                  |
| **passives.json** | Trigger conditions and scaling                    |
| **maps.json**     | World size, Totem/Decay positions                 |
| **decay.json**    | Spread speed, aggression scaling                  |

### Battle Summary

* **Formation:** 6 units per side (3 front / 3 back).
* **Mechanics:** Auto-attacks based on cooldown; passives trigger on hit/heal/death.
* **End Condition:** One side fully defeated.
* **Rewards:** Life Essence and possible Relic drops.
* **No XP:** Sprouts only level via resources or Soul Seeds.

### Design Goals & Balance Notes

* Preserve 3-turn rhythm for clear pacing.
* Focus on adjacency logic, visual feedback, and world readability.
* Allow content expansion (tiles, attacks, variants) purely via data updates.
* Support roguelite replayability through Totem and map seed variety.

---

## Full Design Document

### 1) High-Level Overview

**Genre:** Turn-based forest regrowth roguelite
**Engine:** Godot 4.4.1 (2D, controller/keyboard only)
**Core Fantasy:** Restore a fallen forest by nurturing life and holding back the Decay. Each tile placement advances time, allowing new growth, Sprout awakening, and strategic battles for survival.

#### Design Pillars

* **Calm Strategy:** Every turn matters — no time pressure, only meaningful decisions.
* **Readable Systems:** Clear, visual cause and effect with minimal hidden rules.
* **Simple Inputs:** Arrows move, Space confirms, Z cancels, Tab/Start opens panels.

---

### 2) Gameplay Loop

**Start of Run**

1. Choose a **Totem** (placement determined by map seed).
2. For each tile category — Harvest, Build, Refine, Storage, Guard, Upgrade, and Chanting — pick one of three variant cards. These define that tile’s behavior for the run.
3. A starting **Tile Deck** of 30 tiles is created (default: 8H/6B/4R/4G/3S/3U/1C) based on your chosen variants.

**During Play**

* Place one tile per turn, adjacent to existing tiles.
* Turns advance: Overgrowth matures, Decay spreads, resources generate.
* Every **3 turns**, the Totem generates new tile packs for selection.

**Totem Tile Generation**

* Every 3 turns, a **Tile Choice Window** opens.
* Choose one of three **tile packs** (examples: 2 Harvest + 1 Build, 1 Refine + 1 Chanting, or a Special Tile).
* The chosen pack is added to the deck and shuffled.
* **Special Tiles** are **bonus additions** — they do not replace deck slots and must be placed immediately.

**End Conditions**

* **Victory:** All Decay Totems are destroyed.
* **Defeat:** Your Totem is consumed by Decay or the deck is exhausted.

---

### 3) Map & Structure

* The world is a **rectangular hex grid** with configurable width and height.
* **Map seeds** determine Totem and Decay Totem positions.
* All tiles must connect to the Totem’s network.
* Enclosed spaces become **Overgrowth**, which turn into **Groves** after 3 turns.
* Overgrowth touching Decay is instantly corrupted.

---

### 4) Data Architecture

All gameplay systems are **data-driven**, allowing modular content updates.

| System       | File          | Description                                          |
| ------------ | ------------- | ---------------------------------------------------- |
| **Tiles**    | tiles.json    | Tile IDs, categories, variants, and pack definitions |
| **Totems**   | totems.json   | IDs, auras, generation rules, upgrade data           |
| **Sprouts**  | sprouts.json  | IDs, stats, growth curves, linked attacks/passives   |
| **Attacks**  | attacks.json  | Targeting (front/back), cooldowns, effects           |
| **Passives** | passives.json | Trigger logic, scaling, rarity                       |
| **Maps**     | maps.json     | Grid size, seed data, Totem/Decay positions          |

---

### 5) Resources & Ecology

**Essences**

* **Nature Essence:** Produced by Harvest tiles.
* **Earth Essence:** Produced by Build tiles.
* **Water Essence:** Created by Refine tiles.
* **Life Essence:** Earned from battle victories; used to evolve Totems or activate world abilities.

**Caps & Flow**

* Base cap: 5 units per producing tile.
* Harvest clusters: +10 global capacity per tile.
* Storage tiles: +5 capacity to adjacent producers.

**Usage**

* Power Totem evolutions.
* Upgrade Sprouts and abilities.
* Activate large-scale spells or purifications.

---

### 6) The Totem

* Placement and traits are defined by map seed and database entry.
* Generates tile packs every 3 turns.
* Evolving the Totem increases pack rarity, Decay resistance, and adds passive world effects.
* Losing the Totem ends the run.

---

### 7) Growth & Mutation

* Enclosed empty regions become **Overgrowth**, transforming into **Groves** after 3 turns to spawn Sprouts.
* Overgrowth corrupted before maturity becomes Decay.
* Adjacency may cause **mutations** (e.g., Grove + Harvest → Grove Thicket).

**Turn Order**

1. Growth (Overgrowth → Grove)
2. Mutation checks
3. Decay spread
4. Resource generation
5. Every 3 turns: Totem tile generation

---

### 8) Tile Roles & Variants

| Tile Type    | Function                                                                                                                                 |
| ------------ | ---------------------------------------------------------------------------------------------------------------------------------------- |
| **Harvest**  | Generates Nature Essence per adjacent Grove; increases global capacity.                                                                  |
| **Build**    | Produces Earth Essence **only when adjacent to a Guard or Storage tile**. If adjacent to a Harvest tile, production time is **doubled**. |
| **Refine**   | Converts Nature + Earth → Water Essence every 2 turns.                                                                                   |
| **Storage**  | Expands capacity of adjacent producers by +5.                                                                                            |
| **Guard**    | Immune to Decay; provides safe placement zones. Mutated forms may gain adjacency effects.                                                |
| **Upgrade**  | Produces **Soul Seeds**, items that instantly level up Sprouts without resource use.                                                     |
| **Chanting** | Creates single-use spells through rituals.                                                                                               |
| **Grove**    | Formed from Overgrowth; spawns a Sprout and boosts nearby tiles.                                                                         |

---

### 9) The Sprout System

* Sprouts are stored globally in the **Sprout Register**.
* Each Sprout has:

  * 1 **Attack Type**
  * Up to 3 **Passives**
  * **Level Cap:** 99
* Leveling increases HP, Attack, and Attack Speed.
* Level-up sources: resources or **Soul Seeds** (no XP from battles).
* All stats, attacks, and passives are defined by ID in the database.

---

### 10) Battle System

**Structure**

* Battles occur in a separate **Battle Window**.
* Each side fields up to **six units** (3 front row, 3 back row).
* Attacks specify **target row** (front or back) and **cooldown** (seconds).
* Units auto-attack when their cooldowns complete.
* Passives trigger under specific conditions.
* Battle ends when one side is completely defeated.

**Flow**

1. Decay attacks a Life tile.
2. Player selects up to six Sprouts from the Register.
3. Combat resolves automatically.
4. **Victory:** Decay tiles are destroyed, Sprouts return.
   **Defeat:** Target and adjacent tiles become Decay.

**Rewards**

* **Victory:** Life Essence and possible Relic drops.
* **Defeat:** Global Decay aggression increases.
* Sprouts do **not** gain XP from battles.

---

### 11) Threats & Corruption

* **Decay Totems** spread corruption from preset positions.
* Each converts one new tile every 3 turns.
* Decay adjacent to Life tiles begins a 3-turn countdown to battle.
* A maximum of **three Decay attacks** can occur globally per turn.
* Destroying a Decay Totem purifies its nearby Decay tiles.

**Victory:** All Decay Totems destroyed.
**Defeat:** Totem consumed or all tiles placed.

---

### 12) UI & Controls

**Controls**

* **Arrows:** Move cursor
* **Space:** Confirm/place tile
* **Z:** Cancel/back
* **Tab:** Cycle panels (Resources, Sprouts, Deck, Abilities, Combat Log)

**Panels**

* **Tile Deck:** Remaining tiles and upcoming draws.
* **Resources:** Essence totals and generation rates.
* **Sprout Register:** Sprout stats, passives, and level-up progress.
* **Combat Log:** Battle outcomes and summaries.

**Battle Window**

* Displays 3x2 formation, cooldown timers, HP bars, and triggered effects.
* Ends with Victory/Defeat summary, rewards, and Soul Seed count.

---

### 13) Progression & Meta

* Unlock new **Totems**, **Tile Variants**, **Sprouts**, **Attacks**, and **Passives** through progression.
* **Relics** modify Totem generation, battle frequency, or environmental rules.
* **Map seeds** control layout and difficulty scaling.
* Unlocks persist via database flags tied to entity IDs.

---

### 14) Balancing & Configs

| System       | File          | Description                                    |
| ------------ | ------------- | ---------------------------------------------- |
| **Tiles**    | tiles.json    | Ratios, effects, adjacency rules               |
| **Sprouts**  | sprouts.json  | Stat growth, rarity, scaling                   |
| **Attacks**  | attacks.json  | Cooldowns, targeting, power                    |
| **Passives** | passives.json | Trigger conditions, rarity                     |
| **Decay**    | decay.json    | Spread rate, timers, aggression scaling        |
| **Maps**     | maps.json     | Grid dimensions, seed layout, difficulty tiers |

**Balance Goals**

* Preserve the 3-turn rhythm: placement → world update → tile generation → battle.
* Ensure tile synergies and cooldown speeds scale predictably.
* Support content expansion through modular data.

---

### 15) Glossary

* **Totem:** Generates tile packs and anchors the forest.
* **Tile Pack:** Group of tiles added to the deck every 3 turns.
* **Sprout Register:** Global list of all Sprouts.
* **Guard Tile:** Immune tile providing permanent map stability.
* **Soul Seed:** Item that levels up Sprouts instantly.
* **Battle Window:** Separate arena for Decay battles.
* **Front Row / Back Row:** Formation layout (3 per row).
* **Attack Cooldown:** Time before an attack can repeat.
* **Decay Totem:** Source of spreading corruption.
* **Overgrowth / Grove:** Growth phases that generate new Sprouts.
* **Essences:** Nature, Earth, Water, and Life — main resources.
* **Relic:** Persistent meta modifier unlocked between runs.
* **Map Seed:** Determines world layout and placements.
