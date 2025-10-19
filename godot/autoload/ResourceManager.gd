extends Node

signal resources_changed()
signal item_changed(item: String)

var amounts: Dictionary = {
        "nature": 0,
        "earth": 0,
        "water": 0,
        "life": 0,
}

var capacity: Dictionary = {
        "nature": 0,
        "earth": 0,
        "water": 0,
        "life": 999999,
}

var soul_seeds: int = 0

var _tiles: Array = []
var _tile_rules: Dictionary = {}
var _rules_by_category: Dictionary = {}
var _by_category: Dictionary = {}
var _world: Node = null
var _turn_counter: int = 1

func _ready() -> void:
        _load_tile_rules()
        _connect_turn_engine()
        _connect_battle_manager()

func bind_world(world: Node) -> void:
        _world = world

func get_amount(kind: String) -> int:
        return int(amounts.get(kind, 0))

func get_capacity(kind: String) -> int:
        return int(capacity.get(kind, 0))

func add(kind: String, val: int) -> void:
        if not amounts.has(kind):
                return
        var next_value: int = amounts[kind] + val
        amounts[kind] = clamp(next_value, 0, get_capacity(kind))
        emit_signal("resources_changed")

func spend(kind: String, val: int) -> bool:
        if not amounts.has(kind):
                return false
        if amounts[kind] < val:
                return false
        amounts[kind] -= val
        emit_signal("resources_changed")
        return true

func add_life(val: int) -> void:
        amounts["life"] = max(0, amounts["life"] + val)
        emit_signal("resources_changed")

func add_soul_seed(val: int = 1) -> void:
        soul_seeds = max(0, soul_seeds + val)
        emit_signal("item_changed", "soul_seeds")

func _on_turn_started(turn: int) -> void:
        _turn_counter = turn

func _on_phase_started(name: String) -> void:
        if name == "resources":
                _recompute_capacity()
                _produce_resources()
                emit_signal("resources_changed")

func _on_battle_result(victory: bool, rewards: Dictionary) -> void:
        if not victory:
                return
        var life_gain: int = int(rewards.get("life", 3))
        add_life(life_gain)

func _load_tile_rules() -> void:
        if not Engine.has_singleton("DataLite"):
                return
        _tiles = DataLite.load_json_array("res://data/tiles.json")
        for entry_variant in _tiles:
                if entry_variant is Dictionary:
                        var entry: Dictionary = entry_variant
                        var id: String = String(entry.get("id", ""))
                        if id.is_empty():
                                continue
                        var rules_variant: Variant = entry.get("rules", {})
                        var rules: Dictionary = rules_variant if rules_variant is Dictionary else {}
                        _tile_rules[id] = rules
                        var category: String = String(entry.get("category", ""))
                        if not _by_category.has(category):
                                _by_category[category] = []
                        _by_category[category].append(id)
                        if not _rules_by_category.has(category):
                                _rules_by_category[category] = rules

func _connect_turn_engine() -> void:
        var turn_engine: Node = null
        if Engine.has_singleton("TurnEngine"):
                turn_engine = get_node_or_null("/root/TurnEngine")
        elif Engine.has_singleton("Game"):
                turn_engine = get_node_or_null("/root/Game")
        if turn_engine == null:
                return
        if not turn_engine.is_connected("phase_started", Callable(self, "_on_phase_started")):
                turn_engine.connect("phase_started", Callable(self, "_on_phase_started"))
        if not turn_engine.is_connected("turn_started", Callable(self, "_on_turn_started")):
                turn_engine.connect("turn_started", Callable(self, "_on_turn_started"))

func _connect_battle_manager() -> void:
        var battle_manager: Node = get_node_or_null("/root/BattleManager")
        if battle_manager == null:
                return
        if not battle_manager.is_connected("battle_result", Callable(self, "_on_battle_result")):
                battle_manager.connect("battle_result", Callable(self, "_on_battle_result"))

func _recompute_capacity() -> void:
        capacity["nature"] = 0
        capacity["earth"] = 0
        capacity["water"] = 0
        if _world == null:
                return
        var width: int = int(_world.width)
        var height: int = int(_world.height)
        var producers: Dictionary = {
                "harvest": [],
                "build": [],
                "refine": [],
                "storage": [],
        }
        for y in range(height):
                for x in range(width):
                        var cell := Vector2i(x, y)
                        var category: String = _world.get_cell_name(_world.LAYER_LIFE, cell)
                        if producers.has(category):
                                producers[category].append(cell)
        capacity["nature"] += producers["harvest"].size() * 5
        capacity["earth"] += producers["build"].size() * 5
        capacity["water"] += producers["refine"].size() * 5
        for storage_cell in producers["storage"]:
                for neighbor in _world.neighbors_even_q(storage_cell):
                        var neighbor_category: String = _world.get_cell_name(_world.LAYER_LIFE, neighbor)
                        match neighbor_category:
                                "harvest":
                                        capacity["nature"] += 5
                                "build":
                                        capacity["earth"] += 5
                                "refine":
                                        capacity["water"] += 5
        for kind in ["nature", "earth", "water"]:
                amounts[kind] = clamp(amounts[kind], 0, capacity[kind])

