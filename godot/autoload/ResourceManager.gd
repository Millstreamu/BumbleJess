extends Node

signal resources_changed()
signal item_changed(item: String)
signal produced_cells(cells_by_fx: Dictionary)

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
var _rules_by_id: Dictionary = {}
var _category_by_id: Dictionary = {}
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
		if not Engine.has_singleton("DataLite"):
				return
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

func _rule(id: String, key: String, default_value = null):
		var rules_variant: Variant = _rules_by_id.get(id, {})
		var rules: Dictionary = rules_variant if rules_variant is Dictionary else {}
		return rules.get(key, default_value)

func _add_capacity(kind: String, value: int) -> void:
		var previous: int = int(capacity.get(kind, 0))
		capacity[kind] = previous + value
		if not amounts.has(kind):
				amounts[kind] = 0

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
		for key in capacity.keys():
				if key == "life":
						continue
				capacity[key] = 0
		if _world == null:
				return
		var width: int = int(_world.width)
		var height: int = int(_world.height)

		for y in range(height):
				for x in range(width):
						var cell := Vector2i(x, y)
						var base_category: String = _world.get_cell_name(_world.LAYER_LIFE, cell)
						if base_category.is_empty():
								continue
						var id: String = _world.get_cell_tile_id(_world.LAYER_LIFE, cell)
						var category: String = base_category
						if not id.is_empty():
								category = String(_category_by_id.get(id, base_category))
						var cap_base_variant: Variant = _rule(id, "capacity_base", {})
						var cap_base: Dictionary = cap_base_variant if cap_base_variant is Dictionary else {}
						if cap_base.is_empty():
								match category:
										"harvest":
												cap_base = {"nature": 5}
										"build":
												cap_base = {"earth": 5}
										"refine":
												cap_base = {"water": 5}
										_:
												cap_base = {}
						for res in cap_base.keys():
								var value: int = int(cap_base[res])
								if value == 0:
										continue
								_add_capacity(res, value)

		for y in range(height):
				for x in range(width):
						var cell := Vector2i(x, y)
						var base_category: String = _world.get_cell_name(_world.LAYER_LIFE, cell)
						if base_category.is_empty():
								continue
						var id: String = _world.get_cell_tile_id(_world.LAYER_LIFE, cell)
						var category: String = base_category
						if not id.is_empty():
								category = String(_category_by_id.get(id, base_category))
						var aura_variant: Variant = _rule(id, "capacity_aura_adjacent", {})
						var aura: Dictionary = aura_variant if aura_variant is Dictionary else {}
						if aura.is_empty() and category == "storage":
								aura = {
										"harvest": {"nature": 5},
										"build": {"earth": 5},
										"refine": {"water": 5},
								}
						if aura.is_empty():
								continue
						for neighbor in _world.neighbors_even_q(cell):
								var neighbor_category: String = _world.get_cell_name(_world.LAYER_LIFE, neighbor)
								if neighbor_category.is_empty():
										continue
								var bonus_variant: Variant = aura.get(neighbor_category, null)
								if bonus_variant is Dictionary:
										var bonus: Dictionary = bonus_variant
										for res in bonus.keys():
												var value: int = int(bonus[res])
												if value == 0:
														continue
												_add_capacity(res, value)

		for key in capacity.keys():
				if key == "life":
						continue
				var cap_value: int = int(capacity[key])
				if not amounts.has(key):
						amounts[key] = 0
				amounts[key] = clamp(int(amounts[key]), 0, cap_value)

