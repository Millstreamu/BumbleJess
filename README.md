## Sprouts — Design Document (v3.1)

### 1) High-Level Overview

**Genre:** Calm turn-based forest regrowth roguelite
**Engine:** Godot 4.4.1 (2D, controller/keyboard only)
**Core Fantasy:** Restore a fallen forest by nurturing life through careful, deliberate tile placement. Summon Sprouts—living embodiments of renewal—to fight Decay, spread growth, and bring balance back to the world.

#### Pillars

* **Chill, not idle:** Each placement and choice advances the world one turn.
* **Readable systems:** Everything has a visible, meaningful effect.
* **One-input model:** Arrows move focus; Space confirms; Z backs out; Tab opens menus.

---

### 2) Game Flow

**Run Start**

1. **Choose a Totem** – Sets your passive bonuses, unique tile access, and playstyle.
2. **Select 4 Sprout Types** – Defines your generatable Sprouts for that run.

**Each Turn**

1. **Commune (Start of Turn):** Choose one of three tiles (weighted by bias).
2. **Player Phase:** Place a tile, optionally attack Decay tiles or Totems.
3. **End Turn:** Press the Turn Button. Resolves world progression:

   * Overgrowth → Grove transitions.
   * Resource generation.
   * Decay spreads and attacks up to 3 times sequentially.
   * Sprouts and Smogs heal 5% HP.
   * Totem passives trigger.

**Victory:** All Decay Totems destroyed.
**Defeat:** Totem consumed by Decay or no valid placements remain.

---

### 3) Tile System

Tiles are the foundation of world growth. Each has **type**, **tags**, **effects**, and **synergy rules**. All data-driven via `tiles.json`.

#### 3.1 Tile Categories

##### **Nature Tiles** (Resource: Nature)

1. **Whispering Pine Forest** – Generates 2 Nature/turn. Adjacent to other *Forest* tiles → +1 Nature.
2. **Lone Bloom** – Generates 1 Nature per adjacent *Grove*.
3. **Moss Terrace** – Every 2 turns, spawns an Overgrowth tile in adjacent empty hexes.

* **Unique:** *Heartroot Grove* – On placement, generates 3 Groves instantly; one-time use.

##### **Earth Tiles** (Resource: Earth)

1. **Stone Vein** – Generates 1 Earth/turn; +1 per adjacent *Rocky* tile.
2. **Root Bastion** – +5 defense to nearby tiles; produces 1 Earth/2 turns if touching *Nest* tile.
3. **Mud Hollow** – If adjacent to *Water* tile, doubles Earth output.

* **Unique:** *Earthen Core* – Boosts production of all Earth tiles globally by +25%.

##### **Water Tiles** (Resource: Water)

1. **Mirror Pool** – Produces 1 Water/2 turns. Doubles if touching *Nature* tile.
2. **Rocky Outcrop** – Produces 1 Water if adjacent to any tile with `RIVER` tag.
3. **Spring Nexus** – Generates 1 Water + 1 Nature every 3 turns.

* **Unique:** *Tidal Heart* – Converts 1 Nature + 1 Earth → 2 Water every turn.

##### **Nest Tiles** (Storage)

1. **Treasure Nest** – Increases resource cap by +5 for all adjacent producers.
2. **Hollow Burrow** – Allows Sprout healing +10% faster if nearby.
3. **Mycelium Bed** – Converts 1 Nature → 1 Earth/2 turns.

* **Unique:** *Warden’s Cradle* – Doubles storage of all touching tiles; cannot produce resources itself.

##### **Mystic Tiles** (Soul Seed / Item Production)

1. **Chanting Circle** – Produces 1 random item every 5 turns.
2. **Soul Bloom** – Generates 1 Soul Seed every 8 turns.
3. **Glowing Spire** – Boosts passive bonuses from equipped items by +10% globally.

* **Unique:** *Elder Shrine* – Produces both 1 Soul Seed and 1 random item every 5 turns.

##### **Aggression Tiles** (Decay Counter)

1. **Thorn Watch** – After 4 turns adjacent to Decay, purifies 1 Decay tile.
2. **Ironbark Front** – Nearby Sprouts in battle +5% HP.
3. **Fungal Barricade** – Slows Decay spread by 1 turn radius.

* **Unique:** *Wrath Grove* – Can be targeted to attack a Decay Totem; triggers an immediate battle.

#### 3.2 Universal Tile Effects System (schema)

A small **universal effects engine** drives all tile behaviors using a few consistent fields. This keeps JSON simple, expressive, and hard to break.

**Effect object (reusable):**

```json
{
  "when": "start_of_turn",          // start_of_turn | end_of_turn | on_place | on_transform | on_adjacency_change
  "interval_turns": 1,               // apply every N turns when the timing condition is met (optional)
  "duration_turns": null,            // if set, effect expires after N applications (optional)

  "target": {                        // who is affected
    "scope": "adjacent",            // self | adjacent | radius | global
    "radius": 1,                     // used when scope == radius
    "has_tags_any": ["forest"],     // filter: target tile must have ANY of these tags (optional)
    "has_tags_all": [],              // filter: target tile must have ALL of these tags (optional)
    "category_any": ["Nature"],     // filter by categories (optional)
    "include_overgrowth": true,      // include Overgrowth in selection (optional)
    "include_grove": true            // include Groves in selection (optional)
  },

  "condition": {                     // gate the effect (optional)
    "adjacent_count": {              // check neighbors around the SOURCE tile
      "tag": "forest",
      "op": ">=",
      "value": 1
    },
    "touching_decay": false,         // require not touching decay
    "turn_mod": {"mod": 2, "eq": 0} // only when (turn % mod == eq) — e.g., every 2 turns
  },

  "op": "add",                      // add | mul | set | convert | spawn | transform | cleanse_decay | damage_decay | aura_sprout
  "stat": "output.nature",          // path for modifiers (e.g., output.nature, cap.global, purity, battle.hp_pct)
  "amount": 1,                       // numeric amount or object for convert/spawn/transform
  "stacking": "sum"                 // sum | max | min (how parallel effects combine)
}
```

