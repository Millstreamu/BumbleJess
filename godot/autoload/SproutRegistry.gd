extends Node

signal roster_changed()
signal sprout_leveled(sprout_uid: String, new_level: int)
signal error_msg(text: String)

const MAX_SELECTION := 6
const TEMPLATE_PATH := "res://data/sprouts_roster.json"
const SAVE_PATH := "user://sprouts_roster.json"

var _db_by_id: Dictionary = {}
var _roster: Array[Dictionary] = []
var _uid_counter: int = 1
var _last_selection: Array[Dictionary] = []
var _rng := RandomNumberGenerator.new()

func _ensure_db_loaded() -> void:
		if _db_by_id.is_empty():
				_load_db()

func _ready() -> void:
		_load_db()
		_load_persisted_roster()
		_rng.randomize()

func refresh_for_new_game(map_id: String = "") -> void:
		if _db_by_id.is_empty():
				_load_db()
		var seed_entries: Array[Dictionary] = _load_seed_entries(map_id)
		if seed_entries.is_empty():
				seed_entries = _load_seed_entries("")
		_apply_roster_seed(seed_entries)

func _load_seed_entries(map_id: String) -> Array[Dictionary]:
		var paths: Array[String] = []
		if not map_id.is_empty():
				paths.append("res://sprouts/seeds/%s.json" % map_id)
				paths.append("res://sprouts/seeds/%s_seed.json" % map_id)
				var sanitized_map_id := map_id.replace("map.", "")
				if sanitized_map_id != map_id:
						paths.append("res://sprouts/seeds/%s.json" % sanitized_map_id)
						paths.append("res://sprouts/seeds/%s_seed.json" % sanitized_map_id)
		paths.append(TEMPLATE_PATH)
		for path in paths:
				if not FileAccess.file_exists(path):
						continue
				var arr: Array = DataLite.load_json_array(path)
				var result: Array[Dictionary] = []
				for entry_variant in arr:
						if entry_variant is Dictionary:
								result.append(entry_variant)
				if not result.is_empty():
						return result
		return []

func _apply_roster_seed(entries: Array[Dictionary]) -> void:
		_roster.clear()
		_last_selection.clear()
		_uid_counter = 1
		for entry in entries:
				var entry_dict := entry.duplicate(true)
				entry_dict.erase("uid")
				var sanitized := _sanitize_roster_entry(entry_dict)
				_roster.append(sanitized)
		_save_persisted_roster()
		emit_signal("roster_changed")

func _load_db() -> void:
		_db_by_id.clear()
		var entries: Array = DataLite.load_json_array("res://data/sprouts.json")
		for entry_variant in entries:
				if entry_variant is Dictionary:
						var entry: Dictionary = entry_variant
						var sid: String = String(entry.get("id", ""))
						if sid.is_empty():
								continue
						_db_by_id[sid] = entry.duplicate(true)

func _load_persisted_roster() -> void:
		_roster.clear()
		_uid_counter = 1
		if not FileAccess.file_exists(SAVE_PATH):
				return
		var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
		if file == null:
				return
		var parsed: Variant = JSON.parse_string(file.get_as_text())
		if typeof(parsed) != TYPE_ARRAY:
				return
		for entry_variant in parsed:
				if entry_variant is Dictionary:
						var entry: Dictionary = _sanitize_roster_entry(entry_variant)
						_roster.append(entry)
						var uid_str: String = String(entry.get("uid", "1"))
						if uid_str.begins_with("S"):
								uid_str = uid_str.substr(1, uid_str.length() - 1)
						var uid_num: int = uid_str.to_int()
						_uid_counter = max(_uid_counter, uid_num + 1)

func _save_persisted_roster() -> void:
		var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
		if file == null:
				return
		file.store_string(JSON.stringify(_roster, "\t"))

func get_roster() -> Array:
		var result: Array = []
		for entry in _roster:
				result.append(entry.duplicate(true))
		return result

func get_entry_by_uid(uid: String) -> Dictionary:
		var idx := _find_roster_index(uid)
		if idx == -1:
				return {}
		return _roster[idx].duplicate(true)

func get_by_id(id: String) -> Dictionary:
		_ensure_db_loaded()
		if not _db_by_id.has(id):
				return {}
		var def_variant: Variant = _db_by_id[id]
		if def_variant is Dictionary:
				return Dictionary(def_variant).duplicate(true)
		return {}

