extends Node

var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var deck: Array[String] = []
var next_tile_id: String = ""

var tiles_by_category: Dictionary = {}
var tiles_by_id: Dictionary = {}
var id_to_category: Dictionary = {}
var id_to_name: Dictionary = {}

func _ready() -> void:
        rng.randomize()
        build_starting_deck()
        shuffle()
        draw_one()

func build_starting_deck() -> void:
        build_starting_deck_from_ratios("res://data/deck.json", {})

func build_starting_deck_from_ratios(path: String, selected: Dictionary) -> void:
        next_tile_id = ""
        deck.clear()
        _rebuild_tile_catalog()
        var config: Dictionary = DataLite.load_json_dict(path)
        var ratios_variant: Variant = config.get("start_ratios", config.get("counts", {}))
        var ratios: Dictionary = ratios_variant if ratios_variant is Dictionary else {}
        if ratios.is_empty():
                return
        for cat in ratios.keys():
                var count := int(ratios[cat])
                if count <= 0:
                        continue
                var chosen_id := String(selected.get(cat, ""))
                if chosen_id.is_empty():
                        chosen_id = _first_id_for_category(cat)
                if chosen_id.is_empty():
                        continue
                for _i in range(count):
                        deck.append(chosen_id)

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

func peek_name() -> String:
        if next_tile_id.is_empty():
                return ""
        return get_tile_name(next_tile_id)

func peek_category() -> String:
        if next_tile_id.is_empty():
                return ""
        return get_tile_category(next_tile_id)

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

func _rebuild_tile_catalog() -> void:
        tiles_by_category.clear()
        tiles_by_id.clear()
        id_to_category.clear()
        id_to_name.clear()
        var tiles_raw: Array = DataLite.load_json_array("res://data/tiles.json")
        for entry in tiles_raw:
                if not (entry is Dictionary):
                        continue
                var tile: Dictionary = entry
                var id: String = String(tile.get("id", ""))
                if id.is_empty():
                        continue
                var category: String = String(tile.get("category", ""))
                var tile_name: String = String(tile.get("name", id))
                var info: Dictionary = {
                        "id": id,
                        "category": category,
                        "name": tile_name,
                }
                tiles_by_id[id] = info
                id_to_category[id] = category
                id_to_name[id] = tile_name
                if not tiles_by_category.has(category):
                        tiles_by_category[category] = []
                var list: Array = tiles_by_category[category]
                list.append(id)
                tiles_by_category[category] = list

func _first_id_for_category(cat: String) -> String:
        var list_variant: Variant = tiles_by_category.get(cat, [])
        var list: Array = list_variant if list_variant is Array else []
        if list.is_empty():
                return ""
        return String(list[0])
