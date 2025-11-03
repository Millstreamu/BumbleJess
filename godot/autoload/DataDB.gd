## Provides tile data access and effect schema sanitization.
extends Node

const EFFECT_WHEN := [
	"start_of_turn",
	"end_of_turn",
	"on_place",
	"on_transform",
	"on_adjacency_change",
]
const TARGET_SCOPES := [
	"self",
	"adjacent",
	"radius",
	"global",
]
const EFFECT_OPS := [
	"add",
	"mul",
	"set",
	"convert",
	"spawn",
	"transform",
	"cleanse_decay",
	"damage_decay",
	"aura_sprout",
]
const STACKING_MODES := [
	"sum",
	"max",
	"min",
]
const CONDITION_ADJ_OPS := {">=": true, "<=": true, "==": true, "!=": true, ">": true, "<": true}

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

func iter_tiles() -> Array:
	_ensure_loaded()
	return _tiles.duplicate(true)

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
	_tiles = []
	_id_to_def.clear()
	id_to_tags.clear()
	id_to_category.clear()

	var raw_tiles: Array = DataLite.load_json_array("res://data/tiles.json")
	for entry_variant in raw_tiles:
		if not (entry_variant is Dictionary):
			continue
		var entry: Dictionary = entry_variant
		var tile_id := String(entry.get("id", ""))
		if tile_id.is_empty():
			continue

		var sanitized: Dictionary = _sanitize_tile(entry)  # <-- explicit type
		_tiles.append(sanitized)
		_id_to_def[tile_id] = sanitized.duplicate(true)
		id_to_tags[tile_id] = _normalize_tags(sanitized.get("tags", []))
		id_to_category[tile_id] = _canonicalize_category(String(sanitized.get("category", "")))

func _sanitize_tile(source: Dictionary) -> Dictionary:
	var sanitized: Dictionary = source.duplicate(true)  # <-- explicit type

	var effects_variant: Variant = sanitized.get("effects", [])
	var effects_array: Array = []
	if effects_variant is Array:
		effects_array = effects_variant

	var tile_id := String(sanitized.get("id", ""))
	var sanitized_effects: Array = []

	for effect_variant in effects_array:
		if not (effect_variant is Dictionary):
			_warn(tile_id, "effect entry is not a dictionary; skipping")
			continue
		var effect_dict: Dictionary = effect_variant
		var sanitized_effect: Dictionary = _sanitize_effect(tile_id, sanitized_effects.size(), effect_dict)  # <-- explicit
		if sanitized_effect.is_empty():
			continue
		sanitized_effects.append(sanitized_effect)

	sanitized["effects"] = sanitized_effects
	return sanitized


func _sanitize_effect(tile_id: String, index: int, effect: Dictionary) -> Dictionary:
	var when := String(effect.get("when", "start_of_turn"))
	if not EFFECT_WHEN.has(when):
		_warn(tile_id, "effect %d has invalid 'when' value '%s'; defaulting to start_of_turn" % [index, when])
		when = "start_of_turn"

	var interval: int = max(1, int(effect.get("interval_turns", 1)))

	var duration_variant: Variant = effect.get("duration_turns", null)
	var duration: Variant = null
	if duration_variant is int or duration_variant is float:
		var duration_int := int(duration_variant)
		if duration_int > 0:
			duration = duration_int
	elif duration_variant == null:
		duration = null
	else:
		_warn(tile_id, "effect %d has invalid duration; ignoring" % index)

	var target: Dictionary = _sanitize_target(tile_id, index, effect.get("target", {}))         # <-- explicit
	var condition: Dictionary = _sanitize_condition(tile_id, index, effect.get("condition", {})) # <-- explicit

	var op := String(effect.get("op", "add"))
	if not EFFECT_OPS.has(op):
		_warn(tile_id, "effect %d has unsupported op '%s'; skipping" % [index, op])
		return {}

	var stacking := String(effect.get("stacking", "sum"))
	if not STACKING_MODES.has(stacking):
		_warn(tile_id, "effect %d has invalid stacking '%s'; defaulting to sum" % [index, stacking])
		stacking = "sum"

	var sanitized: Dictionary = {
		"when": when,
		"interval_turns": interval,
		"duration_turns": duration,
		"target": target,
		"condition": condition,
		"op": op,
		"stacking": stacking,
	}

	match op:
		"add", "mul", "set":
			var stat_path := String(effect.get("stat", ""))
			if stat_path.is_empty():
				_warn(tile_id, "effect %d missing stat path; skipping" % index)
				return {}
			sanitized["stat"] = stat_path
			sanitized["amount"] = _coerce_number(effect.get("amount", 0))  # <-- avoid Variant temp

		"convert":
			sanitized["amount"] = _sanitize_convert(tile_id, index, effect.get("amount", {}))

		"spawn":
			sanitized["amount"] = _sanitize_spawn(tile_id, index, effect.get("amount", {}))

		"transform":
			sanitized["amount"] = _sanitize_transform(tile_id, index, effect.get("amount", {}))

		"cleanse_decay":
			sanitized["amount"] = _sanitize_decay_amount(tile_id, index, effect.get("amount", {}))

		"damage_decay":
			sanitized["amount"] = _sanitize_damage_amount(tile_id, index, effect.get("amount", {}))

		"aura_sprout":
			sanitized["amount"] = _sanitize_aura_amount(tile_id, index, effect.get("amount", {}))

	return sanitized