**Supported primitives**

* **add/mul/set** → change numeric stats (resource output, caps, purity, battle modifiers).
* **convert** → `{ "from": {"nature":1}, "to": {"water":1}, "period": 2 }`.
* **spawn** → `{ "tile_id": "tile.overgrowth", "count": 1, "empty_only": true }`.
* **transform** → `{ "to": "tile.overgrowth" }` (self-only).
* **cleanse_decay** → `{ "radius": 1, "max_tiles": 1 }`.
* **damage_decay** → `{ "radius": 1, "amount": 1 }` (per tick).
* **aura_sprout** → `{ "stat": "hp_pct", "op": "add", "amount": 0.05 }` (affects friendly Sprouts in range during battles).

> Engine rules: evaluate **when**; check **condition**; collect **target** set; apply **op** to each target using **stat/amount**; respect **interval/duration**; combine parallel effects via **stacking**.

#### 3.3 Tile JSON Examples (using the universal effects)

**Rocky Outcrop** — *Produces 1 Water if next to a RIVER tile*

```json
{
  "id": "tile.rocky_outcrop",
  "category": "Water",
  "tags": ["rocky"],
  "effects": [
    {
      "when": "start_of_turn",
      "target": {"scope": "self"},
      "condition": {"adjacent_count": {"tag": "river", "op": ">=", "value": 1}},
      "op": "add", "stat": "output.water", "amount": 1
    }
  ]
}
```

**Wind‑Swept Meadow** — *Boost adjacent FOREST tiles by +1 Nature*

```json
{
  "id": "tile.wind_swept_meadow",
  "category": "Nature",
  "tags": ["plains"],
  "effects": [
    {
      "when": "start_of_turn",
      "target": {"scope": "adjacent", "has_tags_any": ["forest"]},
      "op": "add", "stat": "output.nature", "amount": 1
    }
  ]
}
```

**Moss Terrace** — *Spawn Overgrowth every 2 turns if space exists*

```json
{
  "id": "tile.moss_terrace",
  "category": "Nature",
  "tags": ["wet", "moss"],
  "effects": [
    {
      "when": "start_of_turn",
      "interval_turns": 2,
      "target": {"scope": "adjacent", "include_overgrowth": false},
      "op": "spawn",
      "amount": {"tile_id": "tile.overgrowth", "count": 1, "empty_only": true}
    }
  ]
}
```

**Strangle‑Thorn Thicket** — *Generates +10 Nature/turn; transforms into Overgrowth after 5 turns*

```json
{
  "id": "tile.strangle_thorn_thicket",
  "category": "Nature",
  "tags": ["forest", "thorn"],
  "effects": [
    {"when": "start_of_turn", "target": {"scope": "self"}, "op": "add", "stat": "output.nature", "amount": 10},
    {"when": "start_of_turn", "interval_turns": 5, "target": {"scope": "self"}, "op": "transform", "amount": {"to": "tile.overgrowth"}}
  ]
}
```

**Thorn Watch** — *Cleanse 1 adjacent Decay tile after 4 turns of contact*

```json
{
  "id": "tile.thorn_watch",
  "category": "Aggression",
  "tags": ["ward"],
  "effects": [
    {
      "when": "start_of_turn",
      "interval_turns": 4,
      "target": {"scope": "radius", "radius": 1},
      "condition": {"touching_decay": true},
      "op": "cleanse_decay",
      "amount": {"radius": 1, "max_tiles": 1}
    }
  ]
}
```

**Ironbark Front** — *Battle aura: Sprouts in range gain +5% HP*

```json
{
  "id": "tile.ironbark_front",
  "category": "Aggression",
  "tags": ["bastion"],
  "effects": [
    {
      "when": "start_of_turn",
      "target": {"scope": "radius", "radius": 2},
      "op": "aura_sprout",
      "amount": {"stat": "hp_pct", "op": "add", "amount": 0.05}
    }
  ]
}
```

---

### 4) Overgrowth & Grove

* Overgrowth is created **only by specific tile effects** (e.g., Moss Terrace) and no longer via enclosure.
* After 3 turns → transforms into a **Grove** and spawns one Sprout of your selected types.
* Overgrowth and Groves are highly susceptible to Decay.

---

### 5) Sprouts System

Sprouts are semi-permanent units representing life energy. Chosen 4 types at start; new ones spawn from Groves.

#### 5.1 Leveling & Resources

* Each level requires **6 × n** resources (n = next level).
* Example: L2=6, L3=12, L4=18, L5=24, L6=30.
* Resource composition differs by Sprout type (e.g., 4 Nature + 2 Water, or 3 Nature + 3 Earth).
* **Soul Seed** = 24 resource equivalent (used for quick leveling).

#### 5.2 Equipment

* 1 slot per Sprout.
* Equippable outside or pre-battle only.
* Effects can stack hybrid bonuses (e.g., +200% heal, +50% HP, −75% dmg).

