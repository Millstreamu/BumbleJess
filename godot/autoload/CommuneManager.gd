extends Node

signal offer_ready(choices: Array)
signal chosen(tile_id: String)
signal cleared()

var current_tile_id: String = ""

var _cfg: Dictionary = {}
var _tiles: Array = []
var _id_to_def: Dictionary = {}
var _totems: Array = []
var _last_offer: Array = []
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _history_ids: Array[String] = []
var _category_history: Dictionary = {}
var _tag_history: Dictionary = {}
var _history_limit: int = 12

func _ready() -> void:
		_rng.randomize()
		_cfg = DataLite.load_json_dict("res://data/commune.json")
		_tiles = DataLite.load_json_array("res://data/tiles.json")
		for entry_variant in _tiles:
				if not (entry_variant is Dictionary):
						continue
				var entry: Dictionary = entry_variant
				var id := String(entry.get("id", ""))
				if id.is_empty():
						continue
				_id_to_def[id] = entry
		_totems = DataLite.load_json_array("res://data/totems.json")
		_connect_turn_engine()

func _connect_turn_engine() -> void:
		var turn_node: Node = get_node_or_null("/root/TurnEngine")
		if turn_node == null and Engine.has_singleton("Game"):
				var singleton := Engine.get_singleton("Game")
				if singleton is Node:
						turn_node = singleton
		if turn_node == null:
				turn_node = get_node_or_null("/root/Game")
		if turn_node == null or not turn_node.has_signal("phase_started"):
				return
		if not turn_node.is_connected("phase_started", Callable(self, "_on_phase_started")):
				turn_node.connect("phase_started", Callable(self, "_on_phase_started"))

func _on_phase_started(phase_name: String) -> void:
		if phase_name != "commune":
				return
		_roll_and_emit_offer()

func _roll_and_emit_offer() -> void:
		var count := int(_cfg.get("offer_count", 3))
		var pool := _build_weighted_pool()
		if pool.is_empty():
				return
		pool.shuffle()
		var picks := _sample_unique_by_weight(pool, count)
		_last_offer = picks
		var defs: Array = []
		for pick in picks:
				var tid := String(pick.get("id", ""))
				if tid.is_empty():
						continue
				var def_variant: Variant = _id_to_def.get(tid, {})
				var def: Dictionary = def_variant if def_variant is Dictionary else {}
				defs.append(def)
		if defs.is_empty():
				return
		emit_signal("offer_ready", defs)