func _sanitize_target(tile_id: String, index: int, target_variant: Variant) -> Dictionary:
	var target: Dictionary = target_variant if target_variant is Dictionary else {}
	var scope := String(target.get("scope", "self"))
	if not TARGET_SCOPES.has(scope):
		_warn(tile_id, "effect %d target scope '%s' invalid; defaulting to self" % [index, scope])
		scope = "self"
	var radius := 0
	if scope == "radius":
		radius = max(1, int(target.get("radius", 1)))
	var has_tags_any := _string_array(target.get("has_tags_any", []))
	var has_tags_all := _string_array(target.get("has_tags_all", []))
	var category_any := _string_array(target.get("category_any", []))
	return {
		"scope": scope,
		"radius": radius,
		"has_tags_any": has_tags_any,
		"has_tags_all": has_tags_all,
		"category_any": category_any,
		"include_overgrowth": bool(target.get("include_overgrowth", false)),
		"include_grove": bool(target.get("include_grove", false)),
	}

func _sanitize_condition(tile_id: String, index: int, cond_variant: Variant) -> Dictionary:
	var cond: Dictionary = cond_variant if cond_variant is Dictionary else {}
	var result: Dictionary = {}
	if cond.has("adjacent_count"):
		var adj_variant: Variant = cond.get("adjacent_count")
		if adj_variant is Dictionary:
			var tag := String(adj_variant.get("tag", ""))
			var op := String(adj_variant.get("op", ">="))
			if not CONDITION_ADJ_OPS.has(op):
				_warn(tile_id, "effect %d has invalid adjacent_count op '%s'" % [index, op])
			else:
				var value_num := _coerce_number(adj_variant.get("value", 0))
				result["adjacent_count"] = {
					"tag": tag,
					"op": op,
					"value": int(value_num),
				}
	if cond.has("touching_decay"):
		result["touching_decay"] = bool(cond.get("touching_decay", false))
	if cond.has("turn_mod"):
		var tm_variant: Variant = cond.get("turn_mod")
		if tm_variant is Dictionary:
			var mod_value: int = max(1, int(tm_variant.get("mod", 1)))
			var eq_value := int(tm_variant.get("eq", 0))
			result["turn_mod"] = {
				"mod": mod_value,
				"eq": eq_value,
			}
	return result

func _sanitize_convert(tile_id: String, index: int, amount_variant: Variant) -> Dictionary:
	var amount: Dictionary = amount_variant if amount_variant is Dictionary else {}
	var from_variant: Variant = amount.get("from", {})
	var to_variant: Variant = amount.get("to", {})
	var from_dict: Dictionary = {}
	var to_dict: Dictionary = {}
	if from_variant is Dictionary:
		for key in from_variant.keys():
			from_dict[String(key)] = _coerce_number(from_variant[key])
	if to_variant is Dictionary:
		for key in to_variant.keys():
			to_dict[String(key)] = _coerce_number(to_variant[key])
	return {
		"from": from_dict,
		"to": to_dict,
		"period": max(1, int(amount.get("period", 1))),
	}

func _sanitize_spawn(tile_id: String, index: int, amount_variant: Variant) -> Dictionary:
	var amount: Dictionary = amount_variant if amount_variant is Dictionary else {}
	return {
		"tile_id": String(amount.get("tile_id", "")),
		"count": max(1, int(amount.get("count", 1))),
		"empty_only": bool(amount.get("empty_only", false)),
	}

func _sanitize_transform(tile_id: String, index: int, amount_variant: Variant) -> Dictionary:
	var amount: Dictionary = amount_variant if amount_variant is Dictionary else {}
	return {
		"to": String(amount.get("to", "")),
	}

func _sanitize_decay_amount(tile_id: String, index: int, amount_variant: Variant) -> Dictionary:
	var amount: Dictionary = amount_variant if amount_variant is Dictionary else {}
	return {
		"radius": max(0, int(amount.get("radius", 0))),
		"max_tiles": max(0, int(amount.get("max_tiles", 0))),
	}

func _sanitize_damage_amount(tile_id: String, index: int, amount_variant: Variant) -> Dictionary:
	var amount: Dictionary = amount_variant if amount_variant is Dictionary else {}
	return {
		"radius": max(0, int(amount.get("radius", 0))),
		"amount": _coerce_number(amount.get("amount", 0)),
	}

func _sanitize_aura_amount(tile_id: String, index: int, amount_variant: Variant) -> Dictionary:
	var amount: Dictionary = amount_variant if amount_variant is Dictionary else {}
	return {
		"stat": String(amount.get("stat", "")),
		"op": String(amount.get("op", "add")),
		"amount": _coerce_number(amount.get("amount", 0)),
	}

func _normalize_tags(source: Variant) -> Array:
	var result: Array = []
	var tags_source: Variant = source
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

func _string_array(source: Variant) -> Array:
	var result: Array = []
	if source is Array:
		for entry in source:
			var value := String(entry).strip_edges()
			if value.is_empty():
				continue
			result.append(value)
	elif source is PackedStringArray:
		for entry in Array(source):
			var value := String(entry).strip_edges()
			if value.is_empty():
				continue
			result.append(value)
	elif typeof(source) == TYPE_STRING:
		var value := String(source).strip_edges()
		if not value.is_empty():
			result.append(value)
	return result

func _coerce_number(value: Variant) -> float:
	if value is int:
		return float(value)
	if value is float:
		return value
	return 0.0

func _warn(tile_id: String, message: String) -> void:
	var context := tile_id if not tile_id.is_empty() else "tiles.json"
	push_warning("%s: %s" % [context, message])
