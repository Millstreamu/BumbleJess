extends Node

signal resources_changed()
signal item_changed(item: String)
signal produced_cells(cells_by_fx: Dictionary)

var amounts := {
    "nature": 0,
    "earth": 0,
    "water": 0,
    "life": 0,
}

var capacity := {
    "nature": 0,
    "earth": 0,
    "water": 0,
    "life": 999999,
}

var soul_seeds := 0

var _world: Node = null
var _turn_counter := 1
var _tiles: Array = []
var _rules_by_id: Dictionary = {}
var _category_by_id: Dictionary = {}
var _defaults_by_category := {
    "harvest": {
        "capacity_base": {"nature": 5},
        "nature_per_adjacent": {"grove": 1},
    },
    "build": {
        "capacity_base": {"earth": 5},
        "earth_per_turn": 1,
        "slow_if_adjacent_any": ["harvest"],
        "slow_multiplier": 2,
    },
    "refine": {
        "capacity_base": {"water": 5},
        "refine_every_turns": 2,
        "consume": {"nature": 1, "earth": 1},
        "produce": {"water": 1},
    },
    "storage": {
        "capacity_aura_adjacent": {
            "harvest": {"nature": 5},
            "build": {"earth": 5},
            "refine": {"water": 5},
        },
    },
    "upgrade": {
        "soul_seed_every_turns": 3,
    },
}

func _ready() -> void:
    _load_tile_rules()
    _connect_turn_engine()
    _connect_battle_manager()

func bind_world(world: Node) -> void:
    _world = world

func add(kind: String, val: int) -> void:
    if not amounts.has(kind):
        return
    var next_value: int = int(amounts[kind]) + val
    var cap_value: int = get_capacity(kind)
    amounts[kind] = clamp(next_value, 0, cap_value)
    emit_signal("resources_changed")

func add_life(val: int) -> void:
    amounts["life"] = max(0, int(amounts.get("life", 0)) + val)
    emit_signal("resources_changed")

func add_soul_seed(val: int = 1) -> void:
    soul_seeds = max(0, soul_seeds + val)
    emit_signal("item_changed", "soul_seeds")

func get_amount(kind: String) -> int:
    return int(amounts.get(kind, 0))

func get_capacity(kind: String) -> int:
    return int(capacity.get(kind, 0))

func spend(kind: String, val: int) -> bool:
    if not amounts.has(kind):
        return false
    if int(amounts[kind]) < val:
        return false
    amounts[kind] = int(amounts[kind]) - val
    emit_signal("resources_changed")
    return true

func _on_turn_started(turn: int) -> void:
    _turn_counter = turn

func _on_phase_started(phase_name: String) -> void:
    if phase_name == "resources":
        _recompute_capacity()
        _produce_resources()
        emit_signal("resources_changed")

func _on_battle_result(victory: bool, rewards: Dictionary) -> void:
    if not victory:
        return
    var life_gain: int = int(rewards.get("life", 3))
    add_life(life_gain)

func _load_tile_rules() -> void:
    _tiles = DataLite.load_json_array("res://data/tiles.json")
    _rules_by_id.clear()
    _category_by_id.clear()
    for entry_variant in _tiles:
        if entry_variant is Dictionary:
            var entry: Dictionary = entry_variant
            var id: String = String(entry.get("id", ""))
            if id.is_empty():
                continue
            var category: String = String(entry.get("category", ""))
            _category_by_id[id] = category
            var rules_variant: Variant = entry.get("rules", {})
            var rules: Dictionary = rules_variant if rules_variant is Dictionary else {}
            _rules_by_id[id] = rules

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

func _rules_for(id: String, cat: String) -> Dictionary:
    var result: Dictionary = {}
    var defaults_variant: Variant = _defaults_by_category.get(cat, {})
    if defaults_variant is Dictionary:
        result = (defaults_variant as Dictionary).duplicate(true)
    var specific_variant: Variant = _rules_by_id.get(id, {})
    if specific_variant is Dictionary:
        var specific: Dictionary = specific_variant
        if result.is_empty():
            return specific.duplicate(true)
        for key in specific.keys():
            result[key] = specific[key]
        return result
    return result

