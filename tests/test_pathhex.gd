extends RefCounted

const Board := preload("res://src/systems/Board.gd")
const PathHex := preload("res://src/core/PathHex.gd")
const RunState := preload("res://src/core/RunState.gd")

func _reset_state() -> void:
	RunState.connected_set = {}
	RunState.decay_tiles = {}
	RunState.decay_adjacent_age = {}
	RunState.decay_totems = []
	RunState.overgrowth = {}

func test_nearest_connected_step_skips_blocked_tiles() -> bool:
	_reset_state()
	var board := Board.new()
	board.add_tile(Vector2i.ZERO, "Grove", "grove_base")
	board.add_tile(Vector2i(1, 0), "Grove", "grove_base")
	board.add_tile(Vector2i(1, -1), "Grove", "grove_base")
	RunState.connected_set[Board.key(Vector2i.ZERO)] = true
	RunState.connected_set[Board.key(Vector2i(1, 0))] = true
	PathHex.set_board(board)
	var step := PathHex.nearest_connected_step(Vector2i(2, -2))
	var repeat_step := PathHex.nearest_connected_step(Vector2i(2, -2))
	return step == Vector2i(2, -1) and repeat_step == step
