extends RefCounted

const Resources := preload("res://scripts/world/Resources.gd")
const Board := preload("res://scripts/world/Board.gd")
const RunState := preload("res://autoload/RunState.gd")

func _setup_board() -> Board:
        Resources.reset()
        RunState.refine_cooldown = {}
        return Board.new()

func test_harvest_yield_per_adjacent_grove() -> bool:
        var board := _setup_board()
        board.add_tile(Vector2i(0, 0), "Harvest", "harvest_default")
        board.add_tile(Vector2i(1, 0), "Grove", "grove_base")
        board.add_tile(Vector2i(0, 1), "Grove", "grove_base")
        Resources.do_production(board)
        if Resources.amount["Nature"] != 2:
                push_error("Harvest should gain 2 Nature from two adjacent Groves")
                return false
        return true

func test_refine_converts_every_two_turns() -> bool:
        var board := _setup_board()
        board.add_tile(Vector2i(0, 0), "Harvest", "harvest_default")
        board.add_tile(Vector2i(1, 0), "Grove", "grove_base")
        board.add_tile(Vector2i(-1, 0), "Build", "build_default")
        board.add_tile(Vector2i(0, 1), "Refine", "refine_default")
        Resources.do_production(board)
        if Resources.amount["Nature"] != 1:
                push_error("First resources phase should generate 1 Nature")
                return false
        if Resources.amount["Earth"] != 1:
                push_error("First resources phase should generate 1 Earth")
                return false
        Resources.do_production(board)
        if Resources.amount["Water"] != 1:
                push_error("Refine should produce 1 Water on the second phase")
                return false
        if Resources.amount["Nature"] != 1:
                push_error("Nature should be reduced to 1 after conversion")
                return false
        if Resources.amount["Earth"] != 1:
                push_error("Earth should be reduced to 1 after conversion")
                return false
        return true
