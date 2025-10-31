extends Node

var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var deck: Array[String] = []
var next_tile_id: String = ""

var tiles_by_category: Dictionary = {}
var tiles_by_id: Dictionary = {}
var id_to_category: Dictionary = {}
var id_to_canonical: Dictionary = {}
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
                var canonical_cat := CategoryMap.canonical(cat)
                var chosen_id := String(selected.get(cat, ""))
                if chosen_id.is_empty():
                        chosen_id = String(selected.get(canonical_cat, ""))
                if chosen_id.is_empty() and canonical_cat == "Mystic":
                        chosen_id = String(selected.get("chanting", ""))
                if chosen_id.is_empty():
                        chosen_id = _first_id_for_category(cat)
                if chosen_id.is_empty():
                        continue
                for _i in range(count):
                        deck.append(chosen_id)

func build_deck_from_core(path: String, selected_core: Array[String]) -> void:
        next_tile_id = ""
        deck.clear()
        _rebuild_tile_catalog()
        var conf: Dictionary = DataLite.load_json_dict(path)
        var ratios_variant: Variant = conf.get("start_ratios", conf.get("counts", {}))
        var ratios: Dictionary = ratios_variant if ratios_variant is Dictionary else {}
        if ratios.is_empty():
                return
        var cat_pick: Dictionary = {}
        for cat_key in ratios.keys():
                var cat_str := String(cat_key)
                var canonical_cat := CategoryMap.canonical(cat_str)
                var chosen := ""
                if typeof(selected_core) == TYPE_ARRAY:
                        for entry in selected_core:
                                if typeof(entry) != TYPE_STRING:
                                        continue
                                var cid := String(entry)
                                if cid.is_empty():
                                        continue
                                var core_cat := String(id_to_canonical.get(cid, ""))
                                if core_cat.is_empty():
                                        core_cat = CategoryMap.canonical(String(id_to_category.get(cid, "")))
                                if canonical_cat.is_empty():
                                        if core_cat.is_empty():
                                                chosen = cid
                                                break
                                elif core_cat == canonical_cat:
                                        chosen = cid
                                        break
                if chosen.is_empty():
                        var fallback_cat := canonical_cat if not canonical_cat.is_empty() else cat_str
                        chosen = _first_id_for_category(fallback_cat)
                cat_pick[cat_key] = chosen
        for cat_key in ratios.keys():
                var count := int(ratios[cat_key])
                if count <= 0:
                        continue
                var pick := String(cat_pick.get(cat_key, ""))
                if pick.is_empty():
                        continue
                for _i in range(count):
                        deck.append(pick)
        shuffle()
        draw_one()

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

func get_tile_canonical_category(id: String) -> String:
        if id.is_empty():
                return ""
        var stored: Variant = id_to_canonical.get(id, null)
        if typeof(stored) == TYPE_STRING:
                return String(stored)
        return CategoryMap.canonical(get_tile_category(id))

func get_tile_name(id: String) -> String:
        var info_variant: Variant = tiles_by_id.get(id, {})
        var info: Dictionary = info_variant if info_variant is Dictionary else {}
        return String(info.get("name", id))

func _rebuild_tile_catalog() -> void:
        tiles_by_category.clear()
        tiles_by_id.clear()
        id_to_category.clear()
        id_to_canonical.clear()
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
                var canonical_cat: String = CategoryMap.canonical(category)
                var tile_name: String = String(tile.get("name", id))
                var info: Dictionary = {
                        "id": id,
                        "category": category,
                        "name": tile_name,
                        "canonical_category": canonical_cat,
                }
                tiles_by_id[id] = info
                id_to_category[id] = category
                id_to_canonical[id] = canonical_cat
                id_to_name[id] = tile_name
                var canonical_key := canonical_cat if not canonical_cat.is_empty() else category
                if not canonical_key.is_empty():
                        var canonical_list_variant: Variant = tiles_by_category.get(canonical_key, [])
                        var canonical_list: Array = canonical_list_variant if canonical_list_variant is Array else []
                        canonical_list.append(id)
                        tiles_by_category[canonical_key] = canonical_list
                if canonical_key != category and not category.is_empty():
                        var legacy_list_variant: Variant = tiles_by_category.get(category, [])
                        var legacy_list: Array = legacy_list_variant if legacy_list_variant is Array else []
                        legacy_list.append(id)
                        tiles_by_category[category] = legacy_list

func _first_id_for_category(cat: String) -> String:
        var canonical_key := CategoryMap.canonical(cat)
        var list_variant: Variant = tiles_by_category.get(canonical_key, [])
        var list: Array = list_variant if list_variant is Array else []
        if list.is_empty() and canonical_key != cat:
                list_variant = tiles_by_category.get(cat, [])
                list = list_variant if list_variant is Array else []
        if list.is_empty():
                return ""
        return String(list[0])
