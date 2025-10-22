extends Node

signal tile_choice_ready(choices: Array)
signal special_to_place_now(tile_id: String)
signal totem_tier_changed(new_tier: int)

var _world: Node = null
var _totems: Array = []
var _packs: Array = []
var _totem_id := "totem.heartwood"
var _tier: int = 1

var _packs_by_id: Dictionary = {}
var _choice_def: Array = []
var _interval: int = 3
var _special_forced_place: bool = true
var _last_picks: Array = []
var _turn_source: Node = null
var _last_choice_turn: int = 0


func _ready() -> void:
	_totems = DataLite.load_json_array("res://data/totems.json")
	_packs = DataLite.load_json_array("res://data/packs.json")
	_packs_by_id.clear()
	for pack_variant in _packs:
		if not (pack_variant is Dictionary):
			continue
		var pack: Dictionary = pack_variant
		var pack_id := String(pack.get("id", ""))
		if pack_id.is_empty():
			continue
		_packs_by_id[pack_id] = pack
	_load_totem(_totem_id)
	_tier = clamp(_tier, 1, _get_max_tier())
	emit_signal("totem_tier_changed", _tier)
	_turn_source = _locate_turn_source()
	if _turn_source != null and _turn_source.has_signal("phase_started"):
		if not _turn_source.is_connected("phase_started", Callable(self, "_on_phase_started")):
			_turn_source.connect("phase_started", Callable(self, "_on_phase_started"))


func bind_world(world: Node) -> void:
	_world = world


func _locate_turn_source() -> Node:
	var turn_node: Node = get_node_or_null("/root/TurnEngine")
	if turn_node == null:
		turn_node = get_node_or_null("/root/Game")
	return turn_node


func _load_totem(id: String) -> void:
	var totem_def := _get_totem_def(id)
	var gen_variant: Variant = totem_def.get("tile_gen", {})
	var gen: Dictionary = gen_variant if gen_variant is Dictionary else {}
	_interval = int(gen.get("interval_turns", 3))
	var choices_variant: Variant = gen.get("choices", [])
	_choice_def = choices_variant if choices_variant is Array else []
	_special_forced_place = bool(gen.get("special_forced_place", true))


func set_totem(id: String, tier: int = 1) -> void:
	_totem_id = id
	_load_totem(id)
	var max_tier := _get_max_tier()
	_tier = clamp(tier, 1, max_tier)
	emit_signal("totem_tier_changed", _tier)


func get_tier() -> int:
	return _tier


func get_interval() -> int:
	return _interval


func get_next_choice_turn() -> int:
	var interval := _interval
	if interval <= 0:
		return -1
	var current_turn := _get_turn_count()
	if current_turn <= 0:
		current_turn = max(_last_choice_turn, interval)
	else:
		current_turn = max(current_turn, _last_choice_turn)
	var mod := current_turn % interval
	if mod == 0:
		return current_turn + interval
	return current_turn + (interval - mod)


func _on_phase_started(phase_name: String) -> void:
	if phase_name != "tile_gen":
		return
	if _interval <= 0:
		return
	if not _last_picks.is_empty():
		return
	var turn := _get_turn_count()
	if turn <= 0:
		return
	if turn % _interval != 0:
		return
	_roll_and_emit_choices(turn)


func _roll_and_emit_choices(turn: int) -> void:
	var bag: Array[String] = []
	for choice_variant in _choice_def:
		if not (choice_variant is Dictionary):
			continue
		var choice: Dictionary = choice_variant
		var pack_id := String(choice.get("pack_id", ""))
		if pack_id.is_empty():
			continue
		var weight: int = max(0, int(choice.get("weight", 1)))
		var min_tier := int(choice.get("min_tier", 1))
		if _tier < min_tier:
			continue
		for _i in range(weight):
			bag.append(pack_id)
	if bag.is_empty():
		return
	bag.shuffle()
	var seen: Dictionary = {}
	_last_picks.clear()
	for pack_id in bag:
		if _last_picks.size() >= 3:
			break
		if seen.has(pack_id):
			continue
		var pack_variant: Variant = _packs_by_id.get(pack_id, null)
		if not (pack_variant is Dictionary):
			continue
		var pack: Dictionary = (pack_variant as Dictionary).duplicate(true)
		if not pack.has("id"):
			pack["id"] = pack_id
		_last_picks.append(pack)
		seen[pack_id] = true
	if _last_picks.is_empty():
		return
	_last_choice_turn = turn
	emit_signal("tile_choice_ready", _last_picks)


