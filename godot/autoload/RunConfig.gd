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

var totem_id := ""
var map_id: String = "map.demo_001"
var difficulty: String = "normal"
var world_seed: int = 12345
var core_tiles: Array[String] = []
var spawn_sprout_ids: Array[String] = []
var last_pick_id: String = ""


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

func set_totem(id: String) -> void:
        var sanitized := String(id)
        totem_id = sanitized
        emit_signal("selections_changed")
        if not sanitized.is_empty() and Engine.has_singleton("TileGen"):
                TileGen.set_totem(sanitized)

func set_map(id: String) -> void:
        map_id = String(id)

func set_difficulty(d: String) -> void:
        difficulty = String(d)

func set_seed(n: int) -> void:
        world_seed = int(n)

func set_spawn_sprouts(ids: Array) -> void:
        var sanitized: Array[String] = []
        for entry in ids:
                if typeof(entry) == TYPE_STRING:
                        var sid := String(entry)
                        if sid.is_empty():
                                continue
                        sanitized.append(sid)
        spawn_sprout_ids = sanitized
        emit_signal("selections_changed")

func clear_draft_selections() -> void:
        _reset_selection_tables()
        emit_signal("selections_changed")

func clear_for_new_run() -> void:
        _reset_selection_tables()
        core_tiles.clear()
        spawn_sprout_ids.clear()
        totem_id = ""
        last_pick_id = ""
        emit_signal("selections_changed")

func _reset_selection_tables() -> void:
        for canonical_key in CANONICAL_KEYS:
                selected_variants[canonical_key] = ""
                var legacy_key := _legacy_for(canonical_key)
                selected_variants[legacy_key] = ""
        selected_variants["chanting"] = ""

func mark_ready() -> void:
        emit_signal("run_ready")

func add_core_tile(id: String) -> void:
        var tid := String(id)
        if tid.is_empty():
                return
        if not core_tiles.has(tid):
                core_tiles.append(tid)
        emit_signal("selections_changed")

func remove_core_tile(id: String) -> void:
        var tid := String(id)
        if tid.is_empty():
                return
        if core_tiles.has(tid):
                core_tiles.erase(tid)
        emit_signal("selections_changed")

func set_core_tiles(ids: Array) -> void:
        var sanitized: Array[String] = []
        for entry in ids:
                if typeof(entry) != TYPE_STRING:
                        continue
                var tid := String(entry)
                if tid.is_empty():
                        continue
                if sanitized.has(tid):
                        continue
                sanitized.append(tid)
        core_tiles = sanitized
        emit_signal("selections_changed")

func has_core_tile(id: String) -> bool:
        var tid := String(id)
        if tid.is_empty():
                return false
        return core_tiles.has(tid)

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
