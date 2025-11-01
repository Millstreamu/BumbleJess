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

#### 3.2 Tile JSON Example

```json
{
  "id": "tile.whispering_pine_forest",  // Unique identifier
  "category": "Nature",
  "tags": ["forest", "organic"],
  "outputs": {"nature": 2},  // Produces 2 Nature per turn
  "synergies": [
    {"tag": "forest", "bonus": {"nature": +1}}  // +1 if touching another forest tile
  ],
  "can_generate_overgrowth": false,
  "unique": null  // Not a unique tile
}
```

---

### 4) Overgrowth & Grove

* Created by specific tiles (e.g., *Moss Terrace*) or enclosure.
* After 3 turns → becomes a **Grove** and spawns one Sprout of your selected types.
* Decay spreads easily through Overgrowth/Groves but does not destroy them instantly.

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
  "id": "map.demo_001",
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

*(End of v3.1 — expanded and annotated for implementation.)*
