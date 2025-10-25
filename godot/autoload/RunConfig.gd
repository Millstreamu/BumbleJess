extends Node

signal selections_changed()
signal run_ready()

var selected_variants := {
        "harvest": "",
        "build": "",
        "refine": "",
        "storage": "",
        "guard": "",
        "upgrade": "",
        "chanting": ""
}

var totem_id := "totem.heartwood"
var map_id := "map.demo_001"

func set_selection(cat: String, tile_id: String) -> void:
        selected_variants[cat] = tile_id
        emit_signal("selections_changed")

func get_selection(cat: String) -> String:
        return String(selected_variants.get(cat, ""))

func all_categories_selected() -> bool:
        for cat in selected_variants.keys():
                if String(selected_variants[cat]).is_empty():
                        return false
        return true

func clear_for_new_run() -> void:
        for cat in selected_variants.keys():
                selected_variants[cat] = ""
        emit_signal("selections_changed")

func mark_ready() -> void:
        emit_signal("run_ready")
