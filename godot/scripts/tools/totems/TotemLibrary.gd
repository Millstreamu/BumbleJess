@tool
extends Resource
class_name TotemLibrary

@export_file("*.json") var tile_pack_output_path: String = "res://data/packs.json"
@export_file("*.json") var totem_output_path: String = "res://data/totems.json"
@export var tile_packs: Array[TilePackDefinition] = []
@export var totems: Array[TotemDefinition] = []

var _regenerate_json := false
@export var regenerate_json := false:
    set(value):
        _set_regenerate_json(value)
    get:
        return _regenerate_json

func _set_regenerate_json(value: bool) -> void:
    if Engine.is_editor_hint() and value:
        save_json_files()
    _regenerate_json = false

func save_json_files() -> void:
    _save_json_files()

func _save_json_files() -> void:
    var pack_dicts: Array = []
    var seen_ids: Dictionary = {}
    for pack in tile_packs:
        if pack == null or not pack.is_valid():
            continue
        if seen_ids.has(pack.id):
            push_warning("Duplicate tile pack id detected: %s" % pack.id)
            continue
        seen_ids[pack.id] = true
        pack_dicts.append(pack.to_dict())
    pack_dicts.sort_custom(Callable(self, "_sort_by_id"))
    _write_json(tile_pack_output_path, pack_dicts)

    var totem_dicts: Array = []
    seen_ids.clear()
    for totem in totems:
        if totem == null or not totem.is_valid():
            continue
        if seen_ids.has(totem.id):
            push_warning("Duplicate totem id detected: %s" % totem.id)
            continue
        seen_ids[totem.id] = true
        totem_dicts.append(totem.to_dict())
    totem_dicts.sort_custom(Callable(self, "_sort_by_id"))
    _write_json(totem_output_path, totem_dicts)

func _write_json(path: String, data: Variant) -> void:
    if path.is_empty():
        push_warning("No output path configured for json export.")
        return
    var base_dir := path.get_base_dir()
    if base_dir.is_empty():
        base_dir = "."
    var abs_dir := ProjectSettings.globalize_path(base_dir)
    DirAccess.make_dir_recursive_absolute(abs_dir)
    var file := FileAccess.open(path, FileAccess.WRITE)
    if file == null:
        push_error("Unable to open %s for writing" % path)
        return
    var json := JSON.stringify(data, "  ")
    file.store_string(json + "\n")
    file.flush()
    file.close()
    print("TotemLibrary exported json -> %s" % path)

func _sort_by_id(a: Dictionary, b: Dictionary) -> bool:
    return String(a.get("id", "")) < String(b.get("id", ""))
