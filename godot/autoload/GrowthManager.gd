extends Node

signal grove_spawned(cell: Vector2i)

const MATURATION_TURNS := 3

var _world: Node = null
var _turn: int = 1
var _growth_mult := 1.0
var _overgrowth_born: Dictionary = {}
var _tmp_reachable_from_edge: Dictionary = {}
var _born_turn: Dictionary = {}
var _tile_rules_cache: Dictionary = {}

func _ready() -> void:
        _connect_turn_engine()
        _connect_world_signal()

func bind_world(world: Node) -> void:
	_world = world
	_overgrowth_born.clear()
	_tmp_reachable_from_edge.clear()
	_born_turn.clear()
	_connect_world_signal()

func tick_growth_phase(turn: int) -> void:
        _turn = max(turn, 1)
        _run_growth_cycle()

func request_growth_update(current_turn: int = -1) -> void:
        if current_turn < 0:
                var engine := _get_turn_engine()
                if engine != null:
                        var value: Variant = engine.get("turn_index")
                        if typeof(value) == TYPE_INT:
                                current_turn = int(value)
        if current_turn >= 0:
                _turn = max(current_turn, 1)
        _run_growth_cycle()

func apply_growth_multiplier(mult: float) -> void:
        _growth_mult *= mult
        print("Growth speed multiplier:", _growth_mult)

func _connect_turn_engine() -> void:
        var turn_engine: Node = _get_turn_engine()
        if turn_engine == null:
                return
        if turn_engine.has_signal("run_started") and not turn_engine.is_connected(
                "run_started", Callable(self, "_on_run_started")
        ):
                turn_engine.connect("run_started", Callable(self, "_on_run_started"))
        if turn_engine.has_signal("turn_changed") and not turn_engine.is_connected(
                "turn_changed", Callable(self, "_on_turn_changed")
        ):
                turn_engine.connect("turn_changed", Callable(self, "_on_turn_changed"))
        _on_run_started()

func _on_run_started() -> void:
        var engine := _get_turn_engine()
        if engine == null:
                _turn = 1
                return
        var value: Variant = engine.get("turn_index")
        if typeof(value) == TYPE_INT:
                _turn = max(int(value), 1)
        else:
                _turn = 1

func _on_turn_changed(turn: int) -> void:
        _turn = max(turn, 1)

func _get_turn_engine() -> Node:
        var turn_engine: Node = null
        if Engine.has_singleton("TurnEngine"):
                var singleton := Engine.get_singleton("TurnEngine")
                if singleton is Node:
                        turn_engine = singleton
        if turn_engine == null:
                turn_engine = get_node_or_null("/root/TurnEngine")
        if turn_engine == null and Engine.has_singleton("Game"):
                var game_singleton := Engine.get_singleton("Game")
                if game_singleton is Node:
                        turn_engine = game_singleton
        if turn_engine == null:
                turn_engine = get_node_or_null("/root/Game")
        return turn_engine

func _run_growth_cycle() -> void:
	_recompute_overgrowth()
	_handle_decay_contact()
	_bloom_groves()
	_handle_special_growth()
	if _world != null and _world.has_method("_update_hud"):
		_world._update_hud()

