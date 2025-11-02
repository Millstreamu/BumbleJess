extends Node

var _tiles: Array = []
var _id_to_def: Dictionary = {}
var id_to_tags: Dictionary = {}
var id_to_category: Dictionary = {}

func _ready() -> void:
        _reload_tiles()

func refresh() -> void:
        _reload_tiles()

func get_tile_def(id: String) -> Dictionary:
        _ensure_loaded()
        var def_variant: Variant = _id_to_def.get(id, {})
        if def_variant is Dictionary:
                return (def_variant as Dictionary).duplicate(true)
        return {}

func get_tags_for_id(id: String) -> Array:
        _ensure_loaded()
        var tags_variant: Variant = id_to_tags.get(id, [])
        if tags_variant is Array:
                return (tags_variant as Array).duplicate()
        if tags_variant is PackedStringArray:
                return Array(tags_variant)
        return []

func get_category_for_id(id: String) -> String:
        _ensure_loaded()
        return String(id_to_category.get(id, ""))

func _ensure_loaded() -> void:
        if _id_to_def.is_empty():
                _reload_tiles()

func _reload_tiles() -> void:
        _tiles = DataLite.load_json_array("res://data/tiles.json")
        _id_to_def.clear()
        id_to_tags.clear()
        id_to_category.clear()
        for entry_variant in _tiles:
                if not (entry_variant is Dictionary):
                        continue
                var entry: Dictionary = (entry_variant as Dictionary)
                var tile_id := String(entry.get("id", ""))
                if tile_id.is_empty():
                        continue
                _id_to_def[tile_id] = entry.duplicate(true)
                id_to_tags[tile_id] = _normalize_tags(entry.get("tags", []))
                id_to_category[tile_id] = _canonicalize_category(String(entry.get("category", "")))

func _normalize_tags(source: Variant) -> Array:
        var result: Array = []
        var tags_source := source
        if tags_source is PackedStringArray:
                tags_source = Array(tags_source)
        if tags_source is Array:
                for tag in tags_source:
                        var tag_str := String(tag).strip_edges()
                        if tag_str.is_empty():
                                continue
                        if not result.has(tag_str):
                                result.append(tag_str)
        elif typeof(tags_source) == TYPE_STRING:
                var single := String(tags_source).strip_edges()
                if not single.is_empty():
                        result.append(single)
        return result

func _canonicalize_category(value: String) -> String:
        var trimmed := String(value).strip_edges()
        if trimmed.is_empty():
                return ""
        if typeof(CategoryMap) != TYPE_NIL:
                return CategoryMap.canonical(trimmed)
        return trimmed
