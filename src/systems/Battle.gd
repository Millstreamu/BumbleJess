extends Node
class_name Battle

const RunState := preload("res://src/core/RunState.gd")
const Board := preload("res://src/systems/Board.gd")
const CombatLog := preload("res://src/ui/CombatLogPanel.gd")

static func resolve_all(board: Node) -> void:
	if board == null:
		return
	var cleansed: Array[String] = []
	if board is Board:
		var b: Board = board
		for key in b.placed_tiles.keys():
			var tile: Dictionary = b.placed_tiles[key]
			if String(tile.get("category", "")) != "Decay":
				continue
			if not RunState.connected_set.has(key):
				continue
			var axial := Board.unkey(key)
			b.remove_tile(axial)
			b._render_tile(axial, "", "", "cleanse")
			cleansed.append(key)
	for key in cleansed:
		RunState.decay_tiles.erase(key)
	var message := "Battle phase quiet — no decay cleansed."
	if cleansed.size() == 1:
		message = "Guardians cleansed 1 decay tile."
	elif cleansed.size() > 1:
		message = "Guardians cleansed %d decay tiles." % cleansed.size()
	RunState.add_turn_note(message)
	CombatLog.log("• " + message)
