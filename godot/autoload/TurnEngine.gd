extends Node

signal turn_started(turn: int)
signal phase_started(phase_name: String)
signal turn_ended(turn: int)
signal triple_turn(turn: int)

var turn_count: int = 1

func advance_one_turn() -> void:
        turn_count += 1
        emit_signal("turn_started", turn_count)
        _phase("growth")
        _phase("mutations")
        _phase("decay")
        _phase("resources")
        _phase("tile_gen")
        if turn_count % 3 == 0:
                emit_signal("triple_turn", turn_count)
        emit_signal("turn_ended", turn_count)

func _phase(phase_name: String) -> void:
        emit_signal("phase_started", phase_name)
