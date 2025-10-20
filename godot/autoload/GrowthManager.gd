extends Node

signal grove_spawned(cell: Vector2i)

const MATURATION_TURNS := 3

var _world: Node = null
var _turn: int = 1
var _overgrowth_born: Dictionary = {}
var _tmp_reachable_from_edge: Dictionary = {}

func _ready() -> void:
	_bind_turn_events()

func _bind_turn_events() -> void:
	if has_node("/root/TurnEngine"):
		var turn_engine: Node = get_node("/root/TurnEngine")
		if not turn_engine.is_connected("turn_started", Callable(self, "_on_turn_started")):
			turn_engine.connect("turn_started", Callable(self, "_on_turn_started"))
		if not turn_engine.is_connected("phase_started", Callable(self, "_on_phase_started")):
			turn_engine.connect("phase_started", Callable(self, "_on_phase_started"))
	elif has_node("/root/Game"):
		var game: Node = get_node("/root/Game")
		if not game.is_connected("turn_started", Callable(self, "_on_turn_started")):
			game.connect("turn_started", Callable(self, "_on_turn_started"))
		if not game.is_connected("phase_started", Callable(self, "_on_phase_started")):
			game.connect("phase_started", Callable(self, "_on_phase_started"))

func bind_world(world: Node) -> void:
	_world = world
	_overgrowth_born.clear()
	_tmp_reachable_from_edge.clear()

func _on_turn_started(turn: int) -> void:
	_turn = max(turn, 1)

func _on_phase_started(phase_name: String) -> void:
	if phase_name != "growth":
		return
	_run_growth_cycle()

func request_growth_update(current_turn: int = -1) -> void:
	if current_turn >= 0:
		_turn = max(current_turn, 1)
	_run_growth_cycle()

func _run_growth_cycle() -> void:
	_recompute_overgrowth()
	_handle_decay_contact()
	_bloom_groves()
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
		var cell := _unhash_cell(cell_hash, width)
		if _world.get_cell_name(_world.LAYER_LIFE, cell) == "overgrowth":
			to_bloom.append(cell)

	for cell in to_bloom:
		_world.set_cell_named(_world.LAYER_LIFE, cell, "grove")
		var cell_hash := _hash_cell(cell, width)
		_overgrowth_born.erase(cell_hash)
		emit_signal("grove_spawned", cell)

func _hash_cell(cell: Vector2i, width: int) -> int:
	return cell.y * width + cell.x

func _unhash_cell(cell_hash: int, width: int) -> Vector2i:
        if width <= 0:
                return Vector2i.ZERO
        var x := cell_hash % width
        var y := int(floor(float(cell_hash) / float(width)))
        return Vector2i(x, y)