#### 5.3 Example Archetypes

* **Grumbler:** High HP, low dmg.
* **Amber Knight:** Medium HP, balanced dmg, minor regen.
* **Moss Golem:** Low HP, support-oriented healing.

#### 5.4 Sprout JSON Example

```json
{
  "id": "sprout.grumbler",
  "archetype": "tank",  // Informative only
  "base_stats": {"hp": 100, "attack": 10, "speed": 1.0},
  "growth_per_level": {"mult": 1.05},  // +5% per level
  "level_caps": 99,
  "level_costs": {"nature": 4, "water": 2},  // Leveling requires Nature/Water mix
  "attack_id": "atk.slam",
  "passive_ids": ["pas.stone_skin"],
  "equip_slots": 1,
  "permadeath": true
}
```

---

### 6) Battle System

* 2×3 grid (Sprouts left, Smogs right).
* Average fight: 60 seconds.
* Each unit uses its `attack_id` (cooldown in seconds).
* All attacks have row targeting (front/back) and cooldown.
* Global modifiers: +1% HP or similar from certain tiles.

**Synergies:**

* Family bonuses (e.g., +1% dmg per “Trog” Sprout in battle).
* Persistent HP damage across fights; 5% regen per world turn.

---

### 7) Totems

Each Totem defines run theme, commune weighting, and passives. Upgraded via Life Essence.

#### 7.1 Tier Table Example

| Tier | Bonus                | Unique Tile Chance | Regen Bonus |
| ---- | -------------------- | ------------------ | ----------- |
| 1    | Base                 | 5%                 | 0%          |
| 2    | +2 passive strength  | 10%                | +0.5%       |
| 3    | +5 passive strength  | 15%                | +1%         |
| 4    | +7 passive strength  | 20%                | +1.5%       |
| 5    | +10 passive strength | 25%                | +2%         |

#### 7.2 Totem JSON Example

```json
{
  "id": "totem.heartseed",
  "tier": 1,
  "commune_interval_turns": 1,
  "passives": ["pas.regen_small"],
  "unique_tiles": ["tile.heartroot_grove"],
  "upgrades": {
    "cost": {"life": 5},
    "effects": {"regen_bonus": "+0.5"}
  }
}
```

---

### 8) Artefacts & Unlocks

* 1 artefact per map (3 on large maps).
* Hidden under the Shroud; revealed when a tile is placed on that hex.
* Unlocks a new Sprout permanently in your **Sprout Library**.

**Example Artefacts:**

* **Ancient Husk:** “You uncover a slumbering guardian.” → Unlocks *Moss Golem.*
* **Echo Seed:** “A crystal hums softly.” → Unlocks *Amber Knight.*
* **Lost Shell:** “A fragment of life reawakens.” → Unlocks *Grumbler.*

#### 8.1 Map JSON Example

```json
{
  "id": "map.demo_01",
  "grid": {"width": 32, "height": 24},
  "seed": 12345,
  "totem_pos": {"x": 8, "y": 12},
  "decay_totems": [{"x": 26, "y": 6}],
  "artefacts": [
    {"x": 18, "y": 10, "reveals_sprout_id": "sprout.moss_golem"}
  ]
}
```

---

### 9) Data Flow Overview

```
[GameLoader]
   ↓ loads all JSONs
[DataDB] — stores all definitions
   ↓ provides to managers
[MapSeeder] → creates Totem, Decay, Artefact hexes
[CommuneManager] → handles weighted tile offers (Bias Algorithm)
[TileManager] → handles placement, adjacency, overgrowth
[BattleManager] → runs auto-battles, applies persistence
[MetaManager] → tracks unlocks, Sprout Library
```

---

### 10) Glossary

* **Commune:** Start-of-turn Totem event offering tiles.
* **Core Tiles:** Up to 10 primary tiles that bias Commune draws.
* **Overgrowth:** Transitional tile that becomes Grove after 3 turns.
* **Grove:** Life tile that spawns Sprouts.
* **Soul Seeds:** Rare currency for leveling Sprouts.
* **Artefact Hex:** Hidden map location revealing new Sprouts.
* **Sprout Library:** Persistent collection of unlocked Sprouts.

---

### 12) Appendix — JSON Templates (clean, no comments)

#### 12.1 Tiles (example content set)

