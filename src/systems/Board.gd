extends Node
## Minimal board data container used for tests and turn processing.
class_name Board

var placed_tiles: Dictionary = {}

static func key(axial: Vector2i) -> String:
		return "%d,%d" % [axial.x, axial.y]

static func unkey(k: String) -> Vector2i:
		var parts := k.split(",")
		return Vector2i(int(parts[0]), int(parts[1]))

func add_tile(axial: Vector2i, category: String, variant_id: String) -> void:
		placed_tiles[key(axial)] = {
				"category": category,
				"variant_id": variant_id,
				"flags": {},
		}
		_render_tile(axial, category, variant_id)

func replace_tile(axial: Vector2i, category: String, variant_id: String) -> void:
		placed_tiles[key(axial)] = {
				"category": category,
				"variant_id": variant_id,
				"flags": {},
		}
		_render_tile(axial, category, variant_id)

func add_decay(axial: Vector2i) -> void:
		add_tile(axial, "Decay", "decay_base")

func remove_tile(axial: Vector2i) -> void:
		placed_tiles.erase(key(axial))

func get_tile(axial: Vector2i) -> Dictionary:
		return placed_tiles.get(key(axial), {})

func has_tile(axial: Vector2i) -> bool:
		return placed_tiles.has(key(axial))

func is_empty(axial: Vector2i) -> bool:
		return not placed_tiles.has(key(axial))

func is_decay(axial: Vector2i) -> bool:
		if not placed_tiles.has(key(axial)):
				return false
		var tile: Dictionary = placed_tiles[key(axial)]
		return tile.get("category", "") == "Decay"

func _render_tile(_axial: Vector2i, _category: String, _variant_id: String) -> void:
		# Rendering is handled elsewhere in the main project; tests only require the data state.
		pass
