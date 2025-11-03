## Evaluates JSON-driven tile effects for all placements and turn phases.
extends Node

var _tile_manager: TileManager = null
var _effect_state: Dictionary = {}
var _pending_events: Array[String] = []
var _processing: bool = false
var _aura_cache: Dictionary = {}

func _ready() -> void:
	_tile_manager = _locate_tile_manager()
	if _tile_manager != null:
		if not _tile_manager.is_connected("tile_removed", Callable(self, "_on_tile_removed")):
			_tile_manager.connect("tile_removed", Callable(self, "_on_tile_removed"))
		if not _tile_manager.is_connected("tile_transformed", Callable(self, "_on_tile_transformed")):
			_tile_manager.connect("tile_transformed", Callable(self, "_on_tile_transformed"))

func reset_state() -> void:
	_effect_state.clear()
	_pending_events.clear()
	_processing = false
	_aura_cache.clear()

func apply_when(when: String) -> void:
	if when.is_empty():
		return
	_pending_events.append(when)
	if _processing:
		return
	_processing = true
	while not _pending_events.is_empty():
		var current: String = _pending_events[0]
		_pending_events.remove_at(0)
		_process_event(current)
	_processing = false

func get_aura_cache() -> Dictionary:
	var copy: Dictionary = {}
	for key in _aura_cache.keys():
		var entry_variant: Variant = _aura_cache[key]
		if entry_variant is Dictionary:
			copy[key] = (entry_variant as Dictionary).duplicate(true)
	return copy

func _process_event(when: String) -> void:
	if _tile_manager == null:
		_tile_manager = _locate_tile_manager()
	if _tile_manager == null:
		return
	if when == "start_of_turn":
		_aura_cache.clear()
	var tiles: Array = _tile_manager.get_all_tiles()
	if tiles.is_empty():
		return
	var turn_idx: int = _get_turn_index()
	for tile_variant in tiles:
		if not (tile_variant is TileManager.TileRef):
			continue
		var tile: TileManager.TileRef = tile_variant
		var definition: Dictionary = tile.definition
		var effects_variant: Variant = definition.get("effects", [])
		if not (effects_variant is Array):
			continue
		var effects: Array = effects_variant
		for effect_index in range(effects.size()):
			var effect_variant: Variant = effects[effect_index]
			if not (effect_variant is Dictionary):
				continue
			var effect: Dictionary = effect_variant
			if String(effect.get("when", "")) != when:
				continue
			var state: Dictionary = _prepare_state(tile, effect_index, effect, turn_idx)
			if state.is_empty():
				continue
			if not _conditions_met(tile, effect, turn_idx):
				continue
			_mark_triggered(tile.uid, effect_index, effect, state, turn_idx)
			var targets: Dictionary = _resolve_targets(tile, effect)
			_apply_effect(tile, effect, targets, state)

func _prepare_state(tile: TileManager.TileRef, effect_index: int, effect: Dictionary, turn_idx: int) -> Dictionary:
	var tile_states: Dictionary = _effect_state.get(tile.uid, {})
	if not (tile_states is Dictionary):
		tile_states = {}
	_effect_state[tile.uid] = tile_states
	var state_variant: Variant = tile_states.get(effect_index, null)
	var state: Dictionary = state_variant if state_variant is Dictionary else {}
	if state.is_empty():
		var interval: int = max(1, int(effect.get("interval_turns", 1)))
		state = {
			"next_due": turn_idx + interval - 1,
			"started_turn": turn_idx,
			"trigger_count": 0,
		}
		tile_states[effect_index] = state
	var duration_variant: Variant = effect.get("duration_turns", null)
	if duration_variant is int or duration_variant is float:
		var duration: int = int(duration_variant)
		if duration > 0:
			var expires: int = int(state.get("started_turn", turn_idx)) + duration
			if turn_idx >= expires:
				return {}
	var next_due: int = int(state.get("next_due", turn_idx))
	if turn_idx < next_due:
		return {}
	return state

