extends RefCounted

const Resources := preload("res://src/systems/Resources.gd")
const Board := preload("res://src/systems/Board.gd")
const RunState := preload("res://src/core/RunState.gd")

func _setup() -> Board:
        Resources.reset()
        RunState.refine_cooldown = {}
        return Board.new()

func test_baseline_caps_from_tiles() -> bool:
        var board := _setup()
        board.add_tile(Vector2i(0, 0), "Harvest", "harvest_default")
        board.add_tile(Vector2i(1, 0), "Build", "build_default")
        board.add_tile(Vector2i(0, 1), "Refine", "refine_default")
        board.add_tile(Vector2i(-1, 0), "Grove", "grove_base")
        Resources.do_production(board)
        if Resources.cap["Nature"] != 10:
                push_error("Expected Nature cap 10 from Harvest+Grove baseline")
                return false
        if Resources.cap["Earth"] != 5:
                push_error("Expected Earth cap 5 from one Build tile")
                return false
        if Resources.cap["Water"] != 5:
                push_error("Expected Water cap 5 from one Refine tile")
                return false
        return true

func test_harvest_cluster_bonus() -> bool:
        var board := _setup()
        board.add_tile(Vector2i(0, 0), "Harvest", "harvest_default")
        board.add_tile(Vector2i(1, 0), "Harvest", "harvest_default")
        board.add_tile(Vector2i(0, 1), "Harvest", "harvest_default")
        Resources.do_production(board)
        var expected := 3 * 5 + 3 * 10
        if Resources.cap["Nature"] != expected:
                push_error("Expected Nature cap %d, got %d" % [expected, Resources.cap["Nature"]])
                return false
        return true

func test_storage_adjacent_bonus() -> bool:
        var board := _setup()
        board.add_tile(Vector2i(0, 0), "Storage", "storage_default")
        board.add_tile(Vector2i(1, 0), "Harvest", "harvest_default")
        board.add_tile(Vector2i(-1, 0), "Build", "build_default")
        board.add_tile(Vector2i(0, 1), "Refine", "refine_default")
        Resources.do_production(board)
        if Resources.cap["Nature"] != 10:
                push_error("Storage adjacency should raise Nature cap to 10")
                return false
        if Resources.cap["Earth"] != 10:
                push_error("Storage adjacency should raise Earth cap to 10")
                return false
        if Resources.cap["Water"] != 10:
                push_error("Storage adjacency should raise Water cap to 10")
                return false
        return true
