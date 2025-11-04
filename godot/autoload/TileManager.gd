## Maintains placed tiles, adjacency data, and decay helper state for effects.
extends Node
class_name TileManagerClass

signal tile_placed(tile)
signal tile_removed(tile)
signal tile_transformed(tile, previous_id)
signal adjacency_changed(changed_positions)

const HEX_DIRECTIONS := [
	Vector2i(1, 0),
	Vector2i(1, -1),
	Vector2i(0, -1),
	Vector2i(-1, 0),
	Vector2i(-1, 1),
	Vector2i(0, 1),
]
const CATEGORY_OVERGROWTH := "overgrowth"
const CATEGORY_GROVE := "grove"

class TileRef extends RefCounted:
	var uid: int
	var id: String
	var position: Vector2i
	var category: String
	var tags: Array[String] = []
	var stats: Dictionary = {}
	var definition: Dictionary = {}

	func _init(uid_value: int, tile_id: String, tile_pos: Vector2i, def: Dictionary) -> void:
		self.uid = uid_value
		self.id = tile_id
		self.position = tile_pos
		self.definition = def.duplicate(true)
		self.category = String(def.get("category", ""))
		self.tags = TileManagerClass._extract_tags(def.get("tags", []))
		reset_stats()

	func reset_stats() -> void:
				self.stats = TileManagerClass._build_default_stats()

	func duplicate() -> TileRef:
		var copy := TileRef.new(uid, id, position, definition)
		copy.stats = TileManagerClass._deep_copy_dict(stats)
		copy.tags = tags.duplicate()
		copy.category = category
		return copy

var _tiles: Dictionary = {}
var _adjacent_cache: Dictionary = {}
var _decay_cells: Dictionary = {}
var _next_uid: int = 1

func clear() -> void:
	_tiles.clear()
	_adjacent_cache.clear()
	_decay_cells.clear()
	_next_uid = 1
	emit_signal("adjacency_changed", [])

func place_tile(tile_id: String, position: Vector2i) -> TileRef:
	if tile_id.is_empty():
		return null
	if _tiles.has(position):
		return null
	var def := DataDB.get_tile_def(tile_id)
	if def.is_empty():
		return null
	var tile := TileRef.new(_generate_uid(), tile_id, position, def)
	_tiles[position] = tile
	_update_adjacency_around(position)
	emit_signal("tile_placed", tile)
	emit_signal("adjacency_changed", [position])
	return tile

func remove_tile(position: Vector2i) -> void:
	var tile: TileRef = get_tile(position)
	if tile == null:
		return
	_tiles.erase(position)
	_adjacent_cache.erase(position)
	_update_adjacency_around(position)
	emit_signal("tile_removed", tile)
	emit_signal("adjacency_changed", [position])

func transform_tile(position: Vector2i, new_tile_id: String) -> TileRef:
	var tile: TileRef = get_tile(position)
	if tile == null:
		return null
	var def := DataDB.get_tile_def(new_tile_id)
	if def.is_empty():
		return tile
	var previous_id := tile.id
	tile.id = new_tile_id
	tile.definition = def.duplicate(true)
	tile.category = String(def.get("category", ""))
	tile.tags = _extract_tags(def.get("tags", []))
	tile.reset_stats()
	_update_adjacency_around(position)
	emit_signal("tile_transformed", tile, previous_id)
	emit_signal("adjacency_changed", [position])
	return tile

func get_tile(position: Vector2i) -> TileRef:
	var tile_variant: Variant = _tiles.get(position, null)
	return tile_variant if tile_variant is TileRef else null

func has_tile(position: Vector2i) -> bool:
	return _tiles.has(position)

func get_all_tiles() -> Array:
	var result: Array = []
	for tile in _tiles.values():
		if tile is TileRef:
			result.append(tile)
	return result

func get_all_positions() -> Array:
	return _tiles.keys()

func get_adjacent_tiles(position: Vector2i) -> Array:
	var cached: Variant = _adjacent_cache.get(position, null)
	if cached is Array:
		return (cached as Array).duplicate()
	var computed := _compute_adjacent_tiles(position)
	if computed.is_empty():
		_adjacent_cache.erase(position)
	else:
		_adjacent_cache[position] = computed
	return computed.duplicate()

func get_adjacent_positions(position: Vector2i) -> Array:
	var result: Array = []
	for offset in HEX_DIRECTIONS:
		result.append(position + offset)
	return result

func get_tiles_in_radius(center: Vector2i, radius: int) -> Array:
	var result: Array = []
	if radius < 0:
		return result
	var tile := get_tile(center)
	if tile != null:
		result.append(tile)
	if radius == 0:
		return result
	var visited := {center: true}
	var frontier: Array = [center]
	for _step in range(radius):
		var next_frontier: Array = []
		for pos in frontier:
			for neighbor in get_adjacent_positions(pos):
				if visited.has(neighbor):
					continue
				visited[neighbor] = true
				next_frontier.append(neighbor)
				var neighbor_tile := get_tile(neighbor)
				if neighbor_tile != null:
					result.append(neighbor_tile)
		frontier = next_frontier
	return result