func _mark_triggered(tile_uid: int, effect_index: int, effect: Dictionary, state: Dictionary, turn_idx: int) -> void:
	var interval: int = max(1, int(effect.get("interval_turns", 1)))
	state["next_due"] = turn_idx + interval
	state["trigger_count"] = int(state.get("trigger_count", 0)) + 1
	state["last_turn"] = turn_idx

func _conditions_met(tile: TileManager.TileRef, effect: Dictionary, turn_idx: int) -> bool:
	var cond_variant: Variant = effect.get("condition", {})
	if cond_variant is Dictionary:
		var cond: Dictionary = cond_variant
		if cond.has("adjacent_count"):
			var adj_variant: Variant = cond.get("adjacent_count")
			if adj_variant is Dictionary:
				var tag := String(adj_variant.get("tag", ""))
				var op := String(adj_variant.get("op", ">="))
				var value := int(adj_variant.get("value", 0))
				var count := _tile_manager.count_adjacent_with_tag(tile.position, tag)
				if not _compare_numbers(count, value, op):
					return false
		if cond.has("touching_decay"):
			var expect: bool = bool(cond.get("touching_decay", false))
			var touching: bool = _tile_manager.is_touching_decay(tile.position)
			if touching != expect:
				return false
		if cond.has("turn_mod"):
			var tm_variant: Variant = cond.get("turn_mod")
			if tm_variant is Dictionary:
				var mod_value: int = max(1, int(tm_variant.get("mod", 1)))
				var eq_value: int = int(tm_variant.get("eq", 0))
				if turn_idx % mod_value != eq_value:
					return false
	return true

func _resolve_targets(source_tile: TileManager.TileRef, effect: Dictionary) -> Dictionary:
	var target_variant: Variant = effect.get("target", {})
	var target: Dictionary = target_variant if target_variant is Dictionary else {}
	var scope := String(target.get("scope", "self"))
	var positions: Array = []
	var tiles: Array = []
	match scope:
		"self":
			positions.append(source_tile.position)
			tiles.append(source_tile)
		"adjacent":
			positions = _tile_manager.get_adjacent_positions(source_tile.position)
			for pos in positions:
				var neighbor_tile := _tile_manager.get_tile(pos)
				if neighbor_tile != null:
					tiles.append(neighbor_tile)
		"radius":
			var radius: int = max(0, int(target.get("radius", 1)))
			positions = _positions_in_radius(source_tile.position, radius)
			var radius_tiles: Array = _tile_manager.get_tiles_in_radius(source_tile.position, radius)
			for radius_tile in radius_tiles:
				tiles.append(radius_tile)
		"global":
			positions = _tile_manager.get_all_positions()
			tiles = _tile_manager.get_all_tiles()
		_:
			positions.append(source_tile.position)
			tiles.append(source_tile)
	var include_overgrowth: bool = bool(target.get("include_overgrowth", false))
	var include_grove: bool = bool(target.get("include_grove", false))
	var filtered_tiles: Array = []
	for tile_variant in tiles:
		if not (tile_variant is TileManager.TileRef):
			continue
		var tile: TileManager.TileRef = tile_variant
		if tile.category == TileManager.CATEGORY_OVERGROWTH and not include_overgrowth:
			continue
		if tile.category == TileManager.CATEGORY_GROVE and not include_grove:
			continue
		filtered_tiles.append(tile)
	filtered_tiles = _tile_manager.filter_by_tags(filtered_tiles, target.get("has_tags_any", []), target.get("has_tags_all", []), target.get("category_any", []))
	return {
		"tiles": filtered_tiles,
		"positions": positions,
	}

func _apply_effect(source_tile: TileManager.TileRef, effect: Dictionary, targets: Dictionary, state: Dictionary) -> void:
	var op := String(effect.get("op", ""))
	match op:
		"add", "mul", "set":
			_apply_stat_effect(op, effect, targets)
		"convert":
			_apply_convert_effect(effect, targets, state)
		"spawn":
			_apply_spawn_effect(effect, targets)
		"transform":
			_apply_transform_effect(effect, targets)
		"cleanse_decay":
			_apply_cleanse_decay(effect, targets)
		"damage_decay":
			_apply_damage_decay(effect, targets)
		"aura_sprout":
			_apply_aura_effect(source_tile, effect, targets)
		_:
			pass

