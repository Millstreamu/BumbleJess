extends Node

var _cache: Dictionary = {}

func load_json_array(p: String) -> Array:
	if _cache.has(p):
		return _cache[p]
	var f: FileAccess = FileAccess.open(p, FileAccess.READ)
	if f == null:
		return []
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	if typeof(parsed) == TYPE_ARRAY:
		_cache[p] = parsed
		return parsed
	return []

func load_json_dict(p: String) -> Dictionary:
	if _cache.has(p):
		return _cache[p]
	var f: FileAccess = FileAccess.open(p, FileAccess.READ)
	if f == null:
		return {}
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	if typeof(parsed) == TYPE_DICTIONARY:
		_cache[p] = parsed
		return parsed
	return {}