func _build_weighted_pool() -> Array:
		var pool: Array = []
		var bias_cfg_variant: Variant = _cfg.get("bias", {})
		var bias_cfg: Dictionary = bias_cfg_variant if bias_cfg_variant is Dictionary else {}
		var mult_t: float = max(float(bias_cfg.get("totem_weight_mult", 1.0)), 0.0)
		var core_w: float = float(bias_cfg.get("core_tile_weight", 3.0))
		var dupe_pen: float = float(bias_cfg.get("recent_dupe_penalty", -2.5))
		var soft_cap: float = float(bias_cfg.get("category_soft_cap", 0.0))
		var unique_chance: float = clamp(float(_cfg.get("unique_chance_base", 0.05)), 0.0, 1.0)

		var tw_cat: Dictionary = {}
		var tw_tag: Dictionary = {}
		var rc: Object = RunConfig if typeof(RunConfig) != TYPE_NIL else null
		if rc != null:
				var tid := String(rc.totem_id)
				var totem := _get_totem(tid)
				var commune_variant: Variant = totem.get("commune_weights", {})
				var commune_weights: Dictionary = commune_variant if commune_variant is Dictionary else {}
				var cats_variant: Variant = commune_weights.get("categories", {})
				tw_cat = cats_variant if cats_variant is Dictionary else {}
				var tags_variant: Variant = commune_weights.get("tags", {})
				tw_tag = tags_variant if tags_variant is Dictionary else {}

		for entry_variant in _tiles:
				if not (entry_variant is Dictionary):
						continue
				var entry: Dictionary = entry_variant
				var id := String(entry.get("id", ""))
				if id.is_empty():
						continue
				var category := CategoryMap.canonical(String(entry.get("category", "")))
				if category.is_empty():
						category = String(entry.get("category", ""))
				if category.is_empty():
						continue
				var base := 1.0
				if mult_t > 0.0:
						var cat_bias := float(tw_cat.get(category, 1.0))
						if cat_bias != 1.0:
								base *= pow(cat_bias, mult_t)
						var tags_array: Array = entry.get("tags", [])
						for tag_variant in tags_array:
								var tag := String(tag_variant)
								if tag.is_empty():
										continue
								var tag_bias := float(tw_tag.get(tag, 1.0))
								if tag_bias != 1.0:
										base *= pow(tag_bias, mult_t)
				if rc != null and rc.has_core_tile(id):
						base += core_w
				if rc != null:
						var any_core_same_cat := false
						if typeof(DataDB) != TYPE_NIL and DataDB.has_method("get_category_for_id"):
								for core_id in rc.core_tiles:
										if typeof(core_id) != TYPE_STRING:
												continue
										var cid := String(core_id)
										if cid.is_empty():
												continue
										var core_cat := CategoryMap.canonical(DataDB.get_category_for_id(cid))
										if core_cat == category:
												any_core_same_cat = true
												break
						if any_core_same_cat:
								base *= 1.10
				if rc != null and rc.last_pick_id == id:
						base = max(0.1, base + dupe_pen)
				var history_total := _history_ids.size()
				if history_total > 0 and soft_cap > 0.0:
						var cat_count := float(_category_history.get(category, 0))
						var cat_share := cat_count / float(history_total)
						if cat_share > soft_cap:
								var over: float = clamp(cat_share - soft_cap, 0.0, 0.9)
								base *= max(0.1, 1.0 - over)
						var tags_array_hist: Array = entry.get("tags", [])
						for tag_variant in tags_array_hist:
								var tag := String(tag_variant)
								if tag.is_empty():
										continue
								var tag_count := float(_tag_history.get(tag, 0))
								var tag_share := tag_count / float(history_total)
								if tag_share > soft_cap:
										var tag_over: float = clamp(tag_share - soft_cap, 0.0, 0.9)
										base *= max(0.1, 1.0 - tag_over)
				if entry.get("unique", false):
						if unique_chance < 1.0 and unique_chance > 0.0:
								if _rng.randf() > unique_chance:
										base *= max(unique_chance, 0.05)
								else:
										base *= max(1.0, 1.0 / max(unique_chance, 0.05))
						elif unique_chance <= 0.0:
								base *= 0.1
				base = max(0.01, base)
				pool.append({
						"id": id,
						"w": base,
						"category": category,
				})
		if soft_cap > 0.0:
				var total_weight := 0.0
				var weight_by_cat: Dictionary = {}
				for item in pool:
						var weight := float(item.get("w", 0.0))
						total_weight += weight
						var cat := String(item.get("category", ""))
						weight_by_cat[cat] = float(weight_by_cat.get(cat, 0.0)) + weight
				if total_weight > 0.0:
						for cat_key in weight_by_cat.keys():
								var cat_weight := float(weight_by_cat[cat_key])
								var share := cat_weight / total_weight
								if share <= soft_cap:
										continue
								var scale := soft_cap / share
								for entry in pool:
										if String(entry.get("category", "")) != String(cat_key):
												continue
										entry["w"] = max(0.01, float(entry.get("w", 0.0)) * scale)
		return pool

