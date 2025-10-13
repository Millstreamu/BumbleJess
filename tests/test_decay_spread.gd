extends RefCounted

const Board := preload("res://src/systems/Board.gd")
const Config := preload("res://src/data/Config.gd")
const Decay := preload("res://src/systems/Decay.gd")
const RunState := preload("res://src/core/RunState.gd")

func _setup_environment() -> Dictionary:
	Config.load_all()
	var totem_cfg_variant: Variant = Config.decay().get("totems", {})
	var backup := {}
	if typeof(totem_cfg_variant) == TYPE_DICTIONARY:
		backup = (totem_cfg_variant as Dictionary).duplicate(true)
	RunState.connected_set = {}
	RunState.decay_totems = []
	RunState.decay_tiles = {}
	RunState.decay_adjacent_age = {}
	RunState.overgrowth = {}
	return backup

func _restore_config(backup: Dictionary) -> void:
	var totem_cfg_variant: Variant = Config.decay().get("totems", {})
	if typeof(totem_cfg_variant) != TYPE_DICTIONARY:
		return
	var totem_cfg: Dictionary = totem_cfg_variant
	for key in backup.keys():
		totem_cfg[key] = backup[key]
	for key in totem_cfg.keys():
		if not backup.has(key):
			totem_cfg.erase(key)

func _sorted_decay_positions() -> Array:
	var result: Array = []
	for key in RunState.decay_tiles.keys():
		result.append(Board.unkey(key))
	result.sort_custom(func(a, b):
		if a.x == b.x:
			return a.y < b.y
		return a.x < b.x)
	return result

func test_decay_spread_respects_timer_and_cap() -> bool:
	var backup := _setup_environment()
	var totem_cfg_variant: Variant = Config.decay().get("totems", {})
	if typeof(totem_cfg_variant) != TYPE_DICTIONARY:
		_restore_config(backup)
		return false
	var totem_cfg: Dictionary = totem_cfg_variant
	totem_cfg["spread_every_turns"] = 2
	totem_cfg["attacks_per_turn"] = 1
	totem_cfg["count"] = 2
	var board := Board.new()
	board.add_tile(Vector2i.ZERO, "Grove", "grove_base")
	RunState.connected_set[Board.key(Vector2i.ZERO)] = true
	RunState.decay_totems = [
		{"ax": Vector2i(2, -1), "timer": 1},
		{"ax": Vector2i(-2, 1), "timer": 1},
	]
	RunState.decay_tiles = {}
	RunState.decay_adjacent_age = {}
	RunState.overgrowth = {}
	Decay.do_spread(board)
	var first_tiles := RunState.decay_tiles.size()
	var timer_a_turn1 := int(RunState.decay_totems[0]["timer"])
	var timer_b_turn1 := int(RunState.decay_totems[1]["timer"])
	Decay.do_spread(board)
	var second_tiles := RunState.decay_tiles.size()
	var timer_a_turn2 := int(RunState.decay_totems[0]["timer"])
	var timer_b_turn2 := int(RunState.decay_totems[1]["timer"])
	Decay.do_spread(board)
	var third_tiles := RunState.decay_tiles.size()
	var timer_a_turn3 := int(RunState.decay_totems[0]["timer"])
	var timer_b_turn3 := int(RunState.decay_totems[1]["timer"])
	var decay_positions := _sorted_decay_positions()
	var ok := true
	ok = ok and first_tiles == 1
	ok = ok and second_tiles == 1
	ok = ok and third_tiles == 2
	ok = ok and timer_a_turn1 == 2 and timer_b_turn1 == 2
	ok = ok and timer_a_turn2 == 1 and timer_b_turn2 == 1
	ok = ok and timer_a_turn3 == 2 and timer_b_turn3 == 2
		ok = ok and decay_positions.has(Vector2i(1, -1))
		ok = ok and decay_positions.has(Vector2i(1, 0))
	_restore_config(backup)
	RunState.decay_totems = []
	RunState.decay_tiles = {}
	RunState.decay_adjacent_age = {}
	return ok
