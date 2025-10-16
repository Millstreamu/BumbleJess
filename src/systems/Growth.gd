extends Node
class_name Growth

const RunState := preload("res://src/core/RunState.gd")
const CombatLog := preload("res://src/ui/CombatLogPanel.gd")
const Board := preload("res://src/systems/Board.gd")

static func key(ax: Vector2i) -> String:
		return "%d,%d" % [ax.x, ax.y]

static func unkey(k: String) -> Vector2i:
		var p := k.split(",")
		return Vector2i(int(p[0]), int(p[1]))

static func do_growth(board: Node) -> void:
		if RunState.overgrowth.size() == 0:
				return
		var to_promote: Array = []
		var keys: Array = RunState.overgrowth.keys()
		for k in keys:
				var current_age := int(RunState.overgrowth[k])
				current_age += 1
				RunState.overgrowth[k] = current_age
				if current_age >= 3:
						to_promote.append(k)
		for k in to_promote:
				RunState.overgrowth.erase(k)
				var ax := unkey(k)
                                board.replace_tile(ax, "Grove", "grove_base", "grow")
                                RunState.connected_set[k] = true
                                var message := "Grove blossomed at %s" % Board.key(ax)
                                RunState.add_turn_note(message)
                                CombatLog.log("• " + message)
