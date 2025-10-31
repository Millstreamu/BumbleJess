extends Node

signal selections_changed()
signal run_ready()

const CANONICAL_KEYS := [
        "Nature",
        "Earth",
        "Water",
        "Nest",
        "Aggression",
        "Mystic",
]

var selected_variants := {
        "Nature": "",
        "Earth": "",
        "Water": "",
        "Nest": "",
        "Aggression": "",
        "Mystic": "",
        "harvest": "",
        "build": "",
        "refine": "",
        "storage": "",
        "guard": "",
        "upgrade": "",
        "chanting": "",
}

var totem_id := "totem.heartwood"
var map_id := "map.demo_001"


func set_selection(cat: String, tile_id: String) -> void:
        var canonical_key := _resolve_key(cat)
        selected_variants[canonical_key] = tile_id
        var legacy_key := _legacy_for(canonical_key)
        selected_variants[legacy_key] = tile_id
        if canonical_key == "Mystic":
                selected_variants["chanting"] = tile_id
        emit_signal("selections_changed")

func get_selection(cat: String) -> String:
        var canonical_key := _resolve_key(cat)
        var result: String = String(selected_variants.get(canonical_key, ""))
        if result.is_empty():
                var legacy_key := _legacy_for(canonical_key)
                result = String(selected_variants.get(legacy_key, result))
        if result.is_empty() and canonical_key == "Mystic":
                result = String(selected_variants.get("chanting", ""))
        return result

func all_categories_selected() -> bool:
        for canonical_key in CANONICAL_KEYS:
                if String(selected_variants.get(canonical_key, "")).is_empty():
                        return false
        return true

func clear_for_new_run() -> void:
        for canonical_key in CANONICAL_KEYS:
                selected_variants[canonical_key] = ""
                var legacy_key := _legacy_for(canonical_key)
                selected_variants[legacy_key] = ""
        selected_variants["chanting"] = ""
        emit_signal("selections_changed")

func mark_ready() -> void:
        emit_signal("run_ready")

func _resolve_key(cat: String) -> String:
        var canonical_key := CategoryMap.canonical(cat)
        if canonical_key.is_empty():
                return cat
        return canonical_key

func _legacy_for(canonical_key: String) -> String:
        match canonical_key:
                "Nature":
                        return "harvest"
                "Earth":
                        return "build"
                "Water":
                        return "refine"
                "Nest":
                        return "storage"
                "Aggression":
                        return "guard"
                "Mystic":
                        return "upgrade"
                _:
                        return canonical_key