func _recompute_overgrowth() -> void:
	if _world == null:
		return
	var width: int = _world.width
	var height: int = _world.height
	if width <= 0 or height <= 0:
		return

	var empty := PackedByteArray()
	empty.resize(width * height)
	for y in range(height):
		for x in range(width):
			var cell := Vector2i(x, y)
			var object_name: String = _world.get_cell_name(_world.LAYER_OBJECTS, cell)
			var life_name: String = _world.get_cell_name(_world.LAYER_LIFE, cell)
			var has_object: bool = not (object_name.is_empty() or object_name == "empty")
			var has_life: bool = not (life_name.is_empty() or life_name == "empty")
			empty[y * width + x] = 1 if (not has_object and not has_life) else 0

	_tmp_reachable_from_edge.clear()
	var queue: Array[Vector2i] = []

	for x in range(width):
		if empty[0 * width + x] == 1:
			queue.append(Vector2i(x, 0))
		if empty[(height - 1) * width + x] == 1:
			queue.append(Vector2i(x, height - 1))
	for y in range(height):
		if empty[y * width + 0] == 1:
			queue.append(Vector2i(0, y))
		if empty[y * width + (width - 1)] == 1:
			queue.append(Vector2i(width - 1, y))

	while queue.size() > 0:
		var cell: Vector2i = queue.pop_back()
		var cell_hash := _hash_cell(cell, width)
		if _tmp_reachable_from_edge.has(cell_hash):
			continue
		_tmp_reachable_from_edge[cell_hash] = true
		for neighbor in _world.neighbors_even_q(cell):
			if empty[neighbor.y * width + neighbor.x] == 1:
				var neighbor_hash := _hash_cell(neighbor, width)
				if not _tmp_reachable_from_edge.has(neighbor_hash):
					queue.append(neighbor)

	for y in range(height):
		for x in range(width):
			if empty[y * width + x] != 1:
				continue
			var cell := Vector2i(x, y)
			var cell_hash := _hash_cell(cell, width)
			var reachable := _tmp_reachable_from_edge.has(cell_hash)
			var life_name: String = _world.get_cell_name(_world.LAYER_LIFE, cell)
			if not reachable:
				if life_name == "" or life_name == "empty":
                                        _world.set_cell_named(_world.LAYER_LIFE, cell, "overgrowth")
                                        if _world.has_method("set_fx"):
                                                _world.set_fx(cell, "fx_bloom_hint")
                                        if not _overgrowth_born.has(cell_hash):
                                                _overgrowth_born[cell_hash] = _turn
			else:
				if _overgrowth_born.has(cell_hash):
					_overgrowth_born.erase(cell_hash)
				if life_name == "overgrowth":
					_world.set_cell_named(_world.LAYER_LIFE, cell, "empty")

func _handle_decay_contact() -> void:
	if _world == null:
		return
	var width: int = _world.width
	var height: int = _world.height
	var to_clear: Array[Vector2i] = []

	for y in range(height):
		for x in range(width):
			var cell := Vector2i(x, y)
			if _world.get_cell_name(_world.LAYER_LIFE, cell) != "overgrowth":
				continue
			for neighbor in _world.neighbors_even_q(cell):
				if _world.get_cell_name(_world.LAYER_OBJECTS, neighbor) == "decay":
					to_clear.append(cell)
					break

	for cell in to_clear:
		_world.set_cell_named(_world.LAYER_LIFE, cell, "empty")
		var cell_hash := _hash_cell(cell, width)
		if _overgrowth_born.has(cell_hash):
			_overgrowth_born.erase(cell_hash)

func _bloom_groves() -> void:
        if _world == null:
                return
        var width: int = _world.width
        var to_bloom: Array[Vector2i] = []

        for cell_hash in _overgrowth_born.keys():
                var born_turn := int(_overgrowth_born[cell_hash])
                if _turn - born_turn < MATURATION_TURNS:
                        continue
                var cell_pos := _unhash_cell(cell_hash, width)
                if _world.get_cell_name(_world.LAYER_LIFE, cell_pos) == "overgrowth":
                        to_bloom.append(cell_pos)

        var any_bloomed := false
        for bloom_cell in to_bloom:
                _world.set_cell_named(_world.LAYER_LIFE, bloom_cell, "grove")
                if _world.has_method("clear_fx"):
                        _world.clear_fx(bloom_cell)
                if _world.has_method("set_fx"):
                        _world.set_fx(bloom_cell, "fx_grove_glow")
                var bloom_hash := _hash_cell(bloom_cell, width)
                _overgrowth_born.erase(bloom_hash)
                emit_signal("grove_spawned", bloom_cell)
                any_bloomed = true
        if any_bloomed and Engine.has_singleton("AudioBus"):
                AudioBus.play("res://assets/sfx/growth.wav")