```json
[
  {"id":"tile.nature.whispering_pine_forest","category":"Nature","name":"Whispering Pine Forest","description":"Generates +2 Nature per turn. If adjacent to any FOREST tile, generate +1 additional Nature.","tags":["forest","nature"],"effects":[{"when":"start_of_turn","target":{"scope":"self"},"op":"add","stat":"output.nature","amount":2},{"when":"start_of_turn","target":{"scope":"self"},"condition":{"adjacent_count":{"tag":"forest","op":">=","value":1}},"op":"add","stat":"output.nature","amount":1}]},
  {"id":"tile.nature.lone_bloom","category":"Nature","name":"Lone Bloom","description":"Generates +1 Nature per turn, plus +1 Nature if adjacent to any GROVE tile.","tags":["wildflower","nature"],"effects":[{"when":"start_of_turn","target":{"scope":"self"},"op":"add","stat":"output.nature","amount":1},{"when":"start_of_turn","target":{"scope":"self"},"condition":{"adjacent_count":{"tag":"grove","op":">=","value":1}},"op":"add","stat":"output.nature","amount":1}]},
  {"id":"tile.nature.moss_terrace","category":"Nature","name":"Moss Terrace","description":"Every 2 turns, spawns 1 OVERGROWTH into an adjacent empty hex.","tags":["moss","wet","nature"],"effects":[{"when":"start_of_turn","interval_turns":2,"target":{"scope":"adjacent"},"op":"spawn","amount":{"tile_id":"tile.special.overgrowth","count":1,"empty_only":true}}]},
  {"id":"tile.nature.heartroot_grove","category":"Nature","name":"Heartroot Grove","description":"On placement, creates 3 GROVES in adjacent empty hexes (one-time).","tags":["forest","unique","nature"],"effects":[{"when":"on_place","target":{"scope":"adjacent"},"op":"spawn","amount":{"tile_id":"tile.special.grove","count":3,"empty_only":true}}],"unique":{"uses":1,"forced_place":true}},
  {"id":"tile.earth.stone_vein","category":"Earth","name":"Stone Vein","description":"Generates +1 Earth per turn, plus +1 Earth if adjacent to any ROCKY tile.","tags":["rocky","earth"],"effects":[{"when":"start_of_turn","target":{"scope":"self"},"op":"add","stat":"output.earth","amount":1},{"when":"start_of_turn","target":{"scope":"self"},"condition":{"adjacent_count":{"tag":"rocky","op":">=","value":1}},"op":"add","stat":"output.earth","amount":1}]},
  {"id":"tile.earth.root_bastion","category":"Earth","name":"Root Bastion","description":"Sprouts within 2 tiles gain +5% HP in battles. If adjacent to any NEST tile, generates +1 Earth every 2 turns.","tags":["bastion","earth"],"effects":[{"when":"start_of_turn","target":{"scope":"radius","radius":2},"op":"aura_sprout","amount":{"stat":"hp_pct","op":"add","amount":0.05}},{"when":"start_of_turn","interval_turns":2,"target":{"scope":"self"},"condition":{"adjacent_count":{"tag":"nest","op":">=","value":1}},"op":"add","stat":"output.earth","amount":1}]},
  {"id":"tile.earth.mud_hollow","category":"Earth","name":"Mud Hollow","description":"Generates +1 Earth per turn. If adjacent to any WATER tile, doubles its Earth output.","tags":["mud","earth"],"effects":[{"when":"start_of_turn","target":{"scope":"self"},"op":"add","stat":"output.earth","amount":1},{"when":"start_of_turn","target":{"scope":"self"},"condition":{"adjacent_count":{"tag":"water","op":">=","value":1}},"op":"mul","stat":"output.earth","amount":2}]},
  {"id":"tile.earth.earthen_core","category":"Earth","name":"Earthen Core","description":"Globally multiplies Earth output of all EARTH tiles by ×1.25 (one-time unique).","tags":["unique","earth"],"effects":[{"when":"start_of_turn","target":{"scope":"global","category_any":["Earth"]},"op":"mul","stat":"output.earth","amount":1.25}],"unique":{"uses":1,"forced_place":false}},
  {"id":"tile.water.mirror_pool","category":"Water","name":"Mirror Pool","description":"Generates +1 Water every 2 turns. If adjacent to any NATURE tile, doubles Water output.","tags":["pool","water","wet"],"effects":[{"when":"start_of_turn","interval_turns":2,"target":{"scope":"self"},"op":"add","stat":"output.water","amount":1},{"when":"start_of_turn","target":{"scope":"self"},"condition":{"adjacent_count":{"tag":"nature","op":">=","value":1}},"op":"mul","stat":"output.water","amount":2}]},
  {"id":"tile.water.rocky_outcrop","category":"Water","name":"Rocky Outcrop","description":"Generates +1 Water per turn if adjacent to any RIVER tile.","tags":["rocky","water"],"effects":[{"when":"start_of_turn","target":{"scope":"self"},"condition":{"adjacent_count":{"tag":"river","op":">=","value":1}},"op":"add","stat":"output.water","amount":1}]},
  {"id":"tile.water.spring_nexus","category":"Water","name":"Spring Nexus","description":"Every 3 turns, generates +1 Water and +1 Nature.","tags":["spring","water"],"effects":[{"when":"start_of_turn","interval_turns":3,"target":{"scope":"self"},"op":"add","stat":"output.water","amount":1},{"when":"start_of_turn","interval_turns":3,"target":{"scope":"self"},"op":"add","stat":"output.nature","amount":1}]},
  {"id":"tile.water.tidal_heart","category":"Water","name":"Tidal Heart","description":"Each turn converts 1 Nature and 1 Earth into 2 Water (unique).","tags":["unique","water"],"effects":[{"when":"start_of_turn","target":{"scope":"self"},"op":"convert","amount":{"from":{"nature":1,"earth":1},"to":{"water":2},"period":1}}],"unique":{"uses":1,"forced_place":false}},
  {"id":"tile.nest.treasure_nest","category":"Nest","name":"Treasure Nest","description":"Adjacent resource-producing tiles gain +5 local capacity.","tags":["nest","storage"],"effects":[{"when":"start_of_turn","target":{"scope":"adjacent","category_any":["Nature","Earth","Water"]},"op":"add","stat":"cap.local","amount":5}]},
  {"id":"tile.nest.hollow_burrow","category":"Nest","name":"Hollow Burrow","description":"Sprouts within 1 tile heal +10% faster outside of battle.","tags":["nest","burrow"],"effects":[{"when":"start_of_turn","target":{"scope":"radius","radius":1},"op":"aura_sprout","amount":{"stat":"regen_pct","op":"add","amount":0.1}}]},
  {"id":"tile.nest.mycelium_bed","category":"Nest","name":"Mycelium Bed","description":"Every 2 turns, converts 1 Nature into 1 Earth.","tags":["nest","fungal"],"effects":[{"when":"start_of_turn","interval_turns":2,"target":{"scope":"self"},"op":"convert","amount":{"from":{"nature":1},"to":{"earth":1},"period":2}}]},
  {"id":"tile.nest.wardens_cradle","category":"Nest","name":"Warden's Cradle","description":"Doubles local capacity of all adjacent tiles (unique).","tags":["unique","nest","storage"],"effects":[{"when":"start_of_turn","target":{"scope":"adjacent"},"op":"mul","stat":"cap.local","amount":2}],"unique":{"uses":1,"forced_place":false}},
  {"id":"tile.mystic.chanting_circle","category":"Mystic","name":"Chanting Circle","description":"Every 5 turns, produces 1 random item.","tags":["mystic","ritual"],"effects":[{"when":"start_of_turn","interval_turns":5,"target":{"scope":"self"},"op":"add","stat":"output.item_rolls","amount":1}]},
  {"id":"tile.mystic.soul_bloom","category":"Mystic","name":"Soul Bloom","description":"Every 8 turns, produces 1 Soul Seed.","tags":["mystic","seed"],"effects":[{"when":"start_of_turn","interval_turns":8,"target":{"scope":"self"},"op":"add","stat":"output.soul_seed","amount":1}]},
  {"id":"tile.mystic.glowing_spire","category":"Mystic","name":"Glowing Spire","description":"Globally increases the power of equipped items by ×1.10.","tags":["mystic","spire"],"effects":[{"when":"start_of_turn","target":{"scope":"global"},"op":"aura_sprout","amount":{"stat":"item_power_mult","op":"mul","amount":1.1}}]},
  {"id":"tile.mystic.elder_shrine","category":"Mystic","name":"Elder Shrine","description":"Every 5 turns, produces 1 Soul Seed and 1 random item (unique).","tags":["unique","mystic","shrine"],"effects":[{"when":"start_of_turn","interval_turns":5,"target":{"scope":"self"},"op":"add","stat":"output.soul_seed","amount":1},{"when":"start_of_turn","interval_turns":5,"target":{"scope":"self"},"op":"add","stat":"output.item_rolls","amount":1}],"unique":{"uses":1,"forced_place":false}},
  {"id":"tile.aggression.thorn_watch","category":"Aggression","name":"Thorn Watch","description":"If touching Decay, every 4 turns cleanse up to 1 adjacent Decay tile.","tags":["ward","aggression"],"effects":[{"when":"start_of_turn","interval_turns":4,"target":{"scope":"radius","radius":1},"condition":{"touching_decay":true},"op":"cleanse_decay","amount":{"radius":1,"max_tiles":1}}]},
  {"id":"tile.aggression.ironbark_front","category":"Aggression","name":"Ironbark Front","description":"Sprouts within 2 tiles gain +5% HP in battles.","tags":["bastion","aggression"],"effects":[{"when":"start_of_turn","target":{"scope":"radius","radius":2},"op":"aura_sprout","amount":{"stat":"hp_pct","op":"add","amount":0.05}}]},
  {"id":"tile.aggression.fungal_barricade","category":"Aggression","name":"Fungal Barricade","description":"Deals 1 Decay damage each turn to Decay within 1 tile.","tags":["fungal","aggression"],"effects":[{"when":"start_of_turn","target":{"scope":"radius","radius":1},"op":"damage_decay","amount":{"radius":1,"amount":1}}]},
  {"id":"tile.aggression.wrath_grove","category":"Aggression","name":"Wrath Grove","description":"On placement, cleanses up to 2 Decay tiles in radius 2. Sprouts within 2 tiles gain +5% attack (unique).","tags":["unique","aggression","grove"],"effects":[{"when":"on_place","target":{"scope":"radius","radius":2},"op":"cleanse_decay","amount":{"radius":2,"max_tiles":2}},{"when":"start_of_turn","target":{"scope":"radius","radius":2},"op":"aura_sprout","amount":{"stat":"attack_pct","op":"add","amount":0.05}}],"unique":{"uses":1,"forced_place":false}},
  {"id":"tile.special.overgrowth","category":"Nature","name":"Overgrowth","description":"After 3 turns, transforms into a GROVE.","tags":["overgrowth","nature"],"effects":[{"when":"start_of_turn","interval_turns":3,"target":{"scope":"self"},"op":"transform","amount":{"to":"tile.special.grove"}}]},
  {"id":"tile.special.grove","category":"Nature","name":"Grove","description":"On bloom, spawns 1 Sprout of your selected run types.","tags":["grove","nature"],"effects":[{"when":"on_transform","target":{"scope":"self"},"op":"add","stat":"output.spawn_sprout","amount":1}]}
]
```

