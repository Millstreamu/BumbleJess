extends Node

signal battle_result(victory: bool, rewards: Dictionary)

func open_battle(encounter: Dictionary, callback: Callable) -> void:
	var victory := true
	var turn_engine := get_node_or_null("/root/TurnEngine")
	if turn_engine != null:
		var turn_value = turn_engine.get("turn_count") if turn_engine.has_method("get") else turn_engine.turn_count
		if typeof(turn_value) == TYPE_INT and turn_value != 0:
			victory = int(turn_value) % 2 == 0
	var rewards := {"life": 3}
	emit_signal("battle_result", victory, rewards)
	var result := {
		"victory": victory,
		"rewards": rewards,
		"target_cell": encounter.get("target", Vector2i.ZERO),
	}
	if callback.is_valid():
		callback.call(result)
