extends RefCounted

const Board := preload("res://scripts/world/Board.gd")
const Growth := preload("res://scripts/world/Growth.gd")
const RunState := preload("res://autoload/RunState.gd")

func _reset_state() -> void:
        RunState.overgrowth = {}
        RunState.connected_set = {}

func test_overgrowth_matures_into_grove() -> bool:
        _reset_state()
        var board := Board.new()
        var cell := Vector2i.ZERO
        var key := Board.key(cell)
        RunState.overgrowth[key] = 0
        Growth.do_growth(board)
        if int(RunState.overgrowth[key]) != 1:
                return false
        Growth.do_growth(board)
        if int(RunState.overgrowth[key]) != 2:
                return false
        Growth.do_growth(board)
        if RunState.overgrowth.has(key):
                return false
        if not board.placed_tiles.has(key):
                return false
        var tile: Dictionary = board.placed_tiles[key]
        if tile.get("category", "") != "Grove":
                return false
        if tile.get("variant_id", "") != "grove_base":
                return false
        return RunState.connected_set.has(key)