func _produce_resources() -> void:
		if _world == null:
				return
		var fx: Dictionary = {
				"fx_nature": [],
				"fx_earth": [],
				"fx_water": [],
				"fx_seed": [],
		}
		var width: int = int(_world.width)
		var height: int = int(_world.height)

		for y in range(height):
				for x in range(width):
						var cell := Vector2i(x, y)
						var base_category: String = _world.get_cell_name(_world.LAYER_LIFE, cell)
						if base_category.is_empty():
								continue
						var id: String = _world.get_cell_tile_id(_world.LAYER_LIFE, cell)
						var category: String = base_category
						if not id.is_empty():
								category = String(_category_by_id.get(id, base_category))

						if category == "harvest":
								var per_adjacent_variant: Variant = _rule(id, "nature_per_adjacent", {"grove": 1})
								var per_adjacent: Dictionary = per_adjacent_variant if per_adjacent_variant is Dictionary else {"grove": 1}
								if per_adjacent.is_empty():
										per_adjacent = {"grove": 1}
								var total_gain: int = 0
								for target_category in per_adjacent.keys():
										var per_value: int = int(per_adjacent[target_category])
										if per_value == 0:
												continue
										var adjacent_count: int = 0
										for neighbor in _world.neighbors_even_q(cell):
												if _world.get_cell_name(_world.LAYER_LIFE, neighbor) == target_category:
														adjacent_count += 1
										total_gain += per_value * adjacent_count
								if total_gain > 0:
										if not amounts.has("nature"):
												amounts["nature"] = 0
										var cap: int = int(capacity.get("nature", 0))
										amounts["nature"] = clamp(int(amounts["nature"]) + total_gain, 0, cap)
										var nature_list_variant: Variant = fx.get("fx_nature", null)
										if nature_list_variant is Array:
												var nature_list: Array = nature_list_variant
												nature_list.append(cell)
												fx["fx_nature"] = nature_list

						elif category == "build":
								var per_turn: int = int(_rule(id, "earth_per_turn", 1))
								if per_turn <= 0:
										continue
								var slows_variant: Variant = _rule(id, "slow_if_adjacent_any", ["harvest"])
								var slows: Array = []
								if slows_variant is Array:
										slows = slows_variant
								elif slows_variant is PackedStringArray:
										slows = Array(slows_variant)
								var slow_multiplier: int = int(_rule(id, "slow_multiplier", 2))
								if slow_multiplier <= 0:
										slow_multiplier = 1
								var slowed: bool = false
								for neighbor in _world.neighbors_even_q(cell):
										var neighbor_category: String = _world.get_cell_name(_world.LAYER_LIFE, neighbor)
										if slows.has(neighbor_category):
												slowed = true
												break
								var produce_now: bool = true
								if slowed:
										produce_now = (_turn_counter % slow_multiplier) == 0
								if produce_now:
										if not amounts.has("earth"):
												amounts["earth"] = 0
										var cap: int = int(capacity.get("earth", 0))
										amounts["earth"] = clamp(int(amounts["earth"]) + per_turn, 0, cap)
										var earth_list_variant: Variant = fx.get("fx_earth", null)
										if earth_list_variant is Array:
												var earth_list: Array = earth_list_variant
												earth_list.append(cell)
												fx["fx_earth"] = earth_list

						elif category == "refine":
								var every: int = int(_rule(id, "refine_every_turns", 2))
								if every <= 0:
										every = 1
								if (_turn_counter % every) != 0:
										continue
								var consume_variant: Variant = _rule(id, "consume", {"nature": 1, "earth": 1})
								var consume: Dictionary = consume_variant if consume_variant is Dictionary else {"nature": 1, "earth": 1}
								var produce_variant: Variant = _rule(id, "produce", {"water": 1})
								var produce: Dictionary = produce_variant if produce_variant is Dictionary else {"water": 1}
								var can_convert: bool = true
								for consume_kind in consume.keys():
										var need: int = int(consume[consume_kind])
										if need <= 0:
												continue
										if int(amounts.get(consume_kind, 0)) < need:
												can_convert = false
												break
								if not can_convert:
										continue
								var produced_any: bool = false
								for consume_kind in consume.keys():
										var need: int = int(consume[consume_kind])
										if need <= 0:
												continue
										var current_amount: int = int(amounts.get(consume_kind, 0))
										amounts[consume_kind] = max(0, current_amount - need)
								for produce_kind in produce.keys():
										var value: int = int(produce[produce_kind])
										if value == 0:
												continue
										if not amounts.has(produce_kind):
												amounts[produce_kind] = 0
										var cap: int = int(capacity.get(produce_kind, 0))
										amounts[produce_kind] = clamp(int(amounts[produce_kind]) + value, 0, cap)
										produced_any = true
								if produced_any:
										var water_list_variant: Variant = fx.get("fx_water", null)
										if water_list_variant is Array:
												var water_list: Array = water_list_variant
												water_list.append(cell)
												fx["fx_water"] = water_list

						elif category == "upgrade":
								var every_seeds: int = int(_rule(id, "soul_seed_every_turns", 3))
								if every_seeds <= 0:
										every_seeds = 1
								if (_turn_counter % every_seeds) == 0:
										add_soul_seed(1)
										var seed_list_variant: Variant = fx.get("fx_seed", null)
										if seed_list_variant is Array:
												var seed_list: Array = seed_list_variant
												seed_list.append(cell)
												fx["fx_seed"] = seed_list

		var empty_keys: Array = []
		for key in fx.keys():
				var cells_variant: Variant = fx[key]
				if cells_variant is Array:
						var cells_list: Array = cells_variant
						if cells_list.is_empty():
								empty_keys.append(key)
				else:
						empty_keys.append(key)
		for key in empty_keys:
				fx.erase(key)
		emit_signal("produced_cells", fx)