func _sample_unique_by_weight(pool: Array, k: int) -> Array:
		var picks: Array = []
		var bag: Array = []
		for entry in pool:
				if entry is Dictionary:
						bag.append(entry.duplicate(true))
		while picks.size() < k and not bag.is_empty():
				var total := 0.0
				for item in bag:
						total += float(item.get("w", 0.0))
				if total <= 0.0:
						break
				var r := _rng.randf() * total
				var acc := 0.0
				var idx := 0
				for i in range(bag.size()):
						acc += float(bag[i].get("w", 0.0))
						if acc >= r:
								idx = i
								break
				picks.append(bag[idx])
				bag.remove_at(idx)
		return picks

func choose(tile_id: String) -> void:
		tile_id = String(tile_id)
		if tile_id.is_empty():
				return
		current_tile_id = tile_id
		var rc: Object = RunConfig if typeof(RunConfig) != TYPE_NIL else null
		if rc != null:
				rc.last_pick_id = tile_id
		_record_pick(tile_id)
		emit_signal("chosen", tile_id)
		var turn_engine: Node = null
		if Engine.has_singleton("TurnEngine"):
				turn_engine = Engine.get_singleton("TurnEngine")
		if turn_engine == null:
				turn_engine = get_node_or_null("/root/TurnEngine")
		if turn_engine != null and turn_engine.has_method("notify_commune_choice_made"):
				turn_engine.call("notify_commune_choice_made")
		var def_variant: Variant = _id_to_def.get(tile_id, {})
		var def: Dictionary = def_variant if def_variant is Dictionary else {}
		var force_now := bool(def.get("force_immediate", false))
		if force_now:
				current_tile_id = ""
				var world := _find_world()
				if world != null and world.has_method("enqueue_special"):
						world.call("enqueue_special", tile_id)
				emit_signal("cleared")

func has_current_tile() -> bool:
		return not current_tile_id.is_empty()

func get_current_tile_id() -> String:
		return current_tile_id

func consume_current_tile() -> String:
		if current_tile_id.is_empty():
				return ""
		var id := current_tile_id
		current_tile_id = ""
		emit_signal("cleared")
		return id

func get_tile_def(tile_id: String) -> Dictionary:
		var def_variant: Variant = _id_to_def.get(tile_id, {})
		return def_variant if def_variant is Dictionary else {}

func _record_pick(tile_id: String) -> void:
		if tile_id.is_empty():
				return
		_history_ids.append(tile_id)
		_apply_history_delta(tile_id, 1)
		while _history_ids.size() > _history_limit:
				var removed_id: String = String(_history_ids.pop_front())
				_apply_history_delta(removed_id, -1)

func _apply_history_delta(tile_id: String, delta: int) -> void:
		if tile_id.is_empty() or delta == 0:
				return
		var def: Dictionary = get_tile_def(tile_id)
		if def.is_empty():
				return
		var category := CategoryMap.canonical(String(def.get("category", "")))
		if category.is_empty():
				category = String(def.get("category", ""))
		if not category.is_empty():
				var next_cat := int(_category_history.get(category, 0)) + delta
				if next_cat <= 0:
						_category_history.erase(category)
				else:
						_category_history[category] = next_cat
		var tags_variant: Variant = def.get("tags", [])
		if tags_variant is Array:
				for tag_variant in tags_variant:
						var tag := String(tag_variant)
						if tag.is_empty():
								continue
						var next_tag := int(_tag_history.get(tag, 0)) + delta
						if next_tag <= 0:
								_tag_history.erase(tag)
						else:
								_tag_history[tag] = next_tag

func _get_totem(id: String) -> Dictionary:
		for entry_variant in _totems:
				if not (entry_variant is Dictionary):
						continue
				var entry: Dictionary = entry_variant
				if String(entry.get("id", "")) == id:
						return entry
		return {}

func _find_world() -> Node:
		var root := get_tree().root
		if root == null:
				return null
		var main := root.get_node_or_null("Main")
		if main != null and main.has_node("World"):
				return main.get_node("World")
		return root.find_child("World", true, false)