func choose_index(i: int) -> void:
	if i < 0 or i >= _last_picks.size():
		return
	var choice_variant: Variant = _last_picks[i]
	if not (choice_variant is Dictionary):
		return
	var pack: Dictionary = choice_variant
	_last_picks.clear()
	emit_signal("tile_choice_ready", [])
	_inject_pack(pack)


func skip() -> void:
	if _last_picks.is_empty():
		return
	_last_picks.clear()
	emit_signal("tile_choice_ready", [])


func _inject_pack(pack: Dictionary) -> void:
	var tiles_variant: Variant = pack.get("tiles", [])
	var specials_variant: Variant = pack.get("special", [])
	var tiles: Array = tiles_variant if tiles_variant is Array else []
	var specials: Array = specials_variant if specials_variant is Array else []
	if not tiles.is_empty():
		for tile_variant in tiles:
			DeckManager.deck.append(String(tile_variant))
		DeckManager.shuffle()
	_update_world_hud()
	if _special_forced_place and not specials.is_empty():
		for special_variant in specials:
			emit_signal("special_to_place_now", String(special_variant))


func _update_world_hud() -> void:
	if _world == null:
		return
	if _world.has_method("update_hud"):
		_world.call("update_hud", DeckManager.peek_name(), DeckManager.remaining())


func can_evolve() -> bool:
	return _tier < _get_max_tier()


func next_evolve_cost() -> int:
	if not can_evolve():
		return -1
	var evolution_variant: Variant = _get_totem_def(_totem_id).get("evolution", {})
	var evo_dict: Dictionary = evolution_variant if evolution_variant is Dictionary else {}
	var costs_variant: Variant = evo_dict.get("life_essence_costs", [])
	var costs: Array = costs_variant if costs_variant is Array else []
	var next_tier := _tier + 1
	var index: int = clamp(next_tier - 1, 0, max(costs.size() - 1, 0))
	if costs.is_empty():
		return -1
	return int(costs[index])


func can_afford_next_evolve() -> bool:
	var cost := next_evolve_cost()
	if cost <= 0:
		return can_evolve()
	var resource_manager := _get_resource_manager()
	if resource_manager == null:
		return false
	if not resource_manager.has_method("get_amount"):
		return false
	return int(resource_manager.call("get_amount", "life")) >= cost


func evolve() -> bool:
	if not can_evolve():
		return false
	var cost := next_evolve_cost()
	if cost > 0:
		var resource_manager := _get_resource_manager()
		if resource_manager == null or not resource_manager.has_method("spend"):
			return false
		if not bool(resource_manager.call("spend", "life", cost)):
			return false
	_tier += 1
	_tier = min(_tier, _get_max_tier())
	emit_signal("totem_tier_changed", _tier)
	return true


func _get_totem_def(id: String) -> Dictionary:
	for entry_variant in _totems:
		if not (entry_variant is Dictionary):
			continue
		var entry: Dictionary = entry_variant
		if String(entry.get("id", "")) == id:
			return entry
	return {}


func _get_max_tier() -> int:
	var evolution_variant: Variant = _get_totem_def(_totem_id).get("evolution", {})
	var evo_dict: Dictionary = evolution_variant if evolution_variant is Dictionary else {}
	return int(evo_dict.get("tier_max", 5))


func _get_turn_count() -> int:
	if _turn_source == null:
		_turn_source = _locate_turn_source()
	var turn_node := _turn_source
	var value: Variant = null
	if turn_node != null:
		value = turn_node.get("turn_count")
	if typeof(value) == TYPE_INT:
		return int(value)
	if typeof(value) == TYPE_FLOAT:
		return int(value)
	if _world != null and _world.has_method("get"):
		var world_turn: Variant = _world.get("turn")
		if typeof(world_turn) == TYPE_INT:
			return int(world_turn)
		if typeof(world_turn) == TYPE_FLOAT:
			return int(world_turn)
	return 0


func _get_resource_manager() -> Node:
	return get_node_or_null("/root/ResourceManager")
