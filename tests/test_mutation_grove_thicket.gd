extends RefCounted

const Board := preload("res://src/systems/Board.gd")
const Mutation := preload("res://src/systems/Mutation.gd")

func _make_basic_board() -> Board:
        var board := Board.new()
        board.add_tile(Vector2i.ZERO, "Grove", "grove_base")
        return board

func test_grove_adjacent_to_harvest_sets_thicket() -> bool:
        var board := _make_basic_board()
        board.add_tile(Vector2i(1, 0), "Harvest", "harvest_basic")
        Mutation.do_mutations(board)
        var grove_data: Dictionary = board.get_tile(Vector2i.ZERO)
        if not grove_data.has("flags"):
                return false
        if not bool(grove_data["flags"].get("thicket", false)):
                return false
        board.remove_tile(Vector2i(1, 0))
        Mutation.do_mutations(board)
        grove_data = board.get_tile(Vector2i.ZERO)
        return not bool(grove_data["flags"].get("thicket", false))