#### 12.2 Effects (op library)

```json
[
  {"id":"op.add","fields":["stat","amount"]},
  {"id":"op.mul","fields":["stat","amount"]},
  {"id":"op.set","fields":["stat","amount"]},
  {"id":"op.convert","fields":["amount.from","amount.to","amount.period"]},
  {"id":"op.spawn","fields":["amount.tile_id","amount.count","amount.empty_only"]},
  {"id":"op.transform","fields":["amount.to"]},
  {"id":"op.cleanse_decay","fields":["amount.radius","amount.max_tiles"]},
  {"id":"op.damage_decay","fields":["amount.radius","amount.amount"]},
  {"id":"op.aura_sprout","fields":["amount.stat","amount.op","amount.amount"]}
]
```

#### 12.3 Sprouts (template)

```json
[
  {"id":"sprout.grumbler","name":"Grumbler","archetype":"tank","base_stats":{"hp":100,"attack":10,"speed":1.0},"growth_per_level":{"mult":1.05},"level_cap":99,"level_costs":{"nature":4,"water":2},"attack_id":"atk.slam","passive_ids":["pas.stone_skin"],"equip_slots":1,"permadeath":true},
  {"id":"sprout.amber_knight","name":"Amber Knight","archetype":"bruiser","base_stats":{"hp":80,"attack":14,"speed":1.0},"growth_per_level":{"mult":1.05},"level_cap":99,"level_costs":{"nature":3,"earth":3},"attack_id":"atk.pierce","passive_ids":["pas.regen_small"],"equip_slots":1,"permadeath":true}
]
```

