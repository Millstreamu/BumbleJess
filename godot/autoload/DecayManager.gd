extends Node

signal threat_started(cell: Vector2i, turns: int)
signal threat_updated(cell: Vector2i, turns: int)
signal threat_resolved(cell: Vector2i, victory: bool)


class Cluster:
	var id: int
	var totem_cell: Vector2i
	var tiles: Dictionary
	var frontier: Dictionary
	var last_spread_turn: int

	func _init(cluster_id: int, origin: Vector2i) -> void:
		id = cluster_id
		totem_cell = origin
		tiles = {}
		frontier = {}
		last_spread_turn = 0


var cfg := {
	"max_attacks_per_turn": 3,
	"totem_spread_interval_turns": 3,
	"attack_countdown_turns": 3,
}

var debug_show_clusters := false

var _world: Node = null
var _turn := 1
var _last_spread_turn := 0
var _threats: Dictionary = {}
var _clusters: Array = []
var _clusters_dirty := true
var _next_cluster_id := 1
var _fx_name_for_cluster := {}


func _is_guard(c: Vector2i) -> bool:
	if _world == null:
		return false
	return _world.get_cell_name(_world.LAYER_LIFE, c) == "guard"


func _threat_color(turns: int) -> Color:
	var color := Color(1, 0.85, 0.2)
	if turns == 2:
		color = Color(1, 0.55, 0.25)
	elif turns <= 1:
		color = Color(1, 0.25, 0.25)
	return color


func _origin_cell() -> Vector2i:
	if _world == null:
		return Vector2i.ZERO
	return _world.get_origin_cell() if _world.has_method("get_origin_cell") else _world.origin_cell


func _axial_like_distance(a: Vector2i, b: Vector2i) -> int:
	return abs(a.x - b.x) + abs(a.y - b.y)


func _cluster_color(id: int) -> Color:
	var hue := fmod(id * 0.61803398875, 1.0)
	return Color.from_hsv(hue, 0.55, 0.9, 0.35)


func _cell_hash(c: Vector2i) -> int:
	if _world == null:
		return 0
	return c.y * _world.width + c.x


func _cell_from_hash(cell_hash_value: int) -> Vector2i:
	if _world == null or _world.width <= 0:
		return Vector2i.ZERO
	return Vector2i(cell_hash_value % _world.width, cell_hash_value / _world.width)


func _is_decay(c: Vector2i) -> bool:
	if _world == null:
		return false
	return _world.get_cell_name(_world.LAYER_OBJECTS, c) == "decay"


func _is_blocked_for_decay(c: Vector2i) -> bool:
	if _world == null:
		return true
	if _world.get_cell_name(_world.LAYER_OBJECTS, c) != "":
		return true
	if _is_guard(c):
		return true
	return false


func _get_hexmap() -> TileMap:
	if _world == null:
		return null
	return _world.get_node_or_null("HexMap")


func _set_cluster_metadata(c: Vector2i, cluster_id: int) -> void:
	if _world == null:
		return
	_world.set_cell_meta(_world.LAYER_OBJECTS, c, "cluster_id", cluster_id)


func _clear_cluster_metadata(c: Vector2i) -> void:
	if _world == null:
		return
	_world.set_cell_meta(_world.LAYER_OBJECTS, c, "cluster_id", null)


func _get_cluster_id_from_metadata(c: Vector2i) -> int:
	if _world == null:
		return 0
	var existing: Variant = _world.get_cell_meta(_world.LAYER_OBJECTS, c, "cluster_id")
	if typeof(existing) == TYPE_INT:
		return int(existing)
	if typeof(existing) == TYPE_STRING:
		var as_string := String(existing)
		if not as_string.is_empty():
			return as_string.to_int()
	return 0


func _prune_cluster_frontier(cluster: Cluster) -> void:
	var keys_to_remove: Array = []
	for key in cluster.frontier.keys():
		var cell_variant: Variant = cluster.frontier[key]
		if not (cell_variant is Vector2i):
			keys_to_remove.append(key)
			continue
		var cell: Vector2i = cell_variant
		if _is_blocked_for_decay(cell):
			keys_to_remove.append(key)
			continue
		if _is_decay(cell):
			keys_to_remove.append(key)
	for key in keys_to_remove:
		cluster.frontier.erase(key)


func _rebuild_cluster_frontier(cluster: Cluster) -> void:
	cluster.frontier.clear()
	for cluster_hash in cluster.tiles.keys():
		var cell: Vector2i = _cell_from_hash(int(cluster_hash))
		for neighbor in _world.neighbors_even_q(cell):
			if _is_blocked_for_decay(neighbor):
				continue
			if _is_decay(neighbor):
				continue
			cluster.frontier[_cell_hash(neighbor)] = neighbor


