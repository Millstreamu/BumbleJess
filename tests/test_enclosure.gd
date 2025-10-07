extends RefCounted

const Board := preload("res://src/systems/Board.gd")
const Enclosure := preload("res://src/systems/Enclosure.gd")
const RunState := preload("res://src/core/RunState.gd")

func _ring_positions(center: Vector2i) -> Array:
        return [
                center + Vector2i(1, 0),
                center + Vector2i(1, -1),
                center + Vector2i(0, -1),
                center + Vector2i(-1, 0),
                center + Vector2i(-1, 1),
                center + Vector2i(0, 1),
        ]

func _reset_state() -> void:
        RunState.overgrowth = {}
        RunState.connected_set = {}

func test_single_hex_enclosure_marks_overgrowth() -> bool:
        _reset_state()
        var board := Board.new()
        var center := Vector2i.ZERO
        for pos in _ring_positions(center):
                board.add_tile(pos, "Harvest", "harvest_basic")
        Enclosure.detect_and_mark_overgrowth(board)
        var center_key := Board.key(center)
        if not RunState.overgrowth.has(center_key):
                return false
        if int(RunState.overgrowth[center_key]) != 0:
                return false
        var first_size := RunState.overgrowth.size()
        Enclosure.detect_and_mark_overgrowth(board)
        if RunState.overgrowth.size() != first_size:
                return false
        return int(RunState.overgrowth[center_key]) == 0