#### 12.4 Passives (template)

```json
[
  {"id":"pas.split_strike","trigger":"on_attack","effects":[{"type":"extra_hit","hits":1,"mult":0.5}]},
  {"id":"pas.regen_small","trigger":"turn_tick","effects":[{"type":"heal_pct","amount":0.02}]},
  {"id":"pas.stone_skin","trigger":"on_battle_start","effects":[{"type":"defense_add","amount":4}]}
]
```

#### 12.5 Attacks (template)

```json
[
  {"id":"atk.slam","name":"Slam","cooldown_sec":4.0,"target_row":"front","effects":[{"type":"damage","amount":14}]},
  {"id":"atk.pierce","name":"Pierce","cooldown_sec":3.0,"target_row":"back","effects":[{"type":"damage","amount":10}]}
]
```

### 13) Interface & UX Overview

#### 13.1 Main Menu

* **Elements:** Start Run, Settings, Exit, Library (shows unlocked Sprouts, Totems, Tiles).
* **Input:** Controlled by arrow keys; Space confirms; Z backs out.
* **Layout:** Centered title; vertical stack of buttons; Library leads to an unlock browser.

#### 13.2 Totem Selection

* **Transition:** Main Menu slides left; Totem window slides in from right.
* **Layout:** 4-wide, infinite-down grid of totem cards.
* **Totem Card:**

  * Left: hex tile image.
  * Top right: name.
  * Below: effects and description.
* **Input:** Arrows move selection; Space selects; Z returns; 'M' toggles details (commune weights, passives).

#### 13.3 Sprout Selection

* **Transition:** Totem screen slides left; Sprout window slides in from right.
* **Layout:** 4-wide, infinite-down grid.
* **Selection:** Choose 4 Sprouts.
* **Sprout Card:**

  * Left: round portrait.
  * Right: name → HP / Attack / Speed → attack name → passive name → short description.
* **Input:** Arrows move; Space selects; Z backs; 'M' toggles tooltip (attack description, HP/ATK/Speed per level, upgrade costs).

#### 13.4 In-Run Main Screen

* **Layout:**

  * Center: hex grid.
  * Top center: turn number + phase.
  * Bottom right: resources (Nature, Earth, Water, Life Essence).
  * Bottom left: tile card for current tile to place.
  * Top right: quick toggles (Sprout Registry, Resource list).
* **Input:**

  * Arrows move selector.
  * Space: place tile or interact.
  * Z: back.
  * M: toggles tile info popups.
  * N: end turn.
* **Phases:**

  * Resource generation: floating colored numbers for output.
  * Decay attack prep: exclamation marks over threatened tiles (yellow/orange/red).
* **Interaction:**

  * Tiles that can receive Sprouts or resources glow.
  * Space opens context window (assign Sprout or spend resources).

#### 13.5 Commune Window

* **Display:** Overlays main screen; background darkens.
* **Layout:** 3 tile cards horizontally.
* **Tile Card:**

  * Left: tile hex art.
  * Right top: name.
  * Below: effects.
  * Below: description.
* **Input:** Arrows to navigate; Space to select; 'M' shows help image.

#### 13.6 Sprout Registry & Battle Formation

* **Layout:**

  * Left: vertical list of all Sprouts (1 wide, scrollable).
  * Right: battle formation grid (3 rows × 2 columns).
* **Input:**

  * Arrows: navigate.
  * Space: add/remove Sprout.
  * C: clear formation.
  * B: level up with resources.
  * G: level up with Soul Seed.
* **Visuals:**

  * Dead Sprouts fade.
  * Equipped items/passives shown as icons.

**Battle Window Flow**

* **Pre-Battle Modal (overlay on battle window):**

  * Scene: Two teams visible left/right; background darkened.
  * Small centered modal with two options: **Start Battle** and **Edit Team**.
  * Input: Arrows to switch; Space to confirm; Z to back (closes battle window and returns to map without starting).
  * Choosing **Edit Team** opens the Registry/Formation panel (same controls as above), then returns to this modal.
* **Battle Phase:**

  * Modal fades; battle plays out automatically until one side is defeated.
  * UI shows defeat/victory banner on resolution.
* **Post-Battle:**

  * **Space** to continue (always) → closes battle window.
  * Camera pans to the affected map location and animates outcome:

    * Victory: targeted Decay tiles are removed (cleanse animation).
    * Defeat: targeted Life tile converts to Decay (overtake animation).

**Battle Visual Styling**