func _ensure_clusters_scanned() -> void:
	if _clusters_dirty:
		_scan_clusters()


func _mark_clusters_dirty() -> void:
		_clusters_dirty = true


func rescan_clusters() -> void:
		_mark_clusters_dirty()
		_scan_clusters()


func _ensure_cluster_fx_tile(cl_id: int) -> String:
	if _fx_name_for_cluster.has(cl_id):
		return String(_fx_name_for_cluster[cl_id])
	var fx_name := "fx_cluster_%d" % cl_id
	var col := _cluster_color(cl_id)
	if _world != null and _world.has_method("tileset_add_named_color"):
		_world.tileset_add_named_color(fx_name, col)
	_fx_name_for_cluster[cl_id] = fx_name
	return fx_name


func _reapply_threat_fx() -> void:
	if _world == null:
		return
	for key in _threats.keys():
		var record_variant: Variant = _threats[key]
		if not (record_variant is Dictionary):
			continue
		var record: Dictionary = record_variant
		var cell_variant: Variant = record.get("cell", Vector2i.ZERO)
		if cell_variant is Vector2i:
			_world.set_fx(cell_variant, "fx_threat")


func _refresh_cluster_fx_overlay() -> void:
	if _world == null:
		return
	_world.clear_all_fx()
	if debug_show_clusters:
		for cluster in _clusters:
			if cluster == null:
				continue
			var fx_name := _ensure_cluster_fx_tile(cluster.id)
			for cluster_hash in cluster.tiles.keys():
				var cell: Vector2i = _cell_from_hash(int(cluster_hash))
				_world.set_fx(cell, fx_name)
	_reapply_threat_fx()


func _cmp_rec_by_turns(a: Dictionary, b: Dictionary) -> bool:
	return int(a.get("turns", 0)) < int(b.get("turns", 0))


func _refresh_threat_list() -> void:
	if _world == null:
		return
	var rows: VBoxContainer = _world.get_node_or_null("ThreatHUD/ThreatList/Panel/Rows")
	if rows == null:
		return
	for child in rows.get_children():
		child.queue_free()
	var records: Array = []
	for key in _threats.keys():
		var rec_variant: Variant = _threats[key]
		if rec_variant is Dictionary:
			records.append(rec_variant)
	records.sort_custom(Callable(self, "_cmp_rec_by_turns"))
	for rec_variant in records:
		var rec: Dictionary = rec_variant
		var cell: Vector2i = rec.get("cell", Vector2i.ZERO)
		var turns := int(rec.get("turns", 0))
		var row := HBoxContainer.new()
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var lab_cell := Label.new()
		lab_cell.text = "Cell: (%d,%d)" % [cell.x, cell.y]
		lab_cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var lab_turns := Label.new()
		lab_turns.text = "Turns: %d" % turns
		var color := _threat_color(turns)
		lab_cell.add_theme_color_override("font_color", color)
		lab_turns.add_theme_color_override("font_color", color)
		row.add_child(lab_cell)
		row.add_child(lab_turns)
		rows.add_child(row)


func _scan_clusters() -> void:
	if _world == null:
		return
	if not _world.has_node("HexMap"):
		return
	var visited: Dictionary = {}
	var width := int(_world.width)
	var height := int(_world.height)
	var max_existing_id := 0
	for y in range(height):
		for x in range(width):
			var c := Vector2i(x, y)
			var stored_id := _get_cluster_id_from_metadata(c)
			if stored_id > max_existing_id:
				max_existing_id = stored_id
	_clusters.clear()
	_clusters_dirty = false
	if max_existing_id <= 0:
		_next_cluster_id = 1
	else:
		_next_cluster_id = max_existing_id + 1
	var present_cluster_ids: Dictionary = {}
	for y in range(height):
		for x in range(width):
			var c := Vector2i(x, y)
			if not _is_decay(c):
				_clear_cluster_metadata(c)
				continue
			var cell_hash_value := _cell_hash(c)
			if visited.has(cell_hash_value):
				continue
			var cluster_id := _get_cluster_id_from_metadata(c)
			if cluster_id <= 0:
				cluster_id = _next_cluster_id
				_next_cluster_id += 1
			var cluster := Cluster.new(cluster_id, c)
			var queue: Array[Vector2i] = [c]
			visited[cell_hash_value] = true
			while not queue.is_empty():
				var current: Vector2i = queue.pop_back()
				var current_hash := _cell_hash(current)
				cluster.tiles[current_hash] = true
				_set_cluster_metadata(current, cluster.id)
				for neighbor in _world.neighbors_even_q(current):
					if _is_decay(neighbor):
						var n_hash := _cell_hash(neighbor)
						if not visited.has(n_hash):
							visited[n_hash] = true
							queue.append(neighbor)
					elif not _is_blocked_for_decay(neighbor):
						cluster.frontier[_cell_hash(neighbor)] = neighbor
			_clusters.append(cluster)
			present_cluster_ids[cluster.id] = true
	var to_remove: Array = []
	for key in _fx_name_for_cluster.keys():
		if not present_cluster_ids.has(int(key)):
			to_remove.append(key)
	for key in to_remove:
		_fx_name_for_cluster.erase(key)
	_refresh_cluster_fx_overlay()


