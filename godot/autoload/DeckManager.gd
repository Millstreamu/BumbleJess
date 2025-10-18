extends Node

var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var deck: Array[String] = []
var next_tile_id: String = ""

var tiles_by_category: Dictionary = {}
var tiles_by_id: Dictionary = {}

func _ready() -> void:
	rng.randomize()
	build_starting_deck()
	shuffle()
	draw_one()

func build_starting_deck() -> void:
	deck.clear()
	tiles_by_category.clear()
	tiles_by_id.clear()

	var tiles_raw: Variant = _load_json("res://data/tiles.json")
	var tiles: Array = tiles_raw if tiles_raw is Array else []
	for t in tiles:
		if typeof(t) != TYPE_DICTIONARY:
			continue
		var id: String = String(t.get("id", ""))
		if id.is_empty():
			continue
		var category: String = String(t.get("category", ""))
		var name: String = String(t.get("name", id))
		var info: Dictionary = {
			"id": id,
			"category": category,
			"name": name,
		}
		tiles_by_id[id] = info
		if not tiles_by_category.has(category):
			tiles_by_category[category] = []
		tiles_by_category[category].append(id)

	var deck_data_raw: Variant = _load_json("res://data/deck.json")
	var deck_data: Dictionary = deck_data_raw if deck_data_raw is Dictionary else {}
	var counts_variant: Variant = deck_data.get("counts", {})
	var counts: Dictionary = counts_variant if counts_variant is Dictionary else {}
	var target_size: int = int(deck_data.get("target_size", 30))
	var filler_category: String = String(deck_data.get("fill_with", "harvest"))

	for cat in counts.keys():
		var count: int = int(counts[cat])
		var list_variant: Variant = tiles_by_category.get(cat, [])
		var list: Array = list_variant if list_variant is Array else []
		if list.is_empty():
			continue
		var base_id := String(list[0])
		for i in range(count):
			deck.append(base_id)

	if deck.size() < target_size:
		var filler_variant: Variant = tiles_by_category.get(filler_category, [])
		var filler_list: Array = filler_variant if filler_variant is Array else []
		if not filler_list.is_empty():
			var filler_id: String = String(filler_list[0])
			while deck.size() < target_size:
				deck.append(filler_id)

func shuffle() -> void:
	for i in range(deck.size() - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var temp: String = deck[i]
		deck[i] = deck[j]
		deck[j] = temp

func draw_one() -> String:
	if deck.is_empty():
		next_tile_id = ""
		return next_tile_id
	next_tile_id = String(deck.pop_back())
	return next_tile_id

func peek() -> String:
	return next_tile_id

func remaining() -> int:
	return deck.size()

func get_tile_info(id: String) -> Dictionary:
	var info_variant: Variant = tiles_by_id.get(id, {})
	return info_variant if info_variant is Dictionary else {}

func get_tile_category(id: String) -> String:
	var info_variant: Variant = tiles_by_id.get(id, {})
	var info: Dictionary = info_variant if info_variant is Dictionary else {}
	return String(info.get("category", ""))

func get_tile_name(id: String) -> String:
	var info_variant: Variant = tiles_by_id.get(id, {})
	var info: Dictionary = info_variant if info_variant is Dictionary else {}
	return String(info.get("name", id))

func _load_json(path: String) -> Variant:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return []
	var text: String = file.get_as_text()
	var parsed: Variant = JSON.parse_string(text)
	if parsed == null:
		return []
	return parsed