* **Units:** Render **actual Sprout/Smog sprites** (not cards), front/back row per side.
* **HP bars:** Sprouts = **green**; Decay/Smogs = **purple**.
* **Damage numbers:** Red numerals that spawn on hit, drift **away from the attacker’s direction** (looks like being chipped off), rise slightly, and **fade out** (ease-out).
* **Hit feedback:** Sprout sprite **flashes red** briefly on impact (0.08–0.12s), with a light shake (2–4px) for tactile response.
* **Cooldown UI:** Small radial or bar timer overlay on each unit indicating next attack.
* **Result banner:** Center-top **Victory**/**Defeat** banner; fades in/out over 0.6s.

  * Defeat: targeted Life tile converts to Decay (overtake animation).

#### 13.7 Library

* **Layout:** 4-wide grid, infinite down.
* **State:** Each card shows locked or unlocked.
* **Example:** If Totems 1, 2, 4, 5 are unlocked, first row = unlocked, unlocked, locked, unlocked; next row starts unlocked again.
* **Cards:** Show number, name (if unlocked), silhouette or question mark (if locked).

#### 13.8 Interaction Windows

* **Sprout Assignment Window:**

  * Left: 1-wide, infinite-down list of Sprouts.
  * Right: single slot showing selected Sprout card as assigned.
  * Bottom: confirm button (navigable by arrow keys, Space to confirm).
* **Resource Conversion Window:**

  * Left: required resource icons and amounts.
  * Center: convert button.
  * Right: resulting item/resource display.
  * On confirmation: particle effect and fade animation.

#### 13.9 Animation & Timing Rules

* **Turn Phase Sequence:** Resource generation → Decay warnings → Decay attacks → End phase.
* **Timing:** ~0.5s pacing per tile action.
* **Order:** Starts from Totem, radiates outward; each tile generates one at a time.
* **Resource Feedback:** Floating colored numbers rise and fade (green Nature, brown Earth, blue Water).
* **Decay Warning:** Exclamation mark above tiles grows redder each turn.

#### 13.10 Scaling & Resolution

* UI scales proportionally with window size.
* Relative positioning and spacing preserved; absolute pixel size scales with resolution.

#### 13.11 Controls & Accessibility

* No remapping; designed for keyboard/controller parity.
* Console-ready input scheme.
* Navigation unified: arrow keys or D-pad for selection, Space/A for confirm, Z/B for back, M for info toggle, N for end turn.

### 14) State & Logic Mapping (Scaffold)

### Clarifications & Addenda for Demo Readiness

* **Decay Targeting:** Attacks are random among valid Life tiles in range. If fewer than three valid targets exist, it attacks only available ones; if none, it skips the attack phase.
* **Sprout Spawning:** Sprouts are manually assigned to tiles and battle teams. There is no max sprout count. New sprouts only originate from Groves or tile effects.
* **Resource Display:** HUD shows current/maximum values (e.g., 34/50). Updates occur in real time during generation.
* **Battle Timing:** Units attack automatically every 3–5 seconds, determined by the attack speed stat.
* **Camera Behavior:** Camera remains centered on the highlighted tile during normal play. It pans during battle outcomes to show results, then returns to the previously selected tile.
* **Totem Tier Progression:** Totems tier up based on Life Essence spent, improving passive effects but not affecting commune frequency.
* **Victory/Defeat Screens:**

  * Sprout battles: simple Victory/Defeat banner.
  * Run summary: shows Turns Survived, Decay tiles/totems defeated, and New Unlocks gained.
* **Render Order Proposal:**

  1. Tile base layer (terrain)
  2. Overgrowth layer
  3. Sprout/Smog units
  4. Tile effects/particles
  5. UI overlays (floating text, warnings)
  6. HUD/menus/commune window

> This section defines high-level game states, what activates in each, and how transitions occur. No visuals yet—pure logic for implementation reference.

#### 14.1 State Index

* **S1:** `main_menu`
* **S2:** `totem_select`
* **S3:** `sprout_select`
* **S4:** `in_run`
* **S4a (overlay):** `commune_overlay`
* **S4b (overlay):** `sprout_registry`
* **S4c (overlay):** `resource_conversion_window`
* **S4d (overlay):** `battle_window`
* **S5:** `victory`
* **S6:** `defeat`

#### 14.2 State Definitions (entry/exit/inputs/UI)

**S1: main_menu**

* **Entry:** show title; focus default on “Start Run”.
* **UI:** Main Menu layout (13.1). Library opens as sub-view (same state).
* **Inputs:** Arrows (navigate), Space (confirm), Z (back/close sub-view).
* **Transitions:**

  * Space on Start Run → **S2**
  * Space on Library → sub-view (locked/unlocked grid)
  * Space on Settings → settings sub-view (same state)
  * Space on Exit → quit

**S2: totem_select**

* **Entry:** slide in from right; grid 4-wide, infinite down.
* **UI:** Totem cards (13.2). `M` toggles details.
* **Inputs:** Arrows, Space (select), Z (back to S1), M (details).
* **Transitions:**

  * Space on a totem → **S3**
  * Z → **S1**

**S3: sprout_select**

* **Entry:** slide in from right; grid 4-wide; selection counter (need 4).
* **UI:** Sprout cards (13.3). `M` toggles extended tooltip.
* **Inputs:** Arrows, Space (toggle select), Z (back to S2), M (info).
* **Transitions:**

  * Space on “Start Run” (enabled when 4 selected) → **S4**
  * Z → **S2**

**S4: in_run**

* **Entry:** initialize map, place totem/decay; camera focuses grid center.
* **UI:** Main screen (13.4): top turn/phase, bottom-right resources, bottom-left current tile card.
* **Inputs:** Arrows (move hex cursor), Space (place/inspect/interact), Z (back/close), M (toggle tile info), **N (end turn)**.
* **Phase Triggers:** Start-of-turn → **S4a** (Commune overlay). End-turn runs world resolution (13.9).
* **Transitions:**

  * Auto at start of each turn → **S4a**
  * Space on tile with assignable sprout → **S4b**
  * Space on tile with conversion UI → **S4c**
  * Space on Decay tile/totem (attack) → **S4d**
  * Run ends (win/lose) → **S5**/**S6**