func _ready() -> void:
	var data := DataLite.load_json_dict("res://data/decay.json")
	if data is Dictionary and not data.is_empty():
		for key in data.keys():
			cfg[key] = data[key]

	var node: Node = get_node_or_null("/root/TurnEngine")
	if node == null:
		node = get_node_or_null("/root/Game")
	if node != null:
		if (
			node.has_signal("turn_started")
			and not node.is_connected("turn_started", Callable(self, "_on_turn_started"))
		):
			node.connect("turn_started", Callable(self, "_on_turn_started"))
		if (
			node.has_signal("phase_started")
			and not node.is_connected("phase_started", Callable(self, "_on_phase_started"))
		):
			node.connect("phase_started", Callable(self, "_on_phase_started"))


func bind_world(world: Node) -> void:
		if _world != null and _world != world:
				_clear_all_threats()
		_world = world
		_refresh_threat_list()
		rescan_clusters()


func _on_turn_started(turn: int) -> void:
	_turn = turn


func _on_phase_started(phase_name: String) -> void:
	if _world == null:
		return
	if phase_name == "decay":
		_spread_clusters_if_due()
		_tick_and_trigger_battles()
		_start_new_threats_up_to_limit()


func _spread_decay_if_due() -> void:
	_spread_clusters_if_due()


func _spread_clusters_if_due() -> void:
	var interval := int(cfg.get("totem_spread_interval_turns", 3))
	if interval <= 0:
		interval = 3
	if (_turn - _last_spread_turn) % interval != 0:
		return
	_last_spread_turn = _turn

	_ensure_clusters_scanned()
	if _clusters.is_empty():
		return

	var rng := RandomNumberGenerator.new()
	rng.randomize()

	for cluster in _clusters:
		if cluster == null:
			continue
		_prune_cluster_frontier(cluster)
		if cluster.frontier.is_empty():
			_rebuild_cluster_frontier(cluster)
		if cluster.frontier.is_empty():
			continue

		var origin := _origin_cell()
		var best_k := -1
		var best_c := Vector2i(-1, -1)
		var best_score := 1_000_000
		for k in cluster.frontier.keys():
			var cell_variant: Variant = cluster.frontier[k]
			if not (cell_variant is Vector2i):
				continue
			var c: Vector2i = cell_variant
			var score := _axial_like_distance(c, origin)
			score += int(rng.randi_range(0, 2))
			if score < best_score:
				best_score = score
				best_k = k
				best_c = c

		if best_k == -1:
			continue

		_world.set_cell_named(_world.LAYER_OBJECTS, best_c, "decay")
		_set_cluster_metadata(best_c, cluster.id)
		cluster.tiles[_cell_hash(best_c)] = true
		cluster.frontier.erase(best_k)

		for neighbor in _world.neighbors_even_q(best_c):
			if _is_blocked_for_decay(neighbor):
				continue
			if _is_decay(neighbor):
				continue
			cluster.frontier[_cell_hash(neighbor)] = neighbor

		cluster.last_spread_turn = _turn

	_refresh_cluster_fx_overlay()


func _threat_key(c: Vector2i) -> int:
	return c.y * _world.width + c.x


func _has_threat(c: Vector2i) -> bool:
	return _threats.has(_threat_key(c))


func _add_threat(c: Vector2i, turns: int, attacker_cell: Vector2i = Vector2i.ZERO) -> void:
		var key := _threat_key(c)
		if _is_guard(c):
				return
		if _threats.has(key):
				return
		_world.set_fx(c, "fx_threat")
		var hud := _world.get_node_or_null("ThreatHUD")
		var label: Label = null
		if hud != null:
				label = Label.new()
				label.text = str(turns)
				label.add_theme_color_override("font_color", _threat_color(turns))
				label.add_theme_font_size_override("font_size", 16)
				var pos: Vector2 = _world.world_pos_of_cell(c)
				label.position = pos + Vector2(-8, -8)
				hud.add_child(label)
		_threats[key] = {
				"cell": c,
				"turns": turns,
				"attacker": attacker_cell,
				"label": label,
		}
		emit_signal("threat_started", c, turns)
		_refresh_threat_list()


func _update_threat(c: Vector2i, turns: int) -> void:
	var key := _threat_key(c)
	if not _threats.has(key):
		return
	var record: Dictionary = _threats[key]
	record["turns"] = turns
	_threats[key] = record
	var label: Label = record.get("label")
	if is_instance_valid(label):
		label.text = str(turns)
		label.add_theme_color_override("font_color", _threat_color(turns))
	emit_signal("threat_updated", c, turns)
	_refresh_threat_list()


