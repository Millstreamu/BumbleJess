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
	var turn_engine: Node = get_node_or_null("/root/TurnEngine")
	if turn_engine == null and Engine.has_singleton("Game"):
		turn_engine = Engine.get_singleton("Game")
	if turn_engine == null:
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
			if cat == "upgrade":
				var totem_bonus_variant: Variant = r.get(
					"capacity_global_bonus_if_adjacent_to_totem", {}
				)
				var totem_bonus: Dictionary = (
					totem_bonus_variant if totem_bonus_variant is Dictionary else {}
				)
				if not totem_bonus.is_empty():
					var touches_totem := false
					for neighbor in _world.neighbors_even_q(cell):
						if _world.get_cell_name(_world.LAYER_OBJECTS, neighbor) == "totem":
							touches_totem = true
							break
					if touches_totem:
						for res in totem_bonus.keys():
							var add_value: int = int(totem_bonus[res])
							if add_value == 0:
								continue
							capacity[res] = int(capacity.get(res, 0)) + add_value

			var flat_bonus_variant: Variant = r.get("capacity_global_bonus", {})
			var flat_bonus: Dictionary = (
				flat_bonus_variant if flat_bonus_variant is Dictionary else {}
			)
			if not flat_bonus.is_empty():
				for res in flat_bonus.keys():
					var bonus_value: int = int(flat_bonus[res])
					if bonus_value == 0:
						continue
					capacity[res] = int(capacity.get(res, 0)) + bonus_value

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
				var aura_bonus: Dictionary = add_variant
				for res in aura_bonus.keys():
					var value: int = int(aura_bonus[res])
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
				var nature_fx_variant: Variant = fx.get("fx_nature", [])
				var nature_fx: Array = nature_fx_variant if nature_fx_variant is Array else []
				if not nature_fx.has(cell):
					nature_fx.append(cell)
				fx["fx_nature"] = nature_fx

			var per_turn: int = int(r.get("nature_per_turn", 0))
			if per_turn > 0:
				var blocked_variant: Variant = r.get("blocked_if_adjacent_any", [])
				var blocked_list: Array = (
					blocked_variant if blocked_variant is Array else []
				)
				if blocked_variant is PackedStringArray:
					blocked_list = Array(blocked_variant)
				var blocked := false
				for neighbor in _world.neighbors_even_q(cell):
					var neighbor_cat: String = _world.get_cell_name(
						_world.LAYER_LIFE, neighbor
					)
					if blocked_list.has(neighbor_cat):
						blocked = true
						break
				if not blocked:
					var cap_value: int = int(capacity.get("nature", 0))
					amounts["nature"] = clamp(
						int(amounts.get("nature", 0)) + per_turn,
						0,
						cap_value,
					)
					var bloom_fx_variant: Variant = fx.get("fx_nature", [])
					var bloom_fx: Array = (
						bloom_fx_variant if bloom_fx_variant is Array else []
					)
					if not bloom_fx.has(cell):
						bloom_fx.append(cell)
					fx["fx_nature"] = bloom_fx

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
				var earth_fx_variant: Variant = fx.get("fx_earth", [])
				var earth_fx: Array = earth_fx_variant if earth_fx_variant is Array else []
				if not earth_fx.has(cell):
					earth_fx.append(cell)
				fx["fx_earth"] = earth_fx

			var extra_every: int = int(r.get("earth_every_turns", 0))
			if extra_every < 0:
				extra_every = abs(extra_every)
			if extra_every > 0 and (_turn_counter % max(extra_every, 1)) == 0:
				var needs_variant: Variant = r.get("requires_adjacent_any", [])
				var needs: Array = needs_variant if needs_variant is Array else []
				if needs_variant is PackedStringArray:
					needs = Array(needs_variant)
				elif typeof(needs_variant) == TYPE_STRING:
					needs = [String(needs_variant)]
				if needs.is_empty():
					needs = ["guard", "root"]
				var ok := false
				for neighbor in _world.neighbors_even_q(cell):
					var neighbor_cat: String = _world.get_cell_name(
						_world.LAYER_LIFE, neighbor
					)
					if needs.has(neighbor_cat):
						ok = true
						break
				if ok:
					var cap_value: int = int(capacity.get("earth", 0))
					amounts["earth"] = clamp(
						int(amounts.get("earth", 0)) + 1,
						0,
						cap_value,
					)
					var vein_fx_variant: Variant = fx.get("fx_earth", [])
					var vein_fx: Array = (
						vein_fx_variant if vein_fx_variant is Array else []
					)
					if not vein_fx.has(cell):
						vein_fx.append(cell)
					fx["fx_earth"] = vein_fx

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
				var water_fx_variant: Variant = fx.get("fx_water", [])
				var water_fx: Array = water_fx_variant if water_fx_variant is Array else []
				if not water_fx.has(cell):
					water_fx.append(cell)
				fx["fx_water"] = water_fx
			if bool(r.get("per_unique_adjacent_categories", false)):
				var every_special: int = int(r.get("water_every_turns", every))
				if every_special <= 0:
					every_special = 1
				if (_turn_counter % every_special) == 0:
					var unique: Dictionary = {}
					for neighbor in _world.neighbors_even_q(cell):
						var neighbor_cat: String = _world.get_cell_name(
							_world.LAYER_LIFE,
							neighbor,
						)
						if neighbor_cat.is_empty():
							continue
						unique[neighbor_cat] = true
					var gain := unique.size()
					var max_gain: int = int(r.get("max_per_tick", 3))
					if max_gain > 0:
						gain = min(gain, max_gain)
					else:
						gain = 0
					if gain > 0:
						var cap_value: int = int(capacity.get("water", 0))
						amounts["water"] = clamp(
							int(amounts.get("water", 0)) + gain,
							0,
							cap_value,
						)
						var span_fx_variant: Variant = fx.get("fx_water", [])
						var span_fx: Array = (
							span_fx_variant if span_fx_variant is Array else []
						)
						if not span_fx.has(cell):
							span_fx.append(cell)
						fx["fx_water"] = span_fx

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
