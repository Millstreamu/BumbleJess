extends Node

const CANONICAL_ORDER: Array[String] = [
        "Nature",
        "Earth",
        "Water",
        "Nest",
        "Aggression",
        "Mystic",
]

const LEGACY_TO_CANONICAL: Dictionary = {
        "harvest": "Nature",
        "build": "Earth",
        "refine": "Water",
        "storage": "Nest",
        "guard": "Aggression",
        "upgrade": "Mystic",
        "chanting": "Mystic",
}

const CANONICAL_TO_LEGACY: Dictionary = {
        "Nature": "harvest",
        "Earth": "build",
        "Water": "refine",
        "Nest": "storage",
        "Aggression": "guard",
        "Mystic": "upgrade",
}

const DISPLAY_NAMES: Dictionary = {
        "Nature": "Nature",
        "Earth": "Earth",
        "Water": "Water",
        "Nest": "Nest",
        "Aggression": "Aggression",
        "Mystic": "Mystic",
}

var _tile_category_cache: Dictionary = {}

func canonical(cat_or_id: String) -> String:
        var token := _normalize_input(cat_or_id)
        if token.is_empty():
                return cat_or_id
        if token.begins_with("tile."):
                return normalize_from_tile_id(token)
        if token.begins_with("cat:"):
                token = token.substr(4)
        var lower := token.to_lower()
        if LEGACY_TO_CANONICAL.has(lower):
                return String(LEGACY_TO_CANONICAL[lower])
        if DISPLAY_NAMES.has(token):
                return token
        if CANONICAL_TO_LEGACY.has(token):
                return token
        for canonical_name in DISPLAY_NAMES.keys():
                        if String(canonical_name).to_lower() == lower:
                                return String(canonical_name)
        return cat_or_id

func legacy(cat_or_id: String) -> String:
        var token := _normalize_input(cat_or_id)
        if token.is_empty():
                return cat_or_id
        if token.begins_with("tile."):
                var canonical_name := normalize_from_tile_id(token)
                return legacy(canonical_name)
        if token.begins_with("cat:"):
                token = token.substr(4)
        var lower_token := token.to_lower()
        if LEGACY_TO_CANONICAL.has(lower_token):
                return String(lower_token)
        var canonical_name := canonical(token)
        if CANONICAL_TO_LEGACY.has(canonical_name):
                return String(CANONICAL_TO_LEGACY[canonical_name])
        var lower := canonical_name.to_lower()
        for legacy_name in LEGACY_TO_CANONICAL.keys():
                if LEGACY_TO_CANONICAL[legacy_name] == canonical_name:
                        return String(legacy_name)
        return token

func display_name(cat_or_id: String) -> String:
        var canonical_name := canonical(cat_or_id)
        if DISPLAY_NAMES.has(canonical_name):
                return String(DISPLAY_NAMES[canonical_name])
        return canonical_name

func normalize_from_tile_id(tile_id: String) -> String:
        var normalized := _normalize_input(tile_id)
        if normalized.is_empty():
                return tile_id
        _ensure_tile_cache()
        if _tile_category_cache.has(normalized):
                var legacy_category := String(_tile_category_cache[normalized])
                if legacy_category.is_empty():
                        return normalized
                return canonical(legacy_category)
        return tile_id

func canonical_categories() -> Array[String]:
        return CANONICAL_ORDER.duplicate()

func _ensure_tile_cache() -> void:
        if not _tile_category_cache.is_empty():
                return
        var tiles: Array = DataLite.load_json_array("res://data/tiles.json")
        for entry in tiles:
                if not (entry is Dictionary):
                        continue
                var tile: Dictionary = entry
                var id: String = String(tile.get("id", ""))
                var category: String = String(tile.get("category", ""))
                if id.is_empty() or category.is_empty():
                        continue
                _tile_category_cache[id] = category

func _normalize_input(value: String) -> String:
        return String(value).strip_edges()
