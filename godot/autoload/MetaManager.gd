extends Node

signal library_changed()

const LIB_PATH := "user://sprout_library.json"

var _library := {
		"unlocked": []
}

func _normalize_id(value: String) -> String:
		return String(value).strip_edges()

func _ready() -> void:
		_load()

func _load() -> void:
		if FileAccess.file_exists(LIB_PATH):
				var file := FileAccess.open(LIB_PATH, FileAccess.READ)
				if file != null:
						var text := file.get_as_text()
						var data := JSON.parse_string(text)
						if typeof(data) == TYPE_DICTIONARY and data.has("unlocked"):
								_library = data
								return
		_library = {"unlocked": ["sprout.grumbler", "sprout.sprite"]}
		_save()

func _save() -> void:
		var file := FileAccess.open(LIB_PATH, FileAccess.WRITE)
		if file == null:
				return
		file.store_string(JSON.stringify(_library))
		file.flush()

func is_unlocked_sprout(id: String) -> bool:
		var arr_variant := _library.get("unlocked", [])
		if arr_variant is Array:
				return (arr_variant as Array).has(id)
		if arr_variant is PackedStringArray:
				return Array(arr_variant).has(id)
		return false

func unlock_sprout(id: String) -> void:
		var sid := _normalize_id(id)
		if sid.is_empty():
				return
		if not is_unlocked_sprout(sid):
				_append_unlock(sid)
				_save()
				emit_signal("library_changed")
				var root := get_tree().root
				var hud := root.get_node_or_null("HUD") if root != null else null
				var display_name := sid
				if Engine.has_singleton("SproutRegistry"):
						var def := SproutRegistry.get_by_id(sid)
						if def.has("name"):
								display_name = String(def.get("name"))
				if hud == null and root != null:
						hud = root.get_node_or_null("Main/World/HUD")
				if hud != null and hud.has_method("_show_toast"):
						hud.call_deferred("_show_toast", "Unlocked: %s" % display_name)

func lock_sprout(id: String) -> void:
		var sid := _normalize_id(id)
		if sid.is_empty():
				return
		var list := _library.get("unlocked", [])
		var modified := false
		if list is Array:
				if (list as Array).has(sid):
						(list as Array).erase(sid)
						modified = true
		elif list is PackedStringArray:
				var arr := Array(list)
				if arr.has(sid):
						arr.erase(sid)
						_library["unlocked"] = arr
						modified = true
		if modified:
				_save()
				emit_signal("library_changed")

func list_unlocked() -> Array[String]:
		var list := _library.get("unlocked", [])
		if list is Array:
				return (list as Array).duplicate()
		if list is PackedStringArray:
				return Array(list)
		return []

func wipe_library() -> void:
		_library = {"unlocked": []}
		_save()
		emit_signal("library_changed")

func debug_unlock_all() -> void:
		var entries := DataLite.load_json_array("res://data/sprouts.json")
		var all_ids: Array[String] = []
		for entry in entries:
				if entry is Dictionary:
						var sid := String((entry as Dictionary).get("id", ""))
						if not sid.is_empty():
								all_ids.append(sid)
		_library = {"unlocked": all_ids}
		_save()
		emit_signal("library_changed")
		_debug_print("Unlocked all sprouts (%d)" % all_ids.size())

func debug_list_unlocked() -> void:
		var current := list_unlocked()
		var summary := "(none)"
		if not current.is_empty():
				summary = ", ".join(current)
		_debug_print("Unlocked sprouts: %s" % summary)

func debug_unlock_sprout(id: String) -> void:
		var sid := _normalize_id(id)
		if sid.is_empty():
				_debug_print("Unlock sprout skipped — empty id")
				return
		var was_unlocked := is_unlocked_sprout(sid)
		unlock_sprout(sid)
		if was_unlocked:
				_debug_print("Sprout already unlocked: %s" % sid)
		else:
				_debug_print("Unlocked sprout: %s" % sid)

func debug_lock_sprout(id: String) -> void:
		var sid := _normalize_id(id)
		if sid.is_empty():
				_debug_print("Lock sprout skipped — empty id")
				return
		var was_unlocked := is_unlocked_sprout(sid)
		lock_sprout(sid)
		if was_unlocked:
				_debug_print("Locked sprout: %s" % sid)
		else:
				_debug_print("Sprout already locked: %s" % sid)

func debug_wipe_library() -> void:
		wipe_library()
		_debug_print("Sprout library wiped")

func _append_unlock(id: String) -> void:
		var list := _library.get("unlocked", [])
		if list is PackedStringArray:
				list = Array(list)
		if not (list is Array):
				list = []
		if not list.has(id):
				list.append(id)
		_library["unlocked"] = list

func _debug_print(message: String) -> void:
		print("[MetaManager] %s" % message)