func _apply_stat_effect(op: String, effect: Dictionary, targets: Dictionary) -> void:
	var stat_path := String(effect.get("stat", ""))
	if stat_path.is_empty():
		return
	var amount := float(effect.get("amount", 0.0))
	var stacking := String(effect.get("stacking", "sum"))
	var tiles: Array = targets.get("tiles", [])
	if tiles.is_empty():
		return
	var map: Dictionary = {}
	var lookup: Dictionary = {}
	for tile_variant in tiles:
		if not (tile_variant is TileManager.TileRef):
			continue
		var tile: TileManager.TileRef = tile_variant
		var values: Array = map.get(tile.uid, [])
		values.append(amount)
		map[tile.uid] = values
		lookup[tile.uid] = tile
	for uid in map.keys():
		var tile: TileManager.TileRef = lookup.get(uid, null)
		if tile == null:
			continue
		var values: Array = map[uid]
		var combined: float = _combine_values(values, stacking)
		_apply_stat_to_tile(tile, op, stat_path, combined)

func _apply_convert_effect(effect: Dictionary, targets: Dictionary, state: Dictionary) -> void:
	var amount_variant: Variant = effect.get("amount", {})
	if not (amount_variant is Dictionary):
		return
	var amount: Dictionary = amount_variant
	var period: int = max(1, int(amount.get("period", 1)))
	var counter: int = int(state.get("convert_counter", 0)) + 1
	if counter < period:
		state["convert_counter"] = counter
		return
	state["convert_counter"] = 0
	var tiles: Array = targets.get("tiles", [])
	if tiles.is_empty():
		return
	var from_dict: Dictionary = amount.get("from", {})
	var to_dict: Dictionary = amount.get("to", {})
	for tile_variant in tiles:
		if not (tile_variant is TileManager.TileRef):
			continue
		var tile: TileManager.TileRef = tile_variant
		for resource in from_dict.keys():
			var value := float(from_dict[resource])
			_apply_stat_to_tile(tile, "add", "output." + String(resource), -value)
		for resource in to_dict.keys():
			var value := float(to_dict[resource])
			_apply_stat_to_tile(tile, "add", "output." + String(resource), value)

func _apply_spawn_effect(effect: Dictionary, targets: Dictionary) -> void:
	var amount_variant: Variant = effect.get("amount", {})
	if not (amount_variant is Dictionary):
		return
	var amount: Dictionary = amount_variant
	var tile_id := String(amount.get("tile_id", ""))
	if tile_id.is_empty():
		return
	var count: int = max(1, int(amount.get("count", 1)))
	var empty_only: bool = bool(amount.get("empty_only", false))
	var positions: Array = targets.get("positions", [])
	for pos_variant in positions:
		if count <= 0:
			break
		if not (pos_variant is Vector2i):
			continue
		var position: Vector2i = pos_variant
		if _tile_manager.has_tile(position):
			if empty_only:
				continue
			else:
				continue
		var placed := _tile_manager.place_tile(tile_id, position)
		if placed != null:
			count -= 1

func _apply_transform_effect(effect: Dictionary, targets: Dictionary) -> void:
	var amount_variant: Variant = effect.get("amount", {})
	if not (amount_variant is Dictionary):
		return
	var amount: Dictionary = amount_variant
	var to_id := String(amount.get("to", ""))
	if to_id.is_empty():
		return
	for tile_variant in targets.get("tiles", []):
		if tile_variant is TileManager.TileRef:
			var tile: TileManager.TileRef = tile_variant
			_tile_manager.transform_tile(tile.position, to_id)