func _clear_threat(c: Vector2i) -> void:
	var key := _threat_key(c)
	if not _threats.has(key):
		return
	var record: Dictionary = _threats[key]
	var label: Label = record.get("label")
	if is_instance_valid(label):
		label.queue_free()
	if _world != null:
		_world.clear_fx(record.get("cell", c))
	_threats.erase(key)
	_refresh_threat_list()
	_refresh_cluster_fx_overlay()


func _tick_and_trigger_battles() -> void:
	var to_trigger: Array[Vector2i] = []
	for key in _threats.keys():
		var record: Dictionary = _threats[key]
		var cell: Vector2i = record.get("cell", Vector2i.ZERO)
		var next_turns := int(record.get("turns", 0)) - 1
		if next_turns <= 0:
			to_trigger.append(cell)
		else:
			_update_threat(cell, next_turns)
	for cell in to_trigger:
		_trigger_battle(cell)
	_refresh_threat_list()


func _start_new_threats_up_to_limit() -> void:
		var max_per_turn := int(cfg.get("max_attacks_per_turn", 3))
		if max_per_turn <= 0:
				return
		var started := 0
		var seen: Dictionary = {}
		var countdown := int(cfg.get("attack_countdown_turns", 3))
		for y in range(_world.height):
				for x in range(_world.width):
						var c := Vector2i(x, y)
						if _world.get_cell_name(_world.LAYER_OBJECTS, c) != "decay":
								continue
						for n in _world.neighbors_even_q(c):
								if started >= max_per_turn:
										return
								var key := _threat_key(n)
								if seen.has(key):
										continue
								if _world.get_cell_name(_world.LAYER_LIFE, n) == "":
										continue
								if _is_guard(n):
										continue
								if _has_threat(n):
										continue
								_add_threat(n, countdown, c)
								seen[key] = true
								started += 1


func _trigger_battle(target_cell: Vector2i) -> void:
		var attacker_cell := Vector2i.ZERO
		var key := _threat_key(target_cell)
		if _threats.has(key):
				var record: Dictionary = _threats[key]
				var attacker_variant: Variant = record.get("attacker")
				if attacker_variant is Vector2i:
						attacker_cell = attacker_variant
		_clear_threat(target_cell)
		var encounter := {
				"target": target_cell,
				"attacker": attacker_cell,
		}
		BattleManager.open_battle(encounter, Callable(self, "_on_battle_finished"))


func _on_battle_finished(result: Dictionary) -> void:
		var cell: Vector2i = result.get("target_cell", Vector2i.ZERO)
		var victory := bool(result.get("victory", true))
		var attacker_cell: Vector2i = result.get("attacker_cell", Vector2i.ZERO)
		_apply_battle_outcome(cell, victory, attacker_cell)


func _apply_battle_outcome(cell: Vector2i, victory: bool, attacker_cell: Vector2i = Vector2i.ZERO) -> void:
		if _world == null:
				return
		if victory:
				var resource_manager := get_node_or_null("/root/ResourceManager")
				if resource_manager != null and resource_manager.has_method("add_life"):
						resource_manager.call("add_life", 3)
				var decay_cell := attacker_cell
				if _world.get_cell_name(_world.LAYER_OBJECTS, decay_cell) != "decay":
						decay_cell = cell
				if _world.get_cell_name(_world.LAYER_OBJECTS, decay_cell) == "decay":
						_world.set_cell_named(_world.LAYER_OBJECTS, decay_cell, "empty")
						_clear_cluster_metadata(decay_cell)
		else:
				if _world.get_cell_name(_world.LAYER_LIFE, cell) != "guard":
						_world.set_cell_named(_world.LAYER_LIFE, cell, "empty")
		_world.set_cell_named(_world.LAYER_OBJECTS, cell, "decay")
		for neighbor in _world.neighbors_even_q(cell):
				var life_name: String = _world.get_cell_name(_world.LAYER_LIFE, neighbor)
				if life_name != "" and life_name != "guard":
						_world.set_cell_named(_world.LAYER_LIFE, neighbor, "empty")
						_world.set_cell_named(_world.LAYER_OBJECTS, neighbor, "decay")
		emit_signal("threat_resolved", cell, victory)
		rescan_clusters()


func _clear_all_threats() -> void:
	var keys := _threats.keys()
	for key in keys:
		var record: Dictionary = _threats[key]
		var cell: Vector2i = record.get("cell", Vector2i.ZERO)
		_clear_threat(cell)
	_threats.clear()
	_refresh_threat_list()
	_refresh_cluster_fx_overlay()
