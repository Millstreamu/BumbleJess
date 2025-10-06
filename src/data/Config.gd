extends Node
class_name Config

var _tiles := {}
var _deck := {}
var _totems := {}
var _sprouts := {}
var _decay := {}

func load_all() -> void:
    _tiles = _load_json("res://data/tiles.json")
    _deck = _load_json("res://data/deck.json")
    _totems = _load_json("res://data/totems.json")
    _sprouts = _load_json("res://data/sprouts.json")
    _decay = _load_json("res://data/decay.json")
    if not _validate_tiles(_tiles):
        _tiles = {}
    if not _validate_deck(_deck):
        _deck = {}

func tiles() -> Dictionary:
    return _tiles

func deck() -> Dictionary:
    return _deck

func totems() -> Dictionary:
    return _totems

func sprouts() -> Dictionary:
    return _sprouts

func decay() -> Dictionary:
    return _decay

func get_variant(category:String, id:String) -> Dictionary:
    if not _tiles.has("variants"):
        return {}
    var variants := _tiles["variants"]
    if typeof(variants) != TYPE_DICTIONARY:
        return {}
    if not variants.has(category):
        return {}
    for v in variants[category]:
        if typeof(v) == TYPE_DICTIONARY and v.get("id", "") == id:
            return v
    return {}

func _load_json(path:String) -> Dictionary:
    if not FileAccess.file_exists(path):
        push_error("Missing JSON: %s" % path)
        return {}
    var f := FileAccess.open(path, FileAccess.READ)
    if f == null:
        push_error("Unable to open JSON: %s" % path)
        return {}
    var text := f.get_as_text()
    var data = JSON.parse_string(text)
    if typeof(data) != TYPE_DICTIONARY:
        push_error("Invalid JSON: %s" % path)
        return {}
    return data

func _validate_tiles(t:Dictionary) -> bool:
    if t.is_empty():
        _fatal_config("tiles.json missing or empty")
        return false
    if not t.has("categories") or not t.has("variants"):
        _fatal_config("tiles.json missing keys")
        return false
    var categories = t["categories"]
    if typeof(categories) != TYPE_ARRAY:
        _fatal_config("tiles.json categories must be an array")
        return false
    for c in categories:
        if typeof(c) != TYPE_STRING:
            _fatal_config("tiles.json categories must be strings")
            return false
    var variants = t["variants"]
    if typeof(variants) != TYPE_DICTIONARY:
        _fatal_config("tiles.json variants must be a dictionary")
        return false
    for category in categories:
        if not variants.has(category):
            _fatal_config("tiles.json missing variants for %s" % category)
            return false
        var entries = variants[category]
        if typeof(entries) != TYPE_ARRAY:
            _fatal_config("tiles.json variants for %s must be an array" % category)
            return false
        for entry in entries:
            if typeof(entry) != TYPE_DICTIONARY:
                _fatal_config("tiles.json variant entries must be dictionaries")
                return false
            var vid = entry.get("id", "")
            if typeof(vid) != TYPE_STRING or vid.is_empty():
                _fatal_config("tiles.json variant id missing for %s" % category)
                return false
            if not entry.has("effects") or typeof(entry["effects"]) != TYPE_DICTIONARY:
                _fatal_config("tiles.json variant %s missing effects" % vid)
                return false
    return true

func _validate_deck(d:Dictionary) -> bool:
    if d.is_empty():
        _fatal_config("deck.json missing or empty")
        return false
    if not d.has("distribution"):
        _fatal_config("deck.json missing distribution")
        return false
    var distribution = d["distribution"]
    if typeof(distribution) != TYPE_DICTIONARY:
        _fatal_config("deck.json distribution must be a dictionary")
        return false
    for k in distribution.keys():
        if typeof(distribution[k]) != TYPE_INT:
            _fatal_config("deck.json distribution values must be int")
            return false
    return true

func _fatal_config(msg:String) -> void:
    push_error(msg)
    var tree := get_tree()
    if tree == null:
        return
    var error_scene := "res://scenes/ui/ErrorPanel.tscn"
    if ResourceLoader.exists(error_scene):
        tree.change_scene_to_file(error_scene)
        return
    var main_scene := ProjectSettings.get_setting("application/run/main_scene", "")
    if typeof(main_scene) == TYPE_STRING and main_scene != "":
        tree.change_scene_to_file(main_scene)