func filter_by_tags(tiles: Array, any: Variant = [], all: Variant = [], categories: Variant = []) -> Array:
	var any_list := _string_array(any)
	var all_list := _string_array(all)
	var category_list := _string_array(categories)
	var result: Array = []
	for tile_variant in tiles:
		if not (tile_variant is TileRef):
			continue
		var tile: TileRef = tile_variant
		if not any_list.is_empty():
			var matched := false
			for tag in any_list:
				if tile.tags.has(tag):
					matched = true
					break
			if not matched:
				continue
		if not all_list.is_empty():
			var all_pass := true
			for tag in all_list:
				if not tile.tags.has(tag):
					all_pass = false
					break
			if not all_pass:
				continue
		if not category_list.is_empty():
			if not category_list.has(tile.category):
				continue
		result.append(tile)
	return result

func count_adjacent_with_tag(position: Vector2i, tag: String) -> int:
	if tag.is_empty():
		return 0
	var total := 0
	for neighbor_tile in get_adjacent_tiles(position):
		if neighbor_tile is TileRef and neighbor_tile.tags.has(tag):
			total += 1
	return total

func is_touching_decay(position: Vector2i) -> bool:
	if _decay_cells.has(position):
		return true
	for neighbor in get_adjacent_positions(position):
		if _decay_cells.has(neighbor):
			return true
	return false

func set_decay_cell(position: Vector2i, health: float = 1.0) -> void:
	_decay_cells[position] = max(0.0, health)

func clear_decay() -> void:
	_decay_cells.clear()

func get_decay_cells_in_radius(center: Vector2i, radius: int) -> Array:
	var result: Array = []
	if radius < 0:
		return result
	var visited := {center: true}
	var frontier: Array = [center]
	if _decay_cells.has(center):
		result.append(center)
	for _step in range(radius):
		var next_frontier: Array = []
		for pos in frontier:
			for neighbor in get_adjacent_positions(pos):
				if visited.has(neighbor):
					continue
				visited[neighbor] = true
				next_frontier.append(neighbor)
				if _decay_cells.has(neighbor):
					result.append(neighbor)
		frontier = next_frontier
	return result

func remove_decay_cell(position: Vector2i) -> void:
	_decay_cells.erase(position)

func damage_decay_cell(position: Vector2i, amount: float) -> bool:
	if not _decay_cells.has(position):
		return false
	var remaining: float = float(_decay_cells[position]) - max(0.0, amount)
	if remaining <= 0.0:
		_decay_cells.erase(position)
		return true
	_decay_cells[position] = remaining
	return false


static func _build_default_stats() -> Dictionary:
	return {
		"output": {"nature": 0.0, "earth": 0.0, "water": 0.0},
		"cap": {"local": 0.0, "global": 0.0},
		"purity": 0.0,
		"battle": {
			"hp_pct": 0.0,
			"regen_pct": 0.0,
			"attack_pct": 0.0,
			"cooldown_mult": 1.0,
		},
	}

static func _extract_tags(source: Variant) -> Array[String]:
	var tags: Array[String] = []
	var working: Variant = source
	if working is PackedStringArray:
		working = Array(working)
	if working is Array:
		for entry in working:
			var tag := String(entry).strip_edges()
			if tag.is_empty():
				continue
			if not tags.has(tag):
				tags.append(tag)
	elif typeof(working) == TYPE_STRING:
		var single := String(working).strip_edges()
		if not single.is_empty():
			tags.append(single)
	return tags

static func _deep_copy_dict(data: Dictionary) -> Dictionary:
	return data.duplicate(true)
	
static func _string_array(source: Variant) -> Array:
	var result: Array = []
	var working: Variant = source
	if working is PackedStringArray:
		working = Array(working)
	if working is Array:
		for entry in working:
			var value := String(entry).strip_edges()
			if value.is_empty():
				continue
			result.append(value)
	elif typeof(working) == TYPE_STRING:
		var single := String(working).strip_edges()
		if not single.is_empty():
			result.append(single)
	return result

func _generate_uid() -> int:
	var uid := _next_uid
	_next_uid += 1
	return uid

func _compute_adjacent_tiles(position: Vector2i) -> Array:
	var result: Array = []
	for offset in HEX_DIRECTIONS:
		var neighbor: Vector2i = position + offset
		var neighbor_tile := get_tile(neighbor)
		if neighbor_tile != null:
			result.append(neighbor_tile)
	return result


func _update_adjacency_around(position: Vector2i) -> void:
	_update_adjacency_for(position)
	for neighbor in get_adjacent_positions(position):
		_update_adjacency_for(neighbor)

func _update_adjacency_for(position: Vector2i) -> void:
	var neighbors := _compute_adjacent_tiles(position)
	if neighbors.is_empty():
		_adjacent_cache.erase(position)
	else:
		_adjacent_cache[position] = neighbors