**S4a: commune_overlay (overlay on S4)**

* **Entry:** darken background; show 3 tile cards.
* **UI:** Commune (13.5). No skip.
* **Inputs:** Arrows, Space (choose), Z (blocked), M (help image).
* **Transitions:**

  * Space on a tile → close overlay → return to **S4** (tile becomes current placement)

**S4b: sprout_registry (overlay on S4)**

* **Entry:** slide panel; left list (all sprouts), right 3×2 formation.
* **UI:** Registry (13.6).
* **Inputs:** Arrows, Space (add/remove), C (clear), B (level via resources), G (level via Soul Seed), Z (close).
* **Transitions:**

  * Z → close overlay → **S4**

**S4c: resource_conversion_window (overlay on S4)**

* **Entry:** modal with required costs (left), convert button (center), result (right).
* **UI:** Conversion (13.8).
* **Inputs:** Arrows, Space (confirm convert), Z (close).
* **Transitions:**

  * Space on convert → apply; remain; Z to close → **S4**

**S4d: battle_window (overlay on S4)**

* **Entry:** battle grid 2×3 per side; load team; apply auras; show **Pre-Battle Modal** (Start Battle / Edit Team) with background darkened.
* **UI:** Teams visible at sides; small centered modal; defeat/victory banner on resolution.
* **Inputs:**

  * In modal: Arrows/Space, Z to cancel back to S4.
  * Edit Team: opens S4b Registry; returns to modal on close.
  * In battle: passive; no inputs until result.
  * **Post-battle:** Space to continue (always) → close battle window.
* **Transitions:**

  * Space on Start Battle → run battle → show banner → Space → close overlay → **S4**; then camera pans to outcome, applies tile changes.
  * Z in modal → **S4**

**S5: victory**

* **Entry:** summary; unlocks (new totem/tiles); option to return to main.
* **UI:** Victory summary.
* **Inputs:** Space (continue), Z (back to main).
* **Transitions:**

  * Continue → **S1**

**S6: defeat**

* **Entry:** summary; stats; hint text; option to retry.
* **UI:** Defeat summary.
* **Inputs:** Space (retry/continue), Z (main).
* **Transitions:**

  * Retry → **S2**
  * Continue → **S1**

#### 14.3 Global Input Map (per state)

* **Common:** Arrows (navigate), Space (confirm), Z (back), M (info toggle), N (end turn in S4 only), B/G/C (only in S4b).
* **Overlays (S4a–S4d):** consume input; underlying S4 paused until overlay closes.

#### 14.4 Pause/Resume Rules

* **S4 overlays** pause world updates; UI-only.
* End-turn resolution runs only in **S4** (no overlays active).

#### 14.5 Battle Window State Table (S4d)

| Substate        | Description                                          | Visible UI                      | Flags                                                                                          | Inputs                                    | Transition                                                              |
| --------------- | ---------------------------------------------------- | ------------------------------- | ---------------------------------------------------------------------------------------------- | ----------------------------------------- | ----------------------------------------------------------------------- |
| `pre_modal`     | Teams visible L/R; darkened bg; small modal centered | Modal: Start Battle / Edit Team | `overlay_active=1`, `modal_active=1`, `battle_active=0`, `registry_active=0`, `input_locked=0` | Arrows/Space choose; Z cancel             | Space(Start)→`battling`; Space(Edit)→`editing_team`; Z→close overlay→S4 |
| `editing_team`  | Opens Registry/Formation overlay                     | Registry panel                  | `overlay_active=1`, `modal_active=0`, `battle_active=0`, `registry_active=1`, `input_locked=0` | Registry controls (Arrows/Space/B/G/C), Z | Z→return `pre_modal`                                                    |
| `battling`      | Auto battle resolves                                 | Side teams, timers, hp bars     | `overlay_active=1`, `modal_active=0`, `battle_active=1`, `registry_active=0`, `input_locked=1` | (none)                                    | On result → `result_banner`                                             |
| `result_banner` | Victory/Defeat banner shown                          | Banner overlay                  | `overlay_active=1`, `modal_active=0`, `battle_active=0`, `registry_active=0`, `input_locked=0` | Space                                     | Space→`closing`                                                         |
| `closing`       | Close battle, pan camera, apply outcome              | Map camera                      | `overlay_active=0`, `camera_panning=1`                                                         | (none)                                    | On pan complete → return to **S4**                                      |

**Hooks/Signals**

* `battle_started(battle_id)` → emitted on entering `battling`.
* `battle_resolved(battle_id, result)` → emitted on entering `result_banner`.
* `battle_closed(battle_id, result)` → after `closing` finishes and S4 resumes.

---

*(End of v3.1 — expanded, with clean JSON templates, full UI overview, and state/logic scaffold + battle window state table.)*