func _cell_id_and_cat(c: Vector2i) -> Array:
    if _world == null:
        return ["", ""]
    var id: String = ""
    if _world.has_method("get_cell_tile_id"):
        id = String(_world.get_cell_tile_id(_world.LAYER_LIFE, c))
    if id.is_empty():
        var meta = null
        if _world.has_method("get_cell_meta"):
            meta = _world.get_cell_meta(_world.LAYER_LIFE, c, "id")
        if typeof(meta) == TYPE_STRING:
            id = meta
    var cat: String = _world.get_cell_name(_world.LAYER_LIFE, c)
    if not id.is_empty():
        cat = String(_category_by_id.get(id, cat))
    return [id, cat]

func _recompute_capacity() -> void:
    for key in capacity.keys():
        if key == "life":
            continue
        capacity[key] = 0
    if _world == null:
        return
    var width := int(_world.width)
    var height := int(_world.height)

    for y in range(height):
        for x in range(width):
            var cell := Vector2i(x, y)
            var pair := _cell_id_and_cat(cell)
            var id: String = pair[0]
            var cat: String = pair[1]
            if cat.is_empty():
                continue
            var r: Dictionary = _rules_for(id, cat)
            var base_variant: Variant = r.get("capacity_base", {})
            var base: Dictionary = base_variant if base_variant is Dictionary else {}
            for res in base.keys():
                var amount: int = int(base[res])
                if amount == 0:
                    continue
                capacity[res] = int(capacity.get(res, 0)) + amount

    for y in range(height):
        for x in range(width):
            var cell := Vector2i(x, y)
            var pair := _cell_id_and_cat(cell)
            var id: String = pair[0]
            var cat: String = pair[1]
            if cat.is_empty():
                continue
            var aura_variant: Variant = _rules_for(id, cat).get("capacity_aura_adjacent", {})
            var aura: Dictionary = aura_variant if aura_variant is Dictionary else {}
            if aura.is_empty():
                continue
            for neighbor in _world.neighbors_even_q(cell):
                var neighbor_cat: String = _world.get_cell_name(_world.LAYER_LIFE, neighbor)
                if neighbor_cat.is_empty():
                    continue
                if not aura.has(neighbor_cat):
                    continue
                var add_variant: Variant = aura[neighbor_cat]
                if not (add_variant is Dictionary):
                    continue
                var add: Dictionary = add_variant
                for res in add.keys():
                    var value: int = int(add[res])
                    if value == 0:
                        continue
                    capacity[res] = int(capacity.get(res, 0)) + value

    for res in capacity.keys():
        if res == "life":
            continue
        var cap_value: int = int(capacity.get(res, 0))
        amounts[res] = clamp(int(amounts.get(res, 0)), 0, cap_value)

