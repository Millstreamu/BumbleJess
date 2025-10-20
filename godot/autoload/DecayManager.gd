extends Node

signal threat_started(cell: Vector2i, turns: int)
signal threat_updated(cell: Vector2i, turns: int)
signal threat_resolved(cell: Vector2i, victory: bool)

var cfg := {
	"max_attacks_per_turn": 3,
	"totem_spread_interval_turns": 3,
	"attack_countdown_turns": 3,
}

var _world: Node = null
var _turn := 1
var _last_spread_turn := 0
var _threats: Dictionary = {}

func _ready() -> void:
	var data := DataLite.load_json_dict("res://data/decay.json")
	if data is Dictionary and not data.is_empty():
		for key in data.keys():
			cfg[key] = data[key]

	var node: Node = get_node_or_null("/root/TurnEngine")
	if node == null:
		node = get_node_or_null("/root/Game")
	if node != null:
		if node.has_signal("turn_started") and not node.is_connected("turn_started", Callable(self, "_on_turn_started")):
			node.connect("turn_started", Callable(self, "_on_turn_started"))
		if node.has_signal("phase_started") and not node.is_connected("phase_started", Callable(self, "_on_phase_started")):
			node.connect("phase_started", Callable(self, "_on_phase_started"))

func bind_world(world: Node) -> void:
	if _world != null and _world != world:
		_clear_all_threats()
	_world = world

func _on_turn_started(turn: int) -> void:
	_turn = turn

func _on_phase_started(name: String) -> void:
	if _world == null:
		return
	if name == "decay":
		_spread_decay_if_due()
		_tick_and_trigger_battles()
		_start_new_threats_up_to_limit()

func _spread_decay_if_due() -> void:
	var interval := int(cfg.get("totem_spread_interval_turns", 3))
	if interval <= 0:
		interval = 3
	if (_turn - _last_spread_turn) % interval != 0:
		return
	_last_spread_turn = _turn

	var candidates: Array[Vector2i] = []
	for y in range(_world.height):
		for x in range(_world.width):
			var c := Vector2i(x, y)
			if _world.get_cell_name(_world.LAYER_OBJECTS, c) != "decay":
				continue
			var best := c
			var best_score := -999999
			for n in _world.neighbors_even_q(c):
				if _world.get_cell_name(_world.LAYER_OBJECTS, n) != "":
					continue
				var score := -_dist_to_origin(n)
				if score > best_score:
					best_score = score
					best = n
			if best != c:
				candidates.append(best)

	for target in candidates:
		_world.set_cell_named(_world.LAYER_OBJECTS, target, "decay")

func _dist_to_origin(c: Vector2i) -> int:
	var origin: Vector2i = _world.origin_cell
	return abs(c.x - origin.x) + abs(c.y - origin.y)

func _threat_key(c: Vector2i) -> int:
	return c.y * _world.width + c.x

func _has_threat(c: Vector2i) -> bool:
	return _threats.has(_threat_key(c))

func _add_threat(c: Vector2i, turns: int) -> void:
	var key := _threat_key(c)
	if _threats.has(key):
		return
	_world.set_fx(c, "fx_threat")
	var hud := _world.get_node_or_null("ThreatHUD")
	var label: Label = null
	if hud != null:
		label = Label.new()
		label.text = str(turns)
		label.add_theme_color_override("font_color", Color(1, 0.85, 0.2))
		label.add_theme_font_size_override("font_size", 16)
		var pos := _world.world_pos_of_cell(c)
		label.position = pos + Vector2(-8, -8)
		hud.add_child(label)
	_threats[key] = {
		"cell": c,
		"turns": turns,
		"label": label,
	}
	emit_signal("threat_started", c, turns)

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
	emit_signal("threat_updated", c, turns)

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
				if _has_threat(n):
					continue
				_add_threat(n, countdown)
				seen[key] = true
				started += 1

func _trigger_battle(target_cell: Vector2i) -> void:
	_clear_threat(target_cell)
	var encounter := {
		"target": target_cell,
	}
	var battle_manager := get_node_or_null("/root/BattleManager")
	if battle_manager != null and battle_manager.has_method("open_battle"):
		battle_manager.call("open_battle", encounter, Callable(self, "_on_battle_finished"))
	else:
		var rng := RandomNumberGenerator.new()
		rng.randomize()
		var victory := rng.randf() < 0.6
		_apply_battle_outcome(target_cell, victory)

func _on_battle_finished(result: Dictionary) -> void:
	var cell: Vector2i = result.get("target_cell", Vector2i.ZERO)
	var victory := bool(result.get("victory", true))
	_apply_battle_outcome(cell, victory)

func _apply_battle_outcome(cell: Vector2i, victory: bool) -> void:
	if _world == null:
		return
	if victory:
		var resource_manager := get_node_or_null("/root/ResourceManager")
		if resource_manager != null and resource_manager.has_method("add_life"):
			resource_manager.call("add_life", 3)
		if _world.get_cell_name(_world.LAYER_OBJECTS, cell) == "decay":
			_world.set_cell_named(_world.LAYER_OBJECTS, cell, "empty")
	else:
		_world.set_cell_named(_world.LAYER_LIFE, cell, "empty")
		_world.set_cell_named(_world.LAYER_OBJECTS, cell, "decay")
		for neighbor in _world.neighbors_even_q(cell):
			if _world.get_cell_name(_world.LAYER_LIFE, neighbor) != "":
				_world.set_cell_named(_world.LAYER_LIFE, neighbor, "empty")
				_world.set_cell_named(_world.LAYER_OBJECTS, neighbor, "decay")
	emit_signal("threat_resolved", cell, victory)

func _clear_all_threats() -> void:
	var keys := _threats.keys()
	for key in keys:
		var record: Dictionary = _threats[key]
		var cell: Vector2i = record.get("cell", Vector2i.ZERO)
		_clear_threat(cell)
	_threats.clear()
