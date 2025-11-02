extends Node

const CAT_NATURE := "Nature"
const CAT_EARTH := "Earth"
const CAT_WATER := "Water"
const CAT_NEST := "Nest"
const CAT_AGGRESSION := "Aggression"
const CAT_MYSTIC := "Mystic"

signal resources_changed
signal item_changed(item: String)
signal produced_cells(cells_by_fx: Dictionary)

const FX_KEY_BY_RESOURCE := {
	"nature": "fx_nature",
	"earth": "fx_earth",
	"water": "fx_water",
	"soul_seed": "fx_seed",
}

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
var _bonus_mults := {"nature": 1.0, "earth": 1.0, "water": 1.0}
var _defaults_by_category := {
	CAT_NATURE:
	{
		"capacity_base": {"nature": 5},
		"nature_per_adjacent": {"grove": 1},
	},
	CAT_EARTH:
	{
		"capacity_base": {"earth": 5},
		"earth_per_turn": 1,
		"slow_if_adjacent_any": [CAT_NATURE],
		"slow_multiplier": 2,
	},
	CAT_WATER:
	{
		"capacity_base": {"water": 5},
		"refine_every_turns": 2,
		"consume": {"nature": 1, "earth": 1},
		"produce": {"water": 1},
	},
	CAT_NEST:
	{
		"capacity_aura_adjacent":
		{
			CAT_NATURE: {"nature": 5},
			CAT_EARTH: {"earth": 5},
			CAT_WATER: {"water": 5},
		},
	},
	CAT_MYSTIC:
	{
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


func apply_resource_bonus(kind: String, mult: float) -> void:
	var key := String(kind)
	if key.is_empty():
		return
	var current := float(_bonus_mults.get(key, 1.0))
	var next_value := current * mult
	if next_value <= 0.0:
		next_value = 0.0
	_bonus_mults[key] = next_value
	print("Resource bonus for %s now x%.2f" % [key, next_value])


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


func tick_production_phase(turn: int) -> void:
	_turn_counter = max(turn, 1)
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
                        var canonical_category := String(DataDB.get_category_for_id(id))
                        if canonical_category.is_empty():
                                canonical_category = CategoryMap.canonical(category)
                        _category_by_id[id] = canonical_category
                        var rules_variant: Variant = entry.get("rules", {})
                        var rules: Dictionary = rules_variant if rules_variant is Dictionary else {}
                        _rules_by_id[id] = rules


func _connect_turn_engine() -> void:
	var turn_engine: Node = _get_turn_engine()
	if turn_engine == null:
		return
	if (
		turn_engine.has_signal("run_started")
		and not turn_engine.is_connected("run_started", Callable(self, "_on_run_started"))
	):
		turn_engine.connect("run_started", Callable(self, "_on_run_started"))
	if (
		turn_engine.has_signal("turn_changed")
		and not turn_engine.is_connected("turn_changed", Callable(self, "_on_turn_changed"))
	):
		turn_engine.connect("turn_changed", Callable(self, "_on_turn_changed"))
	_on_run_started()


func _on_run_started() -> void:
	var engine: Node = _get_turn_engine()
	if engine == null:
		_turn_counter = 1
		return
	var value: Variant = engine.get("turn_index")
	if typeof(value) == TYPE_INT:
		_turn_counter = max(int(value), 1)
	else:
		_turn_counter = 1


func _on_turn_changed(turn: int) -> void:
	_turn_counter = max(turn, 1)


func _get_turn_engine() -> Node:
	var turn_engine: Node = null
	if Engine.has_singleton("TurnEngine"):
		var singleton := Engine.get_singleton("TurnEngine")
		if singleton is Node:
			turn_engine = singleton
	if turn_engine == null:
		turn_engine = get_node_or_null("/root/TurnEngine")
	if turn_engine == null and Engine.has_singleton("Game"):
		var game_singleton := Engine.get_singleton("Game")
		if game_singleton is Node:
			turn_engine = game_singleton
	if turn_engine == null:
		turn_engine = get_node_or_null("/root/Game")
	return turn_engine


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
        var cat: String = ""
        if _world.has_method("get_cell_meta"):
                var meta_cat: Variant = _world.get_cell_meta(_world.LAYER_LIFE, c, "category")
                if typeof(meta_cat) == TYPE_STRING:
                        cat = String(meta_cat)
        if id.is_empty():
                var meta: Variant = null
                if _world.has_method("get_cell_meta"):
                        meta = _world.get_cell_meta(_world.LAYER_LIFE, c, "id")
                if typeof(meta) == TYPE_STRING:
                        id = String(meta)
        if not id.is_empty():
                var cached_cat: Variant = _category_by_id.get(id, null)
                if typeof(cached_cat) == TYPE_STRING and not String(cached_cat).is_empty():
                        cat = String(cached_cat)
                if cat.is_empty():
                        cat = String(DataDB.get_category_for_id(id))
        if cat.is_empty():
                cat = _world.get_cell_name(_world.LAYER_LIFE, c)
        cat = CategoryMap.canonical(cat)
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
			if cat == CAT_MYSTIC:
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
			var aura: Dictionary = _canonicalize_dict_keys(aura_variant)
			if aura.is_empty():
				continue
			for neighbor in _world.neighbors_even_q(cell):
				var neighbor_cat: String = CategoryMap.canonical(
					String(_world.get_cell_name(_world.LAYER_LIFE, neighbor))
				)
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
        var tracked_resources: Array[String] = []
        for res_key in _bonus_mults.keys():
                tracked_resources.append(String(res_key))
        var baseline: Dictionary = _snapshot_resource_amounts(tracked_resources)
	var fx := {
		"fx_nature": [],
		"fx_earth": [],
		"fx_water": [],
		"fx_seed": [],
	}

	var skip_cells := _produce_resources_v31_outputs_and_synergies(fx)

	for y in range(height):
		for x in range(width):
			var cell := Vector2i(x, y)
			var pair := _cell_id_and_cat(cell)
			var id: String = pair[0]
			var cat: String = pair[1]
			if cat != CAT_NATURE:
				continue
			if skip_cells.has(cell):
				continue
			var r: Dictionary = _rules_for(id, cat)
			var per_adj: Dictionary = _canonicalize_dict_keys(r.get("nature_per_adjacent", {}))
			var total := 0
			for need_cat in per_adj.keys():
				var per := int(per_adj[need_cat])
				if per == 0:
					continue
				var count := 0
				for neighbor in _world.neighbors_even_q(cell):
					var neighbor_cat := CategoryMap.canonical(
						String(_world.get_cell_name(_world.LAYER_LIFE, neighbor))
					)
					if neighbor_cat == need_cat:
						count += 1
				total += per * count
			if total > 0:
				amounts["nature"] = clamp(
					int(amounts.get("nature", 0)) + total, 0, int(capacity.get("nature", 0))
				)
				var nature_fx_variant: Variant = fx.get("fx_nature", [])
				var nature_fx: Array = nature_fx_variant if nature_fx_variant is Array else []
				if not nature_fx.has(cell):
					nature_fx.append(cell)
				fx["fx_nature"] = nature_fx

			var per_turn: int = int(r.get("nature_per_turn", 0))
			if per_turn > 0:
				var blocked_list: Array = _canonicalize_array(r.get("blocked_if_adjacent_any", []))
				var blocked := false
				for neighbor in _world.neighbors_even_q(cell):
					var neighbor_cat := CategoryMap.canonical(
						String(_world.get_cell_name(_world.LAYER_LIFE, neighbor))
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
					var bloom_fx: Array = bloom_fx_variant if bloom_fx_variant is Array else []
					if not bloom_fx.has(cell):
						bloom_fx.append(cell)
					fx["fx_nature"] = bloom_fx

	for y in range(height):
		for x in range(width):
			var cell := Vector2i(x, y)
			var pair := _cell_id_and_cat(cell)
			var id: String = pair[0]
			var cat: String = pair[1]
			if cat != CAT_EARTH:
				continue
			if skip_cells.has(cell):
				continue
			var r: Dictionary = _rules_for(id, cat)
			var per_turn: int = int(r.get("earth_per_turn", 1))
			if per_turn <= 0:
				continue
			var slows: Array = _canonicalize_array(r.get("slow_if_adjacent_any", []))
			var mult: int = int(r.get("slow_multiplier", 2))
			if mult <= 0:
				mult = 1
			var slowed := false
			for neighbor in _world.neighbors_even_q(cell):
				var neighbor_cat := CategoryMap.canonical(
					String(_world.get_cell_name(_world.LAYER_LIFE, neighbor))
				)
				if slows.has(neighbor_cat):
					slowed = true
					break
			var produce_now := true
			if slowed:
				produce_now = (_turn_counter % mult) == 0
			if produce_now:
				amounts["earth"] = clamp(
					int(amounts.get("earth", 0)) + per_turn, 0, int(capacity.get("earth", 0))
				)
				var earth_fx_variant: Variant = fx.get("fx_earth", [])
				var earth_fx: Array = earth_fx_variant if earth_fx_variant is Array else []
				if not earth_fx.has(cell):
					earth_fx.append(cell)
				fx["fx_earth"] = earth_fx

			var extra_every: int = int(r.get("earth_every_turns", 0))
			if extra_every < 0:
				extra_every = abs(extra_every)
			if extra_every > 0 and (_turn_counter % max(extra_every, 1)) == 0:
				var needs: Array = _canonicalize_array(r.get("requires_adjacent_any", []))
				if needs.is_empty():
					needs = [CAT_AGGRESSION, "root"]
				var ok := false
				for neighbor in _world.neighbors_even_q(cell):
					var neighbor_cat := CategoryMap.canonical(
						String(_world.get_cell_name(_world.LAYER_LIFE, neighbor))
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
					var vein_fx: Array = vein_fx_variant if vein_fx_variant is Array else []
					if not vein_fx.has(cell):
						vein_fx.append(cell)
					fx["fx_earth"] = vein_fx

	for y in range(height):
		for x in range(width):
			var cell := Vector2i(x, y)
			var pair := _cell_id_and_cat(cell)
			var id: String = pair[0]
			var cat: String = pair[1]
			if cat != CAT_WATER:
				continue
			if skip_cells.has(cell):
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
						var neighbor_cat := CategoryMap.canonical(
							String(_world.get_cell_name(_world.LAYER_LIFE, neighbor))
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
						var span_fx: Array = span_fx_variant if span_fx_variant is Array else []
						if not span_fx.has(cell):
							span_fx.append(cell)
						fx["fx_water"] = span_fx

        _apply_resource_multipliers(baseline)

	for y in range(height):
		for x in range(width):
			var cell := Vector2i(x, y)
			var pair := _cell_id_and_cat(cell)
			var id: String = pair[0]
			var cat: String = pair[1]
			if cat != CAT_MYSTIC:
				continue
			if skip_cells.has(cell):
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


func _produce_resources_v31_outputs_and_synergies(fx: Dictionary) -> Dictionary:
        var skip_cells: Dictionary = {}
        if _world == null:
                return skip_cells
        var width := int(_world.width)
        var height := int(_world.height)
        for y in range(height):
                for x in range(width):
                        var cell := Vector2i(x, y)
                        var pair := _cell_id_and_cat(cell)
                        var id: String = pair[0]
                        if id.is_empty():
                                continue
                        var tile_def := DataDB.get_tile_def(id)
                        if tile_def.is_empty():
                                continue
                        var outputs_variant: Variant = tile_def.get("outputs", {})
                        var outputs: Dictionary = outputs_variant if outputs_variant is Dictionary else {}
                        if not outputs.is_empty():
                                skip_cells[cell] = true
                                for res in outputs.keys():
                                        var amount: int = int(outputs[res])
                                        if amount == 0:
                                                continue
                                        _add_resource(res, amount, cell, fx)
                        var synergies_variant: Variant = tile_def.get("synergies", [])
                        var synergies: Array = []
                        if synergies_variant is Array:
                                synergies = synergies_variant
                        elif synergies_variant is PackedStringArray:
                                synergies = Array(synergies_variant)
                        if synergies.is_empty():
                                continue
                        for raw_entry in synergies:
                                if not (raw_entry is Dictionary):
                                        continue
                                var entry: Dictionary = raw_entry
                                var tag := String(entry.get("tag", "")).strip_edges()
                                if tag.is_empty():
                                        continue
                                var bonus_variant: Variant = entry.get("bonus", {})
                                if not (bonus_variant is Dictionary):
                                        continue
                                var bonus: Dictionary = bonus_variant
                                if bonus.is_empty():
                                        continue
                                var adjacent := bool(entry.get("adjacent", true))
                                var count := 0
                                if adjacent:
                                        count = _count_adjacent_with_tag(cell, tag)
                                else:
                                        count = 1
                                if count <= 0:
                                        continue
                                for res in bonus.keys():
                                        var bonus_value: int = int(bonus[res])
                                        if bonus_value == 0:
                                                continue
                                        _add_resource(res, bonus_value * count, cell, fx)
        return skip_cells


func _snapshot_resource_amounts(keys: Array[String]) -> Dictionary:
        var snapshot: Dictionary = {}
        for key in keys:
                var resource := String(key)
                if resource.is_empty():
                        continue
                snapshot[resource] = int(amounts.get(resource, 0))
        return snapshot


func _apply_resource_multipliers(baseline: Dictionary) -> void:
        for key in baseline.keys():
                var resource := String(key)
                if resource.is_empty():
                        continue
                var starting_amount: int = int(baseline.get(resource, 0))
                var current_amount: int = int(amounts.get(resource, 0))
                var produced: int = current_amount - starting_amount
                if produced <= 0:
                        continue
                var multiplier: float = float(_bonus_mults.get(resource, 1.0))
                if multiplier <= 1.0:
                        continue
                var scaled_gain := ceili(float(produced) * multiplier)
                if scaled_gain <= produced:
                        continue
                var desired_amount := starting_amount + scaled_gain
                if resource != "life":
                        var cap_value: int = int(capacity.get(resource, 0))
                        desired_amount = clamp(desired_amount, 0, cap_value)
                else:
                        desired_amount = max(desired_amount, 0)
                amounts[resource] = desired_amount


func _count_adjacent_with_tag(cell: Vector2i, tag: String) -> int:
	if _world == null:
		return 0
	var normalized_tag := String(tag).strip_edges()
	if normalized_tag.is_empty():
		return 0
	var lower_tag := normalized_tag.to_lower()
	var canonical_tag := CategoryMap.canonical(normalized_tag)
	var count := 0
	for neighbor in _world.neighbors_even_q(cell):
		var neighbor_id := ""
		var neighbor_tags: Array = []
                if _world.has_method("get_cell_meta"):
                        var tags_variant: Variant = _world.get_cell_meta(
                                _world.LAYER_LIFE, neighbor, "tags"
                        )
                        if tags_variant is PackedStringArray:
                                neighbor_tags = Array(tags_variant)
                        elif tags_variant is Array:
                                neighbor_tags = tags_variant
                        var id_variant: Variant = _world.get_cell_meta(
                                _world.LAYER_LIFE, neighbor, "id"
                        )
                        if typeof(id_variant) == TYPE_STRING:
                                neighbor_id = String(id_variant)
		if neighbor_id.is_empty() and _world.has_method("get_cell_tile_id"):
			neighbor_id = String(_world.get_cell_tile_id(_world.LAYER_LIFE, neighbor))
		if neighbor_tags.is_empty() and not neighbor_id.is_empty():
			neighbor_tags = DataDB.get_tags_for_id(neighbor_id)
		var matched := false
		for neighbor_tag in neighbor_tags:
			var tag_str := String(neighbor_tag)
			if tag_str.is_empty():
				continue
			if tag_str == normalized_tag or tag_str.to_lower() == lower_tag:
				matched = true
				break
		if not matched:
			var neighbor_cat := ""
                        if _world.has_method("get_cell_meta"):
                                var meta_cat: Variant = _world.get_cell_meta(
                                        _world.LAYER_LIFE, neighbor, "category"
                                )
                                if typeof(meta_cat) == TYPE_STRING:
                                        neighbor_cat = String(meta_cat)
			if neighbor_cat.is_empty() and not neighbor_id.is_empty():
				neighbor_cat = String(DataDB.get_category_for_id(neighbor_id))
			var canonical_neighbor := CategoryMap.canonical(neighbor_cat)
			if not canonical_tag.is_empty() and canonical_neighbor == canonical_tag:
				matched = true
			elif neighbor_cat.to_lower() == lower_tag:
				matched = true
		if matched:
			count += 1
	return count


func _add_resource(kind: String, amount: int, cell: Vector2i, fx: Dictionary) -> void:
	if amount == 0:
		return
	if kind == "soul_seed":
		if amount != 0:
			add_soul_seed(amount)
			_mark_fx_cell(fx, kind, cell)
		return
	if not amounts.has(kind):
		amounts[kind] = 0
	if not capacity.has(kind):
		capacity[kind] = 0
	var current := int(amounts.get(kind, 0))
	var next_value := current + amount
	if kind != "life":
		var cap_value := int(capacity.get(kind, 0))
		next_value = clamp(next_value, 0, cap_value)
	else:
		next_value = max(next_value, 0)
	var actual_gain := next_value - current
	amounts[kind] = next_value
	if actual_gain == 0:
		return
	_mark_fx_cell(fx, kind, cell)


func _mark_fx_cell(fx: Dictionary, resource: String, cell: Vector2i) -> void:
	var fx_key := _fx_key_for_resource(resource)
	if fx_key.is_empty():
		return
	var fx_variant: Variant = fx.get(fx_key, [])
	var fx_array: Array = fx_variant if fx_variant is Array else []
	if not fx_array.has(cell):
		fx_array.append(cell)
	fx[fx_key] = fx_array


func _fx_key_for_resource(resource: String) -> String:
	if FX_KEY_BY_RESOURCE.has(resource):
		return String(FX_KEY_BY_RESOURCE[resource])
	return ""


func _canonicalize_array(values: Variant) -> Array:
	var result: Array = []
	var source := values
	if source is PackedStringArray:
		source = Array(source)
	if source is Array:
		for entry in source:
			var canonical_value := CategoryMap.canonical(String(entry))
			if canonical_value.is_empty():
				continue
			if not result.has(canonical_value):
				result.append(canonical_value)
	elif typeof(source) == TYPE_STRING:
		var single := CategoryMap.canonical(String(source))
		if not single.is_empty():
			result.append(single)
	return result


func _canonicalize_dict_keys(dict_variant: Variant) -> Dictionary:
	if not (dict_variant is Dictionary):
		return {}
	var original: Dictionary = dict_variant
	var result: Dictionary = {}
	for key in original.keys():
		var canonical_key := CategoryMap.canonical(String(key))
		if canonical_key.is_empty():
			continue
		result[canonical_key] = original[key]
	return result