func _apply_cleanse_decay(effect: Dictionary, targets: Dictionary) -> void:
	var amount_variant: Variant = effect.get("amount", {})
	if not (amount_variant is Dictionary):
		return
	var amount: Dictionary = amount_variant
	var radius: int = max(0, int(amount.get("radius", 0)))
	var max_tiles: int = max(0, int(amount.get("max_tiles", 0)))
	var remaining: int = max_tiles
	var visited: Dictionary = {}
	var centers: Array = targets.get("positions", [])
	if centers.is_empty():
		for tile_variant in targets.get("tiles", []):
			if tile_variant is TileManager.TileRef:
				centers.append((tile_variant as TileManager.TileRef).position)
	for center_variant in centers:
		if not (center_variant is Vector2i):
			continue
		var center: Vector2i = center_variant
		var decay_cells := _tile_manager.get_decay_cells_in_radius(center, radius)
		for cell in decay_cells:
			if visited.has(cell):
				continue
			visited[cell] = true
			_tile_manager.remove_decay_cell(cell)
			if max_tiles > 0:
				remaining -= 1
				if remaining <= 0:
					return

func _apply_damage_decay(effect: Dictionary, targets: Dictionary) -> void:
	var amount_variant: Variant = effect.get("amount", {})
	if not (amount_variant is Dictionary):
		return
	var amount: Dictionary = amount_variant
	var radius: int = max(0, int(amount.get("radius", 0)))
	var damage: float = float(amount.get("amount", 0.0))
	if damage <= 0.0:
		return
	var centers: Array = targets.get("positions", [])
	if centers.is_empty():
		for tile_variant in targets.get("tiles", []):
			if tile_variant is TileManager.TileRef:
				centers.append((tile_variant as TileManager.TileRef).position)
	var seen: Dictionary = {}
	for center_variant in centers:
		if not (center_variant is Vector2i):
			continue
		var center: Vector2i = center_variant
		for cell in _tile_manager.get_decay_cells_in_radius(center, radius):
			if seen.has(cell):
				continue
			seen[cell] = true
			_tile_manager.damage_decay_cell(cell, damage)

func _apply_aura_effect(source_tile: TileManager.TileRef, effect: Dictionary, targets: Dictionary) -> void:
	var amount_variant: Variant = effect.get("amount", {})
	if not (amount_variant is Dictionary):
		return
	var amount: Dictionary = amount_variant
	var stat := String(amount.get("stat", ""))
	if stat.is_empty():
		return
	var op_kind := String(amount.get("op", "add"))
	var value := float(amount.get("amount", 0.0))
	var stacking := String(effect.get("stacking", "sum"))
	var target_tiles: Array = targets.get("tiles", [])
	if target_tiles.is_empty():
		return
	var key_suffix := "|" + op_kind + "|" + stat
	var target_cfg: Dictionary = effect.get("target", {}) if effect.get("target", {}) is Dictionary else {}
	var radius: int = int(target_cfg.get("radius", 0))
	for tile_variant in target_tiles:
		if not (tile_variant is TileManager.TileRef):
			continue
		var tile: TileManager.TileRef = tile_variant
		var tile_key := str(tile.uid)
		var aura_entry_variant: Variant = _aura_cache.get(tile_key, {})
		var aura_entry: Dictionary = aura_entry_variant if aura_entry_variant is Dictionary else {}
		var aura_key := key_suffix
		var current_variant: Variant = aura_entry.get(aura_key, {})
		var current: Dictionary = current_variant if current_variant is Dictionary else {
			"stat": stat,
			"op": op_kind,
			"radius": radius,
			"amount": 0.0,
			"sources": [],
		}
		var combined: float = value
		if current.has("amount"):
			combined = _combine_values([float(current.get("amount", 0.0)), value], stacking)
		if stacking == "sum":
			combined = float(current.get("amount", 0.0)) + value
		elif stacking == "max":
			combined = max(float(current.get("amount", value)), value)
		elif stacking == "min":
			if current.has("amount"):
				combined = min(float(current.get("amount", value)), value)
			else:
				combined = value
		current["radius"] = radius
		current["amount"] = combined
		var sources: Array = current.get("sources", [])
		if not sources.has(source_tile.uid):
			sources.append(source_tile.uid)
		current["sources"] = sources
		aura_entry[aura_key] = current
		_aura_cache[tile_key] = aura_entry

