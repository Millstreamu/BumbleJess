extends Node

const MAX_SELECTION := 6

var _roster: Array[Dictionary] = []
var _last_selection: Array[Dictionary] = []

func _ready() -> void:
		if _roster.is_empty():
				_roster = [
						{"id": "sprout.woodling", "level": 1},
						{"id": "sprout.woodling", "level": 2},
						{"id": "sprout.woodling", "level": 3},
				]

func on_grove_spawned(cell: Vector2i) -> void:
		# Placeholder implementation; future work can replace this with actual sprout creation.
		print("Grove spawned at ", cell)

func get_roster() -> Array:
		return _roster.duplicate(true)

func add_to_roster(entry: Dictionary) -> void:
				_roster.append(entry.duplicate(true))

func remove_from_roster_by_index(i: int) -> void:
		if i >= 0 and i < _roster.size():
				_roster.remove_at(i)

func set_last_selection(sel: Array) -> void:
		_last_selection = _sanitize_selection(sel)

func get_last_selection() -> Array:
		return _last_selection.duplicate(true)

func pick_for_battle(n: int) -> Array:
				if _last_selection.size() > 0:
								var count: int = min(n, _last_selection.size())
								return _last_selection.slice(0, count)
				var result: Array[Dictionary] = []
				var limit: int = min(n, _roster.size())
				for i in range(limit):
								result.append(_roster[i].duplicate(true))
				return result

func _sanitize_selection(sel: Array) -> Array:
				var result: Array[Dictionary] = []
				var limit: int = min(sel.size(), MAX_SELECTION)
				for i in range(limit):
								var entry: Variant = sel[i]
								if typeof(entry) == TYPE_DICTIONARY:
												result.append(Dictionary(entry).duplicate(true))
				return result
