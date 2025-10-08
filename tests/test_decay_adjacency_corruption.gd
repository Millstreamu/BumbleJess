extends RefCounted

const Board := preload("res://src/systems/Board.gd")
const Decay := preload("res://src/systems/Decay.gd")
const RunState := preload("res://src/core/RunState.gd")

func _reset_state() -> void:
	RunState.decay_tiles = {}
	RunState.decay_totems = []
	RunState.decay_adjacent_age = {}
	RunState.connected_set = {}
	RunState.overgrowth = {}

func test_life_tile_corrupts_after_three_phases() -> bool:
	_reset_state()
	var board := Board.new()
	board.add_tile(Vector2i.ZERO, "Grove", "grove_base")
	RunState.connected_set[Board.key(Vector2i.ZERO)] = true
	board.add_decay(Vector2i(1, 0))
	RunState.decay_tiles[Board.key(Vector2i(1, 0))] = {"age_adj_life": 0}
	for i in range(2):
		Decay.apply_adjacency_corruption(board)
		var tile := board.get_tile(Vector2i.ZERO)
		if tile.get("category", "") != "Grove":
			return false
	Decay.apply_adjacency_corruption(board)
	var corrupted := board.get_tile(Vector2i.ZERO)
	if corrupted.get("category", "") != "Decay":
		return false
	if corrupted.get("variant_id", "") != "decay_base":
		return false
	if RunState.decay_adjacent_age.has(Board.key(Vector2i.ZERO)):
		return false
	if not RunState.decay_tiles.has(Board.key(Vector2i.ZERO)):
		return false
	if RunState.connected_set.has(Board.key(Vector2i.ZERO)):
		return false
	return true

func test_adjacency_timer_resets_when_decay_removed() -> bool:
	_reset_state()
	var board := Board.new()
	board.add_tile(Vector2i.ZERO, "Grove", "grove_base")
	board.add_decay(Vector2i(1, 0))
	var decay_key := Board.key(Vector2i(1, 0))
	RunState.decay_tiles[decay_key] = {"age_adj_life": 0}
	Decay.apply_adjacency_corruption(board)
	var life_key := Board.key(Vector2i.ZERO)
	if int(RunState.decay_adjacent_age.get(life_key, 0)) != 1:
		return false
	board.remove_tile(Vector2i(1, 0))
	RunState.decay_tiles.erase(decay_key)
	Decay.apply_adjacency_corruption(board)
	return not RunState.decay_adjacent_age.has(life_key)
