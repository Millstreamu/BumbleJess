extends Node
## Tracks shared resource amounts and capacity caps for each essence type.
class_name Resources

const TYPES := ["Nature", "Earth", "Water", "Life"]
const STORAGE_PRODUCER_BONUS := 5
const HARVEST_CLUSTER_BONUS := 10
const DEFAULT_TILE_CAP := 5
const DEFAULT_LIFE_CAP := 999

const Clusters := preload("res://src/systems/Clusters.gd")
const ProducerRefine := preload("res://src/systems/ProducerRefine.gd")

static var amount: Dictionary = {
        "Nature": 0,
        "Earth": 0,
        "Water": 0,
        "Life": 0,
}

static var cap: Dictionary = {
        "Nature": 0,
        "Earth": 0,
        "Water": 0,
        "Life": 0,
}

static func reset() -> void:
	for t in TYPES:
		amount[t] = 0
		cap[t] = 0

static func set_cap(type: String, value: int) -> void:
	var key := _ensure_type(type)
	var clamped := max(0, value)
	cap[key] = clamped
	if clamped <= 0:
		amount[key] = 0
	else:
		amount[key] = clamp(amount[key], 0, clamped)

static func add(type: String, delta: int) -> int:
        var key := _ensure_type(type)
        var before: int = int(amount.get(key, 0))
        var limit: int = int(cap.get(key, 0))
        if limit <= 0 and key != "Life":
                amount[key] = max(0, min(before + delta, 0))
        else:
                var max_value: int = limit if limit > 0 else before + delta
                amount[key] = clamp(before + delta, 0, max_value)
        return int(amount[key]) - before

static func get_amount(type: String) -> int:
	var key := _ensure_type(type)
	return amount[key]

static func get_cap(type: String) -> int:
	var key := _ensure_type(type)
	return cap[key]

static func do_production(board: Node) -> void:
	_baseline_caps(board)
	var cluster_tiles := Clusters.count_harvest_cluster_tiles(board)
	if cluster_tiles > 0:
		set_cap("Nature", cap["Nature"] + cluster_tiles * HARVEST_CLUSTER_BONUS)
	_apply_storage_bonuses(board)
	var flat_earth := _count_tiles(board, "Build")
	add("Earth", flat_earth)
	var harvest_yield := _harvest_yield(board)
	add("Nature", harvest_yield)
	ProducerRefine.tick_and_convert(board)
	if cap["Life"] <= 0:
		set_cap("Life", DEFAULT_LIFE_CAP)

static func _baseline_caps(board: Node) -> void:
	var n := 0
	var e := 0
	var w := 0
	var tiles := _placed_tiles(board)
	for k in tiles.keys():
		var tile: Dictionary = tiles[k]
		var category := String(tile.get("category", ""))
		match category:
			"Harvest":
				n += DEFAULT_TILE_CAP
			"Grove":
				n += DEFAULT_TILE_CAP
			"Build":
				e += DEFAULT_TILE_CAP
			"Refine":
				w += DEFAULT_TILE_CAP
	set_cap("Nature", n)
	set_cap("Earth", e)
	set_cap("Water", w)
	if cap["Life"] <= 0:
		cap["Life"] = 0

static func _apply_storage_bonuses(board: Node) -> void:
	var tiles := _placed_tiles(board)
	for key in tiles.keys():
		var tile: Dictionary = tiles[key]
		if String(tile.get("category", "")) != "Storage":
			continue
		var axial := _unkey(key)
		for neighbor in _neighbors(axial):
			var nk := _key(neighbor)
			if not tiles.has(nk):
				continue
			var cat := String(tiles[nk].get("category", ""))
			var rtype := _type_for_category(cat)
			if rtype == "":
				continue
			set_cap(rtype, cap[rtype] + STORAGE_PRODUCER_BONUS)

static func _count_tiles(board: Node, category: String) -> int:
	var total := 0
	var tiles := _placed_tiles(board)
	for key in tiles.keys():
		var tile: Dictionary = tiles[key]
		if String(tile.get("category", "")) == category:
			total += 1
	return total

static func _harvest_yield(board: Node) -> int:
	var total := 0
	var tiles := _placed_tiles(board)
	for key in tiles.keys():
		var tile: Dictionary = tiles[key]
		if String(tile.get("category", "")) != "Harvest":
			continue
		var axial := _unkey(key)
		var adj_groves := 0
		for neighbor in _neighbors(axial):
			var nk := _key(neighbor)
			if tiles.has(nk) and String(tiles[nk].get("category", "")) == "Grove":
				adj_groves += 1
		total += adj_groves
	return total

static func _placed_tiles(board: Node) -> Dictionary:
	if board == null:
		return {}
	var tiles_variant := board.get("placed_tiles")
	if typeof(tiles_variant) == TYPE_DICTIONARY:
		return tiles_variant
	return {}

static func _type_for_category(cat: String) -> String:
	match cat:
		"Harvest", "Grove":
			return "Nature"
		"Build":
			return "Earth"
		"Refine":
			return "Water"
		_:
			return ""

static func _neighbors(ax: Vector2i) -> Array:
	return [
		ax + Vector2i(+1, 0),
		ax + Vector2i(+1, -1),
		ax + Vector2i(0, -1),
		ax + Vector2i(-1, 0),
		ax + Vector2i(-1, +1),
		ax + Vector2i(0, +1),
	]

static func _key(ax: Vector2i) -> String:
	return "%d,%d" % [ax.x, ax.y]

static func _unkey(k: String) -> Vector2i:
	var parts := k.split(",")
	if parts.size() != 2:
		return Vector2i.ZERO
	return Vector2i(int(parts[0]), int(parts[1]))

static func _ensure_type(type: String) -> String:
	var normalized := _normalize_type(type)
	if not amount.has(normalized):
		amount[normalized] = 0
	if not cap.has(normalized):
		cap[normalized] = 0
	return normalized

static func _normalize_type(type: String) -> String:
	var lower := type.to_lower()
	match lower:
		"nature":
			return "Nature"
		"earth":
			return "Earth"
		"water":
			return "Water"
		"life":
			return "Life"
		_:
			return type