func _handle_special_growth() -> void:
	if _world == null:
		return
	var width: int = _world.width
	var height: int = _world.height
	if width <= 0 or height <= 0:
		return

	for y in range(height):
		for x in range(width):
			var cell := Vector2i(x, y)
			var tile_id: String = String(_world.get_cell_tile_id(_world.LAYER_LIFE, cell))
			if tile_id.is_empty():
				continue
			var rules := _rules_for(tile_id)
			if rules.is_empty():
				continue

			if rules.has("overgrowth_every_turns"):
				var every := int(rules.get("overgrowth_every_turns", 1))
				if every <= 0:
					every = 1
				if (_turn % every) == 0:
					var count := int(rules.get("overgrowth_count", 1))
					if count <= 0:
						count = 1
					var converted := 0
					for neighbor in _world.neighbors_even_q(cell):
						if converted >= count:
							break
						var neighbor_name: String = _world.get_cell_name(_world.LAYER_LIFE, neighbor)
						if not (neighbor_name.is_empty() or neighbor_name == "empty"):
							continue
                                                _world.set_cell_named(_world.LAYER_LIFE, neighbor, "overgrowth")
                                                if _world.has_method("set_fx"):
                                                        _world.set_fx(neighbor, "fx_bloom_hint")
                                                if _world.has_method("set_cell_tile_id"):
                                                        _world.set_cell_tile_id(
                                                                _world.LAYER_LIFE,
                                                                neighbor,
                                                                "tile.overgrowth.default",
							)
						var neighbor_hash := _hash_cell(neighbor, width)
						_overgrowth_born[neighbor_hash] = _turn
						converted += 1

			if rules.has("decay_after_turns"):
				var required := int(rules.get("decay_after_turns", 0))
				if required <= 0:
					continue
				var cell_hash := _hash_cell(cell, width)
				var born := int(_born_turn.get(cell_hash, _turn))
				var age := _turn - born
				if age >= required:
					var into := String(rules.get("decay_into", "overgrowth"))
					if into.is_empty():
						into = "overgrowth"
                                        _world.set_cell_named(_world.LAYER_LIFE, cell, into)
                                        if _world.has_method("set_fx"):
                                                if into == "overgrowth":
                                                        _world.set_fx(cell, "fx_bloom_hint")
                                                elif into == "grove":
                                                        if _world.has_method("clear_fx"):
                                                                _world.clear_fx(cell)
                                                        _world.set_fx(cell, "fx_grove_glow")
                                                        if Engine.has_singleton("AudioBus"):
                                                                AudioBus.play("res://assets/sfx/growth.wav")
                                        if _world.has_method("set_cell_tile_id"):
                                                _world.set_cell_tile_id(
                                                        _world.LAYER_LIFE,
                                                        cell,
                                                        "tile.%s.default" % into,
						)
					if into == "overgrowth":
						var overgrowth_hash := _hash_cell(cell, width)
						_overgrowth_born[overgrowth_hash] = _turn
					_born_turn.erase(cell_hash)

func _hash_cell(cell: Vector2i, width: int) -> int:
	return cell.y * width + cell.x

func _unhash_cell(cell_hash: int, width: int) -> Vector2i:
	if width <= 0:
		return Vector2i.ZERO
	var x := cell_hash % width
	var y := int(floor(float(cell_hash) / float(width)))
	return Vector2i(x, y)

func _connect_world_signal() -> void:
	var world_node: Node = _world
	if world_node == null and get_tree() != null:
		world_node = get_tree().root.get_node_or_null("World")
	if world_node == null:
		return
	if _world == null:
		_world = world_node
	if not world_node.has_signal("tile_placed"):
		return
	if not world_node.is_connected("tile_placed", Callable(self, "_on_tile_placed")):
		world_node.connect("tile_placed", Callable(self, "_on_tile_placed"))

func _on_tile_placed(_tile_id: String, cell: Vector2i) -> void:
	if _world == null:
		return
	var width: int = _world.width
	if width <= 0:
		return
	var cell_hash := _hash_cell(cell, width)
	_born_turn[cell_hash] = _turn

func _rules_for(tile_id: String) -> Dictionary:
	if tile_id.is_empty():
		return {}
	if _tile_rules_cache.is_empty():
		var entries: Array = DataLite.load_json_array("res://data/tiles.json")
		for entry_variant in entries:
			if not (entry_variant is Dictionary):
				continue
			var entry: Dictionary = entry_variant
			var entry_id := String(entry.get("id", ""))
			if entry_id.is_empty():
				continue
			var rules_variant: Variant = entry.get("rules", {})
			if rules_variant is Dictionary:
				_tile_rules_cache[entry_id] = (rules_variant as Dictionary)
			else:
				_tile_rules_cache[entry_id] = {}
	var found_variant: Variant = _tile_rules_cache.get(tile_id, {})
	return found_variant if found_variant is Dictionary else {}