func add_to_roster(id: String, level: int = 1, nickname: String = "") -> Dictionary:
		_ensure_db_loaded()
		if not _db_by_id.has(id):
				emit_signal("error_msg", "Unknown sprout id: " + id)
				return {}
		var entry: Dictionary = {
				"uid": _new_uid(),
				"id": id,
				"level": clamp(level, 1, get_level_cap(id)),
				"nickname": nickname,
				"meta": {},
		}
		_roster.append(entry)
		_sync_last_selection_with_roster()
		_save_persisted_roster()
		emit_signal("roster_changed")
		return entry.duplicate(true)

func remove_from_roster(uid: String) -> bool:
		var idx := _find_roster_index(uid)
		if idx == -1:
				return false
		_roster.remove_at(idx)
		_sync_last_selection_with_roster()
		_save_persisted_roster()
		emit_signal("roster_changed")
		return true

func set_last_selection(sel: Array) -> void:
		_last_selection = _sanitize_selection(sel)

func get_last_selection() -> Array:
		var result: Array = []
		for entry in _last_selection:
				result.append(entry.duplicate(true))
		return result

func pick_for_battle(n: int) -> Array:
		if _last_selection.size() > 0:
				var count: int = min(n, _last_selection.size())
				return _last_selection.slice(0, count)
		var result: Array = []
		var limit: int = min(n, _roster.size())
		for i in range(limit):
				result.append(_roster[i].duplicate(true))
		return result

func compute_stats(id: String, level: int) -> Dictionary:
		_ensure_db_loaded()
		if not _db_by_id.has(id):
				return {}
		var sprout_variant: Variant = _db_by_id[id]
		if not (sprout_variant is Dictionary):
				return {}
		var sprout: Dictionary = sprout_variant
		var base_stats_variant: Variant = sprout.get("base_stats", {})
		var growth_variant: Variant = sprout.get("growth", {})
		var base_stats: Dictionary = base_stats_variant if base_stats_variant is Dictionary else {}
		var growth: Dictionary = growth_variant if growth_variant is Dictionary else {}
		var levels_above_one: int = max(0, level - 1)
		var hp: int = int(base_stats.get("hp", 30)) + levels_above_one * int(growth.get("hp_per_level", 3))
		var atk: int = int(base_stats.get("attack", 6)) + levels_above_one * int(growth.get("attack_per_level", 1))
		var aspeed: float = float(base_stats.get("attack_speed", 1.0)) + float(levels_above_one) * float(growth.get("aspeed_per_level", 0.02))
		return {
				"hp": hp,
				"attack": atk,
				"attack_speed": aspeed,
		}

func get_sprout_name(id: String) -> String:
		_ensure_db_loaded()
		if not _db_by_id.has(id):
				return "Sprout"
		var sprout_variant: Variant = _db_by_id[id]
		if sprout_variant is Dictionary:
				var sprout_dict: Dictionary = sprout_variant
				return String(sprout_dict.get("name", "Sprout"))
		return "Sprout"

func get_attack_id(id: String) -> String:
		_ensure_db_loaded()
		if not _db_by_id.has(id):
				return ""
		var sprout_variant: Variant = _db_by_id[id]
		if sprout_variant is Dictionary:
				var sprout_dict: Dictionary = sprout_variant
				return String(sprout_dict.get("attack_id", ""))
		return ""

func get_passives(id: String) -> Array:
		_ensure_db_loaded()
		if not _db_by_id.has(id):
				return []
		var entry_variant: Variant = _db_by_id[id]
		if entry_variant is Dictionary:
				var entry_dict: Dictionary = entry_variant
				var passives_variant: Variant = entry_dict.get("passive_ids", [])
				if passives_variant is Array:
						return Array(passives_variant)
		return []

func get_level_cap(id: String) -> int:
		_ensure_db_loaded()
		if not _db_by_id.has(id):
				return 99
		var entry_variant: Variant = _db_by_id[id]
		if entry_variant is Dictionary:
				var entry_dict: Dictionary = entry_variant
				return int(entry_dict.get("level_cap", 99))
		return 99

