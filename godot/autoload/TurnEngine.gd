extends Node

signal turn_started(turn: int)
signal phase_started(phase_name: String)
signal turn_ended(turn: int)
signal triple_turn(turn: int)

var turn_count: int = 1

func _ready() -> void:
        call_deferred("_start_turn")

func advance_one_turn() -> void:
        _phase("growth")
        _phase("resources")
        _phase("decay")
        _phase("regen")
        _phase("totem_passives")
        emit_signal("turn_ended", turn_count)
        turn_count += 1
        if turn_count % 3 == 0:
                emit_signal("triple_turn", turn_count)
        _start_turn()

func _phase(phase_name: String) -> void:
        emit_signal("phase_started", phase_name)

func _start_turn() -> void:
        emit_signal("turn_started", turn_count)
        _phase("commune")