func _produce_resources() -> void:
    if _world == null:
        return
    var width := int(_world.width)
    var height := int(_world.height)
    var fx := {
        "fx_nature": [],
        "fx_earth": [],
        "fx_water": [],
        "fx_seed": [],
    }

    for y in range(height):
        for x in range(width):
            var cell := Vector2i(x, y)
            var pair := _cell_id_and_cat(cell)
            var id: String = pair[0]
            var cat: String = pair[1]
            if cat != "harvest":
                continue
            var r: Dictionary = _rules_for(id, cat)
            var per_adj_variant: Variant = r.get("nature_per_adjacent", {})
            var per_adj: Dictionary = per_adj_variant if per_adj_variant is Dictionary else {}
            var total := 0
            for need_cat in per_adj.keys():
                var per := int(per_adj[need_cat])
                if per == 0:
                    continue
                var count := 0
                for neighbor in _world.neighbors_even_q(cell):
                    if _world.get_cell_name(_world.LAYER_LIFE, neighbor) == need_cat:
                        count += 1
                total += per * count
            if total > 0:
                amounts["nature"] = clamp(int(amounts.get("nature", 0)) + total, 0, int(capacity.get("nature", 0)))
                var nature_fx: Array = fx.get("fx_nature", [])
                nature_fx.append(cell)
                fx["fx_nature"] = nature_fx

    for y in range(height):
        for x in range(width):
            var cell := Vector2i(x, y)
            var pair := _cell_id_and_cat(cell)
            var id: String = pair[0]
            var cat: String = pair[1]
            if cat != "build":
                continue
            var r: Dictionary = _rules_for(id, cat)
            var per_turn: int = int(r.get("earth_per_turn", 1))
            if per_turn <= 0:
                continue
            var slows_variant: Variant = r.get("slow_if_adjacent_any", [])
            var slows: Array = slows_variant if slows_variant is Array else []
            if slows_variant is PackedStringArray:
                slows = Array(slows_variant)
            var mult: int = int(r.get("slow_multiplier", 2))
            if mult <= 0:
                mult = 1
            var slowed := false
            for neighbor in _world.neighbors_even_q(cell):
                var neighbor_cat: String = _world.get_cell_name(_world.LAYER_LIFE, neighbor)
                if slows.has(neighbor_cat):
                    slowed = true
                    break
            var produce_now := true
            if slowed:
                produce_now = (_turn_counter % mult) == 0
            if produce_now:
                amounts["earth"] = clamp(int(amounts.get("earth", 0)) + per_turn, 0, int(capacity.get("earth", 0)))
                var earth_fx: Array = fx.get("fx_earth", [])
                earth_fx.append(cell)
                fx["fx_earth"] = earth_fx

    for y in range(height):
        for x in range(width):
            var cell := Vector2i(x, y)
            var pair := _cell_id_and_cat(cell)
            var id: String = pair[0]
            var cat: String = pair[1]
            if cat != "refine":
                continue
            var r: Dictionary = _rules_for(id, cat)
            var every: int = int(r.get("refine_every_turns", 2))
            if every <= 0:
                every = 1
            if (_turn_counter % every) != 0:
                continue
            var consume_variant: Variant = r.get("consume", {})
            var consume: Dictionary = consume_variant if consume_variant is Dictionary else {}
            var produce_variant: Variant = r.get("produce", {})
            var produce: Dictionary = produce_variant if produce_variant is Dictionary else {}
            var can_convert := true
            for k in consume.keys():
                var need: int = int(consume[k])
                if need <= 0:
                    continue
                if int(amounts.get(k, 0)) < need:
                    can_convert = false
                    break
            if not can_convert:
                continue
            for k in consume.keys():
                var need: int = int(consume[k])
                if need <= 0:
                    continue
                amounts[k] = max(0, int(amounts.get(k, 0)) - need)
            var produced_any := false
            for k in produce.keys():
                var value: int = int(produce[k])
                if value == 0:
                    continue
                var cap_value: int = int(capacity.get(k, 0))
                amounts[k] = clamp(int(amounts.get(k, 0)) + value, 0, cap_value)
                produced_any = true
            if produced_any:
                var water_fx: Array = fx.get("fx_water", [])
                water_fx.append(cell)
                fx["fx_water"] = water_fx

    for y in range(height):
        for x in range(width):
            var cell := Vector2i(x, y)
            var pair := _cell_id_and_cat(cell)
            var id: String = pair[0]
            var cat: String = pair[1]
            if cat != "upgrade":
                continue
            var r: Dictionary = _rules_for(id, cat)
            var every: int = int(r.get("soul_seed_every_turns", 3))
            if every <= 0:
                every = 1
            if (_turn_counter % every) == 0:
                add_soul_seed(1)
                var seed_fx: Array = fx.get("fx_seed", [])
                seed_fx.append(cell)
                fx["fx_seed"] = seed_fx

    var empty_keys: Array = []
    for key in fx.keys():
        var cells_variant: Variant = fx[key]
        if cells_variant is Array:
            if (cells_variant as Array).is_empty():
                empty_keys.append(key)
        else:
            empty_keys.append(key)
    for key in empty_keys:
        fx.erase(key)
    if not fx.is_empty():
        emit_signal("produced_cells", fx)