func level_up(uid: String, levels: int = 1) -> bool:
		var idx := _find_roster_index(uid)
		if idx == -1:
				return false
		var entry: Dictionary = _roster[idx]
		var id: String = String(entry.get("id", ""))
		var cap: int = get_level_cap(id)
		var current_level: int = int(entry.get("level", 1))
		if current_level >= cap:
				emit_signal("error_msg", "Already at level cap.")
				return false
		levels = max(1, levels)
		var target_level: int = min(current_level + levels, cap)
		var delta: int = target_level - current_level
		if delta <= 0:
				return false
		var seeds_needed: int = delta
		var resource_manager: Node = get_node_or_null("/root/ResourceManager")
		if resource_manager == null:
				emit_signal("error_msg", "ResourceManager missing.")
				return false
		if int(resource_manager.get("soul_seeds")) < seeds_needed:
				emit_signal("error_msg", "Not enough Soul Seeds.")
				return false
		if resource_manager.has_method("add_soul_seed"):
				resource_manager.call("add_soul_seed", -seeds_needed)
		else:
				emit_signal("error_msg", "Cannot spend Soul Seeds.")
				return false
		entry["level"] = target_level
		_roster[idx] = entry
		_sync_last_selection_with_roster()
		_save_persisted_roster()
		emit_signal("sprout_leveled", String(entry.get("uid", "")), target_level)
		emit_signal("roster_changed")
		return true

func short_stats_label(id: String, level: int) -> String:
		var stats := compute_stats(id, level)
		return "Lv%d • HP %d • ATK %d • AS %.2f" % [
				level,
				int(stats.get("hp", 0)),
				int(stats.get("attack", 0)),
				float(stats.get("attack_speed", 0.0)),
		]

func on_grove_spawned(_cell: Vector2i) -> void:
		if _db_by_id.is_empty():
				return
		var ids: Array = _db_by_id.keys()
		if ids.is_empty():
				return
		var chosen_index: int = _rng.randi_range(0, ids.size() - 1)
		var chosen_id: String = String(ids[chosen_index])
		add_to_roster(chosen_id, 1)

func _find_roster_index(uid: String) -> int:
		for i in range(_roster.size()):
				if String(_roster[i].get("uid", "")) == uid:
						return i
		return -1

func _new_uid() -> String:
		var uid := "S%04d" % _uid_counter
		_uid_counter += 1
		return uid

func _sanitize_selection(sel: Array) -> Array[Dictionary]:
		var result: Array[Dictionary] = []
		var limit: int = min(sel.size(), MAX_SELECTION)
		var seen: Dictionary = {}
		for i in range(limit):
				var entry_variant: Variant = sel[i]
				if entry_variant is Dictionary:
						var entry: Dictionary = entry_variant
						var uid := String(entry.get("uid", ""))
						if not uid.is_empty():
								if seen.has(uid):
										continue
								var roster_entry := get_entry_by_uid(uid)
								if not roster_entry.is_empty():
										seen[uid] = true
										result.append(roster_entry)
										continue
								seen[uid] = true
						result.append(_sanitize_roster_entry(entry))
		return result

func _sync_last_selection_with_roster() -> void:
		var synced: Array[Dictionary] = []
		for entry_variant in _last_selection:
				if entry_variant is Dictionary:
						var entry: Dictionary = entry_variant
						var uid := String(entry.get("uid", ""))
						if uid.is_empty():
								continue
						var roster_entry := get_entry_by_uid(uid)
						if roster_entry.is_empty():
								continue
						synced.append(roster_entry)
		_last_selection = synced

func _sanitize_roster_entry(entry: Dictionary) -> Dictionary:
		_ensure_db_loaded()
		var id: String = String(entry.get("id", "sprout.woodling"))
		if not _db_by_id.has(id):
				return {
						"uid": entry.get("uid", _new_uid()),
						"id": "sprout.woodling",
						"level": 1,
						"nickname": String(entry.get("nickname", "")),
						"meta": entry.get("meta", {}),
				}
		var level: int = clamp(int(entry.get("level", 1)), 1, get_level_cap(id))
		var nickname: String = String(entry.get("nickname", ""))
		var uid_value: String = String(entry.get("uid", ""))
		if uid_value.is_empty():
				uid_value = _new_uid()
		var meta_variant: Variant = entry.get("meta", {})
		var meta: Dictionary = meta_variant if meta_variant is Dictionary else {}
		return {
				"uid": uid_value,
				"id": id,
				"level": level,
				"nickname": nickname,
				"meta": meta,
		}