func _combine_values(values: Array, stacking: String) -> float:
	if values.is_empty():
		return 0.0
	var numbers: Array = []
	for value in values:
		numbers.append(float(value))
	match stacking:
		"sum":
			var total := 0.0
			for num in numbers:
				total += num
			return total
		"max":
			var max_val: float = numbers[0]
			for num in numbers:
				if num > max_val:
					max_val = num
			return max_val
		"min":
			var min_val: float = numbers[0]
			for num in numbers:
				if num < min_val:
					min_val = num
			return min_val
		_:
			return numbers[0]

func _apply_stat_to_tile(tile: TileManager.TileRef, op: String, stat_path: String, amount: float) -> void:
	var parts := stat_path.split(".")
	if parts.is_empty():
		return
	if parts.size() == 1:
		var key := parts[0]
		if not tile.stats.has(key):
			push_warning("Unknown stat '%s'" % key)
			return
		var current := float(tile.stats.get(key, 0.0))
		var updated := _compute_stat_value(current, amount, op)
		tile.stats[key] = updated
		return
	var base := parts[0]
	var sub_key := parts[1]
	var container_variant: Variant = tile.stats.get(base, {})
	if not (container_variant is Dictionary):
		push_warning("Unknown stat container '%s'" % base)
		return
	var container: Dictionary = container_variant
	var current_value := float(container.get(sub_key, 0.0))
	container[sub_key] = _compute_stat_value(current_value, amount, op)
	tile.stats[base] = container

func _compute_stat_value(current: float, amount: float, op: String) -> float:
	match op:
		"add":
			return current + amount
		"mul":
			return current * amount
		"set":
			return amount
		_:
			return current


func _compare_numbers(lhs: int, rhs: int, op: String) -> bool:
	match op:
		">=":
			return lhs >= rhs
		"<=":
			return lhs <= rhs
		"==":
			return lhs == rhs
		"!=":
			return lhs != rhs
		">":
			return lhs > rhs
		"<":
			return lhs < rhs
		_:
			return false

func _positions_in_radius(center: Vector2i, radius: int) -> Array:
	var positions: Array = []
	if radius < 0:
		return positions
	positions.append(center)
	if radius == 0:
		return positions
	var visited := {center: true}
	var frontier: Array = [center]
	for _step in range(radius):
		var next_frontier: Array = []
		for pos in frontier:
			for neighbor in _tile_manager.get_adjacent_positions(pos):
				if visited.has(neighbor):
					continue
				visited[neighbor] = true
				next_frontier.append(neighbor)
				positions.append(neighbor)
		frontier = next_frontier
	return positions

func _get_turn_index() -> int:
	if typeof(Game) != TYPE_NIL and Game.has_method("get_turn_index"):
		return Game.get_turn_index()
	var turn_node := get_tree().root.get_node_or_null("TurnEngine")
	if turn_node != null and turn_node.has_variable("turn_index"):
		return int(turn_node.get("turn_index"))
	return 1

func _locate_tile_manager() -> TileManager:
	if typeof(TileManager) != TYPE_NIL and TileManager is TileManager:
		return TileManager
	var node := get_tree().root.get_node_or_null("TileManager")
	if node is TileManager:
		return node
	return null

func _on_tile_removed(tile: TileManager.TileRef) -> void:
	if tile == null:
		return
	_effect_state.erase(tile.uid)
	_aura_cache.erase(str(tile.uid))

func _on_tile_transformed(tile: TileManager.TileRef, _previous_id: String) -> void:
	if tile == null:
		return
	_effect_state.erase(tile.uid)
	_aura_cache.erase(str(tile.uid))