func _produce_resources() -> void:
        if _world == null:
                return
        var width: int = int(_world.width)
        var height: int = int(_world.height)
        var harvest_rules: Dictionary = _rules_by_category.get("harvest", {})
        var refine_rules: Dictionary = _rules_by_category.get("refine", {})
        var upgrade_rules: Dictionary = _rules_by_category.get("upgrade", {})
        var nature_per_grove: int = int(harvest_rules.get("nature_per_adjacent_grove", 1))
        var refine_every: int = int(refine_rules.get("refine_every_turns", 2))
        if refine_every <= 0:
                refine_every = 1
        var consume_variant: Variant = refine_rules.get("consume", {"nature": 1, "earth": 1})
        var consume: Dictionary = consume_variant if consume_variant is Dictionary else {"nature": 1, "earth": 1}
        var produce_variant: Variant = refine_rules.get("produce", {"water": 1})
        var produce: Dictionary = produce_variant if produce_variant is Dictionary else {"water": 1}
        var upgrade_every: int = int(upgrade_rules.get("soul_seed_every_turns", 3))
        if upgrade_every <= 0:
                upgrade_every = 1
        for y in range(height):
                for x in range(width):
                        var cell := Vector2i(x, y)
                        if _world.get_cell_name(_world.LAYER_LIFE, cell) == "harvest":
                                var gain: int = _adjacent_grove_count(cell) * nature_per_grove
                                if gain > 0:
                                        amounts["nature"] = clamp(amounts["nature"] + gain, 0, capacity["nature"])
        for y in range(height):
                for x in range(width):
                        var cell := Vector2i(x, y)
                        if _world.get_cell_name(_world.LAYER_LIFE, cell) == "build":
                                var slowed: bool = _is_adjacent_to_category(cell, "harvest")
                                var produce_now: bool = true
                                if slowed:
                                        # Build tiles work at half speed when touching Harvest tiles.
                                        produce_now = (_turn_counter % 2) == 0
                                if produce_now:
                                        amounts["earth"] = clamp(amounts["earth"] + 1, 0, capacity["earth"])
        if _turn_counter % refine_every == 0:
                for y in range(height):
                        for x in range(width):
                                var cell := Vector2i(x, y)
                                if _world.get_cell_name(_world.LAYER_LIFE, cell) == "refine":
                                        var can_convert: bool = true
                                        for consume_kind in consume.keys():
                                                var need: int = int(consume[consume_kind])
                                                if amounts.get(consume_kind, 0) < need:
                                                        can_convert = false
                                                        break
                                        if not can_convert:
                                                continue
                                        for consume_kind in consume.keys():
                                                var need: int = int(consume[consume_kind])
                                                amounts[consume_kind] = max(0, amounts[consume_kind] - need)
                                        for produce_kind in produce.keys():
                                                var value: int = int(produce[produce_kind])
                                                if not amounts.has(produce_kind):
                                                        continue
                                                # Refiners transmute inputs into water at their cadence.
                                                amounts[produce_kind] = clamp(amounts[produce_kind] + value, 0, get_capacity(produce_kind))
        if _turn_counter % upgrade_every == 0:
                var upgrades: int = 0
                for y in range(height):
                        for x in range(width):
                                if _world.get_cell_name(_world.LAYER_LIFE, Vector2i(x, y)) == "upgrade":
                                        upgrades += 1
                if upgrades > 0:
                        # Upgrade tiles drip Soul Seeds on their cadence.
                        add_soul_seed(upgrades)

func _is_adjacent_to_category(cell: Vector2i, category: String) -> bool:
        if _world == null:
                return false
        for neighbor in _world.neighbors_even_q(cell):
                if _world.get_cell_name(_world.LAYER_LIFE, neighbor) == category:
                        return true
        return false

func _adjacent_grove_count(cell: Vector2i) -> int:
        if _world == null:
                return 0
        var total: int = 0
        for neighbor in _world.neighbors_even_q(cell):
                if _world.get_cell_name(_world.LAYER_LIFE, neighbor) == "grove":
                        total += 1
        return total
