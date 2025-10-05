extends Node2D

## Primary controller for the hex grid. Responsible for generating cells,
## managing the cursor, cell data, and complex bookkeeping.
class_name HexGrid

const Coord := preload("res://scripts/core/Coord.gd")
const HexCell := preload("res://scripts/grid/HexCell.gd")
const HexCursor := preload("res://scripts/grid/HexCursor.gd")
const CellType := preload("res://scripts/core/CellType.gd")
const CellData := preload("res://scripts/core/CellData.gd")
signal complexes_updated(changed_types: Array)
signal brood_created(cells: Array[Vector2i])
signal brood_hatched(cells: Array[Vector2i])
signal brood_state_changed(q: int, r: int, state: int)
signal bee_slots_changed(q: int, r: int, used: int, cap: int)

@export var grid_config: GridConfig
@export var cell_scene: PackedScene = preload("res://scenes/HexCell.tscn")
@export var cursor_scene: PackedScene = preload("res://scenes/HexCursor.tscn")

var cells: Dictionary = {}
var _cell_states: Dictionary = {}
var _complex_sizes: Dictionary = {}
var _cursor_axial: Vector2i = Vector2i.ZERO
var _cursor_node: HexCursor
var _selected_cells: Dictionary = {}
var _active_brood_timers: Dictionary = {}
var _last_brood_created: Array[Vector2i] = []
var _assignment_highlighted: Array[Vector2i] = []
var _bee_positions: Dictionary = {}
var _bee_manager: Node = null
var _current_assignment_spec: String = ""
var _egg_manager: Node = null

func _get_egg_manager() -> Node:
        if is_instance_valid(_egg_manager):
                return _egg_manager
        if Engine.has_singleton("EggManager"):
                _egg_manager = EggManager
                return _egg_manager
        var tree := get_tree()
        if tree and tree.root:
                _egg_manager = tree.root.get_node_or_null("EggManager")
        return _egg_manager

func _ready() -> void:
	if not _ensure_grid_config():
		push_error("HexGrid could not load a GridConfig resource")
		return
	_connect_egg_manager()
	_connect_bee_manager()
	_generate_grid()
	_spawn_cursor()
	set_process(false)

func _generate_grid() -> void:
	if not _ensure_grid_config():
		return
	for child in get_children():
		if child is HexCell:
			remove_child(child)
			child.queue_free()
	cells.clear()
	_cell_states.clear()
	_selected_cells.clear()
	_active_brood_timers.clear()
	_last_brood_created.clear()
	_assignment_highlighted.clear()
	_bee_positions.clear()
	set_process(false)

	var radius := grid_config.radius
	for q in range(-radius, radius + 1):
		for r in range(-radius, radius + 1):
			if abs(q + r) > radius:
				continue
			if abs(q) > radius or abs(r) > radius:
				continue
			var axial := Vector2i(q, r)
			var cell: HexCell = cell_scene.instantiate()
			add_child(cell)
			cell.position = Coord.axial_to_world(axial, grid_config.cell_size)
			var cell_type := CellType.Type.EMPTY
			if axial == Vector2i.ZERO:
				cell_type = CellType.Type.QUEEN_SEAT
			var color := grid_config.get_color(cell_type)
			cell.configure(
				axial,
				grid_config.cell_size,
				grid_config.selection_color,
				color,
				grid_config.brood_progress_ring_width,
				grid_config.brood_progress_ring_color,
				grid_config.brood_damaged_tint,
				grid_config.brood_spent_tint,
				grid_config.assignment_highlight_color
			)
			cells[axial] = cell

			var data := CellData.new()
			data.set_type(cell_type, color)
			data.complex_id = 0
			data.brood_has_egg = false
			data.brood_hatch_remaining = 0.0
			data.brood_state = HexCell.BroodState.IDLE
			_cell_states[axial] = data

	_recompute_complexes([CellType.Type.QUEEN_SEAT])
	_update_buildable_highlights()
	_refresh_assignment_highlights()
	_sync_egg_manager_queen_position()

func _spawn_cursor() -> void:
	if _cursor_node:
		remove_child(_cursor_node)
		_cursor_node.queue_free()
	_cursor_node = cursor_scene.instantiate()
	add_child(_cursor_node)
	_cursor_node.configure(grid_config.cell_size, grid_config.cursor_color)
	_cursor_node.z_index = 10
	_cursor_axial = Vector2i.ZERO
	_update_cursor_position()

func _connect_egg_manager() -> void:
        var egg_manager := _get_egg_manager()
        if not is_instance_valid(egg_manager):
                return
        if egg_manager.egg_assigned.is_connected(_on_egg_assigned):
                return
        egg_manager.egg_assigned.connect(_on_egg_assigned)

func _sync_egg_manager_queen_position() -> void:
        var egg_manager := _get_egg_manager()
        if not is_instance_valid(egg_manager):
                return
        for axial in _cell_states.keys():
                var data: CellData = _cell_states[axial]
                if data.cell_type == CellType.Type.QUEEN_SEAT:
                        egg_manager.set_queen_position(axial.x, axial.y)
                        return

func _connect_bee_manager() -> void:
	if not Engine.has_singleton("BeeManager"):
		return
	_bee_manager = BeeManager
	if _bee_manager.has_method("register_hex_grid"):
		_bee_manager.register_hex_grid(self)
	if not _bee_manager.bee_assigned.is_connected(_on_bee_assigned):
		_bee_manager.bee_assigned.connect(_on_bee_assigned)
	if not _bee_manager.bee_unassigned.is_connected(_on_bee_unassigned):
		_bee_manager.bee_unassigned.connect(_on_bee_unassigned)
	if not _bee_manager.bee_spawned.is_connected(_on_bee_spawned):
		_bee_manager.bee_spawned.connect(_on_bee_spawned)
	_bee_positions.clear()
	var bees: Array = _bee_manager.list_bees()
	for bee in bees:
		if bee.get("state", "") != BeeManager.STATE_ASSIGNED:
			continue
		var assigned_cell = bee.get("assigned_cell")
		if typeof(assigned_cell) != TYPE_VECTOR2I:
			continue
		_bee_positions[bee["id"]] = assigned_cell
		_update_cell_bee_state(assigned_cell)

func move_cursor(delta: Vector2i) -> void:
	var target := _cursor_axial + delta
	if not is_within_grid(target):
		return
	if not _is_cursor_target_allowed(target):
		return
	_cursor_axial = target
	_update_cursor_position()

func get_cursor_axial() -> Vector2i:
	return _cursor_axial

func select_current_hex() -> void:
	if not cells.has(_cursor_axial):
		return
	var cell: HexCell = cells[_cursor_axial]
	cell.toggle_selected()
	if cell.is_selected():
		_selected_cells[_cursor_axial] = cell
	else:
		_selected_cells.erase(_cursor_axial)

func clear_selection() -> void:
	for cell in _selected_cells.values():
		cell.set_selected(false)
	_selected_cells.clear()

func is_within_grid(axial: Vector2i) -> bool:
	if not _ensure_grid_config():
		return false
	return Coord.axial_distance(Vector2i.ZERO, axial) <= grid_config.radius

func _is_cursor_target_allowed(axial: Vector2i) -> bool:
	if not _ensure_grid_config():
		return false

	if not _cell_states.has(axial):
		return false

	var data: CellData = _cell_states[axial]
	if data.cell_type != CellType.Type.EMPTY:
		return true

	if grid_config.allow_isolated_builds:
		return true

	return is_build_adjacent_to_existing(axial.x, axial.y)

func axial_to_world(axial: Vector2i) -> Vector2:
	if not _ensure_grid_config():
		return Vector2.ZERO
	return Coord.axial_to_world(axial, grid_config.cell_size)

func world_to_axial(position: Vector2) -> Vector2i:
	if not _ensure_grid_config():
		return Vector2i.ZERO
	return Coord.world_to_axial(position, grid_config.cell_size)

func is_build_adjacent_to_existing(q: int, r: int) -> bool:
	var axial := Vector2i(q, r)
	for direction: Vector2i in Coord.DIRECTIONS:
		var neighbor := axial + direction
		if not _cell_states.has(neighbor):
			continue
		var neighbor_data: CellData = _cell_states[neighbor]
		if neighbor_data.cell_type != CellType.Type.EMPTY:
			return true
	return false

func try_place_cell(axial: Vector2i, cell_type: int) -> bool:
	if not _cell_states.has(axial):
		_log_build_failure("Cannot build outside the grid.")
		return false
	if CellType.buildable_types().find(cell_type) == -1:
		_log_build_failure("That cell type cannot be constructed.")
		return false
	var data: CellData = _cell_states[axial]
	if data.cell_type == CellType.Type.QUEEN_SEAT:
		_log_build_failure("The queen's seat cannot be replaced.")
		return false
	if data.cell_type != CellType.Type.EMPTY:
		_log_build_failure("This cell already holds a specialized structure.")
		return false
	if not grid_config.allow_isolated_builds and not is_build_adjacent_to_existing(axial.x, axial.y):
		_log_build_failure("Placement blocked: must touch an existing cell")
		return false

	if not grid_config.allow_free_builds:
		var cost := ResourceManager.get_build_cost(cell_type)
		if not ResourceManager.can_pay(cost):
			var type_keys := CellType.Type.keys()
			var type_key := str(cell_type)
			if cell_type >= 0 and cell_type < type_keys.size():
				type_key = String(type_keys[cell_type])
			var balances := ResourceManager.get_balances()
			_log_build_failure("Blocked: need %s to build %s, have %s." % [cost, type_key, balances])
			return false
		ResourceManager.spend(cost)

	var color := grid_config.get_color(cell_type)
	data.set_type(cell_type, color)
	data.brood_has_egg = false
	data.brood_hatch_remaining = 0.0
	data.brood_state = HexCell.BroodState.IDLE
	_active_brood_timers.erase(axial)

	var cell: HexCell = cells.get(axial)
	if cell:
		cell.set_cell_color(color)
		if cell_type == CellType.Type.BROOD:
			cell.set_brood_state(HexCell.BroodState.IDLE, false, 0.0, grid_config.brood_hatch_seconds)
		else:
			cell.clear_brood_state()
		cell.flash()

	if cell_type == CellType.Type.BROOD:
		_request_egg_for_brood(axial, data)

	recompute_brood_enclosures()
	var changed_types: Array[int] = [cell_type]
	if not _last_brood_created.is_empty():
		changed_types.append(CellType.Type.BROOD)
		_last_brood_created.clear()
	_recompute_complexes(changed_types)
	_update_buildable_highlights()
	_refresh_assignment_highlights()
	_emit_bee_slots(axial)
	return true

func get_cell_type(q: int, r: int) -> int:
	var axial := Vector2i(q, r)
	if not _cell_states.has(axial):
		return CellType.Type.EMPTY
	var data: CellData = _cell_states[axial]
	return data.cell_type

func is_brood(q: int, r: int) -> bool:
	return get_cell_type(q, r) == CellType.Type.BROOD

func get_brood_info(q: int, r: int) -> Dictionary:
	var axial := Vector2i(q, r)
	var result := {"has_egg": false, "hatch_remaining": 0.0, "state": HexCell.BroodState.IDLE}
	if not _cell_states.has(axial):
		return result
	var data: CellData = _cell_states[axial]
	if data.cell_type != CellType.Type.BROOD:
		return result
	result["has_egg"] = data.brood_has_egg
	result["hatch_remaining"] = data.brood_hatch_remaining
	result["state"] = data.brood_state
	return result

func is_enclosed_empty(q: int, r: int) -> bool:
	var axial := Vector2i(q, r)
	if not _cell_states.has(axial):
		return false
	var data: CellData = _cell_states[axial]
	if data.cell_type != CellType.Type.EMPTY:
		return false
	if _is_boundary(axial):
		return false

	var visited: Dictionary = {}
	var pending: Array[Vector2i] = [axial]
	while not pending.is_empty():
		var current: Vector2i = pending.pop_back()
		if visited.has(current):
			continue
		visited[current] = true
		if _is_boundary(current):
			return false
		for direction: Vector2i in Coord.DIRECTIONS:
			var neighbor := current + direction
			if not _cell_states.has(neighbor):
				return false
			var neighbor_data: CellData = _cell_states[neighbor]
			if neighbor_data.cell_type == CellType.Type.EMPTY and not visited.has(neighbor):
				pending.append(neighbor)
	return true

func recompute_brood_enclosures() -> void:
	_last_brood_created.clear()
	if not _ensure_grid_config():
		return

	var empty_cells: Dictionary = {}
	var boundary_cells: Array[Vector2i] = []
	for axial in _cell_states.keys():
		var data: CellData = _cell_states[axial]
		if data.cell_type != CellType.Type.EMPTY:
			continue
		empty_cells[axial] = true
		if _is_boundary(axial):
			boundary_cells.append(axial)

	if empty_cells.is_empty():
		return

	var outside: Dictionary = {}
	var queue: Array[Vector2i] = boundary_cells.duplicate()
	while not queue.is_empty():
		var current: Vector2i = queue.pop_back()
		if outside.has(current):
			continue
		outside[current] = true
		for direction: Vector2i in Coord.DIRECTIONS:
			var neighbor := current + direction
			if not empty_cells.has(neighbor):
				continue
			if outside.has(neighbor):
				continue
			queue.append(neighbor)

	var newly_created: Array[Vector2i] = []
	for axial in empty_cells.keys():
		if outside.has(axial):
			continue
		var data: CellData = _cell_states[axial]
		_convert_empty_to_brood(axial, data)
		newly_created.append(axial)

	if newly_created.is_empty():
		return

	_last_brood_created = newly_created.duplicate()
	emit_signal("brood_created", newly_created.duplicate())

func brood_revalidate_on_cell_removed(_q: int, _r: int) -> void:
	## TODO: Future feature - handle brood damage and egg loss when walls break.
	pass

func get_complex_id(q: int, r: int) -> int:
	var axial := Vector2i(q, r)
	if not _cell_states.has(axial):
		return 0
	var data: CellData = _cell_states[axial]
	return data.complex_id

func get_complex_size(complex_id: int) -> int:
	return _complex_sizes.get(complex_id, 0)

func export_cell_types() -> Dictionary:
	var export_data := {}
	for axial in _cell_states.keys():
		var data: CellData = _cell_states[axial]
		export_data[axial] = data.cell_type
	return export_data

func _recompute_complexes(changed_types: Array[int] = []) -> void:
	_complex_sizes.clear()
	for data in _cell_states.values():
		data.complex_id = 0

	var next_complex_id := 1
	for axial in _cell_states.keys():
		var data: CellData = _cell_states[axial]
		if not CellType.is_specialized(data.cell_type):
			continue
		if data.complex_id != 0:
			continue
		var size := _flood_assign_complex(axial, data.cell_type, next_complex_id)
		_complex_sizes[next_complex_id] = size
		next_complex_id += 1

	var unique_types := {}
	for cell_type in changed_types:
		unique_types[cell_type] = true
	if unique_types.is_empty():
		for data in _cell_states.values():
			if CellType.is_specialized(data.cell_type):
				unique_types[data.cell_type] = true
	emit_signal("complexes_updated", unique_types.keys())

func _flood_assign_complex(start_axial: Vector2i, cell_type: int, complex_id: int) -> int:
	var pending: Array[Vector2i] = [start_axial]
	var size := 0
	while pending:
		var current: Vector2i = pending.pop_back()
		if not _cell_states.has(current):
			continue
		var data: CellData = _cell_states[current]
		if data.cell_type != cell_type:
			continue
		if data.complex_id == complex_id:
			continue
		if data.complex_id != 0:
			continue
		data.complex_id = complex_id
		size += 1
		for direction: Vector2i in Coord.DIRECTIONS:
			var neighbor: Vector2i = current + direction
			if not _cell_states.has(neighbor):
				continue
			var neighbor_data: CellData = _cell_states[neighbor]
			if neighbor_data.cell_type == cell_type and neighbor_data.complex_id == 0:
				pending.append(neighbor)
	return size

func _update_cursor_position() -> void:
	if not _cursor_node:
		return
	_cursor_node.position = axial_to_world(_cursor_axial)

func _process(delta: float) -> void:
	if _active_brood_timers.is_empty():
		set_process(false)
		return

	var hatched_cells: Array[Vector2i] = []
	var active_keys: Array = _active_brood_timers.keys()
	for axial_value in active_keys:
		var axial: Vector2i = axial_value
		if not _cell_states.has(axial):
			_active_brood_timers.erase(axial)
			continue
		var data: CellData = _cell_states[axial]
		if data.cell_type != CellType.Type.BROOD or data.brood_state != HexCell.BroodState.INCUBATING:
			_active_brood_timers.erase(axial)
			continue
		data.brood_hatch_remaining = max(0.0, data.brood_hatch_remaining - delta)
		var cell: HexCell = cells.get(axial)
		if cell:
			cell.update_brood_progress(data.brood_hatch_remaining)
		if data.brood_hatch_remaining <= 0.0:
			hatched_cells.append(axial)

	if not hatched_cells.is_empty():
		for axial in hatched_cells:
			_finalize_brood_hatch(axial)
		emit_signal("brood_hatched", hatched_cells.duplicate())

	if _active_brood_timers.is_empty():
		set_process(false)

func _finalize_brood_hatch(axial: Vector2i) -> void:
        if not _cell_states.has(axial):
                return
        var data: CellData = _cell_states[axial]
        data.brood_has_egg = false
        data.brood_hatch_remaining = 0.0
        data.brood_state = HexCell.BroodState.DAMAGED
        _active_brood_timers.erase(axial)

        var cell: HexCell = cells.get(axial)
        if cell:
                cell.set_brood_state(HexCell.BroodState.DAMAGED, false, 0.0, grid_config.brood_hatch_seconds)
                cell.flash()
        emit_signal("brood_state_changed", axial.x, axial.y, HexCell.BroodState.DAMAGED)

        var spawned_id := -1
        if _bee_manager:
                spawned_id = _bee_manager.spawn_bee(axial)
        _emit_bee_slots(axial)
        if spawned_id != -1:
                print("[Bees] Bee #%d spawned from (%d,%d); brood -> Damaged." % [spawned_id, axial.x, axial.y])

func _on_bee_spawned(_bee_id: int) -> void:
	_refresh_assignment_highlights()

func _on_bee_assigned(bee_id: int, q: int, r: int) -> void:
	var axial := Vector2i(q, r)
	if _bee_positions.has(bee_id):
		var previous: Vector2i = _bee_positions[bee_id]
		if previous != axial:
			_update_cell_bee_state(previous)
	_bee_positions[bee_id] = axial
	_update_cell_bee_state(axial)
	_refresh_assignment_highlights()

func _on_bee_unassigned(bee_id: int) -> void:
	if _bee_positions.has(bee_id):
		var previous: Vector2i = _bee_positions[bee_id]
		_bee_positions.erase(bee_id)
		_update_cell_bee_state(previous)
	_refresh_assignment_highlights()

func _log_build_failure(message: String) -> void:
	print("[Build] %s" % message)

func _ensure_grid_config() -> bool:
	if grid_config:
		return true
	grid_config = load("res://resources/GridConfig.tres")
	return grid_config != null

func _update_cell_bee_state(axial: Vector2i) -> void:
	var cell: HexCell = cells.get(axial)
	if not cell:
		return
	var used := get_bee_count(axial.x, axial.y)
	cell.set_bee_present(used > 0)
	_emit_bee_slots(axial)

func _emit_bee_slots(axial: Vector2i) -> void:
        if not _cell_states.has(axial):
                return
        var cap := cell_bee_cap(axial.x, axial.y)
        var used := cell_bee_count(axial.x, axial.y)
        emit_signal("bee_slots_changed", axial.x, axial.y, used, cap)

func set_assignment_highlights_for_spec(spec: String) -> void:
	_current_assignment_spec = spec
	_refresh_assignment_highlights()

func clear_assignment_highlights() -> void:
	_current_assignment_spec = ""
	_clear_assignment_highlights()

func _refresh_assignment_highlights() -> void:
	_clear_assignment_highlights()
	if _current_assignment_spec.is_empty():
		return
	for axial in get_cells_accepting(_current_assignment_spec):
		var cell: HexCell = cells.get(axial)
		if not cell:
			continue
		cell.set_assignment_highlight(true)
		_assignment_highlighted.append(axial)

func _clear_assignment_highlights() -> void:
	for axial in _assignment_highlighted:
		var cell: HexCell = cells.get(axial)
		if cell:
			cell.set_assignment_highlight(false)
	_assignment_highlighted.clear()

func get_bee_cap(q: int, r: int) -> int:
        return cell_bee_cap(q, r)

func get_bee_count(q: int, r: int) -> int:
        return cell_bee_count(q, r)

func get_cell_types_for_specialisation(_spec: String) -> Array:
        ## All non-empty cells are considered eligible in the simplified system.
        var result: Array = []
        for axial in _cell_states.keys():
                var coords: Vector2i = axial
                if cell_is_eligible_for_bee(coords.x, coords.y):
                        var cell_type := get_cell_type(coords.x, coords.y)
                        if not result.has(cell_type):
                                result.append(cell_type)
        return result

func can_accept_bee(_spec: String, q: int, r: int) -> bool:
        if not cell_is_eligible_for_bee(q, r):
                return false
        var cap := cell_bee_cap(q, r)
        if cap <= 0:
                return false
        return cell_bee_count(q, r) < cap

func get_cells_accepting(_spec: String) -> Array[Vector2i]:
        var result: Array[Vector2i] = []
        for axial in _cell_states.keys():
                var coords: Vector2i = axial
                if can_accept_bee("", coords.x, coords.y):
                        result.append(coords)
        return result

func cell_is_eligible_for_bee(q: int, r: int) -> bool:
        var axial := Vector2i(q, r)
        if not _cell_states.has(axial):
                return false
        var data: CellData = _cell_states[axial]
        if data.cell_type == CellType.Type.EMPTY:
                return false
        if not _ensure_grid_config():
                return false
        var disallowed := grid_config.disallowed_bee_cells
        if disallowed.is_empty():
                return true
        var type_keys := CellType.Type.keys()
        var key := str(data.cell_type)
        if data.cell_type >= 0 and data.cell_type < type_keys.size():
                key = String(type_keys[data.cell_type])
        return not disallowed.has(key)

func cell_bee_cap(q: int, r: int) -> int:
        if not cell_is_eligible_for_bee(q, r):
                return 0
        if not _ensure_grid_config():
                return 0
        return max(0, grid_config.default_bee_cap_per_cell)

func cell_bee_count(q: int, r: int) -> int:
        if _bee_manager == null:
                return 0
        return _bee_manager.get_bee_count_for_cell(Vector2i(q, r))

func _set_brood_idle(axial: Vector2i, data: CellData, emit_event: bool = true) -> void:
        data.brood_state = HexCell.BroodState.IDLE
        data.brood_has_egg = false
	data.brood_hatch_remaining = 0.0
	_active_brood_timers.erase(axial)
	var cell: HexCell = cells.get(axial)
	if cell:
		cell.set_brood_state(HexCell.BroodState.IDLE, false, 0.0, grid_config.brood_hatch_seconds)
	if emit_event:
		emit_signal("brood_state_changed", axial.x, axial.y, HexCell.BroodState.IDLE)

func _begin_brood_incubation(axial: Vector2i, data: CellData, emit_event: bool = true) -> void:
	data.brood_state = HexCell.BroodState.INCUBATING
	data.brood_has_egg = true
	data.brood_hatch_remaining = grid_config.brood_hatch_seconds
	_active_brood_timers[axial] = true
	set_process(true)
	var cell: HexCell = cells.get(axial)
	if cell:
		cell.set_brood_state(HexCell.BroodState.INCUBATING, true, data.brood_hatch_remaining, grid_config.brood_hatch_seconds)
		cell.flash()
	if emit_event:
		emit_signal("brood_state_changed", axial.x, axial.y, HexCell.BroodState.INCUBATING)

func _request_egg_for_brood(axial: Vector2i, data: CellData) -> void:
	var egg_manager := _get_egg_manager()
	if not is_instance_valid(egg_manager):
		_set_brood_idle(axial, data)
		return
	if egg_manager.request_egg(axial.x, axial.y):
		_begin_brood_incubation(axial, data)
	else:
		_set_brood_idle(axial, data)

func _on_egg_assigned(q: int, r: int) -> void:
	var axial := Vector2i(q, r)
	var egg_manager := _get_egg_manager()
	if not _cell_states.has(axial):
		if is_instance_valid(egg_manager):
			egg_manager.refund_egg()
		return
	var data: CellData = _cell_states[axial]
	if data.cell_type != CellType.Type.BROOD:
		if is_instance_valid(egg_manager):
			egg_manager.refund_egg()
		return
	if data.brood_state != HexCell.BroodState.IDLE:
		return
	_begin_brood_incubation(axial, data)

func _convert_empty_to_brood(axial: Vector2i, data: CellData) -> void:
	var brood_color := grid_config.get_color(CellType.Type.BROOD)
	data.set_type(CellType.Type.BROOD, brood_color)
	data.complex_id = 0
	data.brood_has_egg = false
	data.brood_hatch_remaining = 0.0
	data.brood_state = HexCell.BroodState.IDLE

	var cell: HexCell = cells.get(axial)
	if cell:
		cell.set_cell_color(brood_color)
	_set_brood_idle(axial, data, false)
	if cell:
		cell.flash()

	_request_egg_for_brood(axial, data)
	_update_buildable_highlights()

func _is_boundary(axial: Vector2i) -> bool:
	if not _ensure_grid_config():
		return false
	var radius := grid_config.radius
	var q := axial.x
	var r := axial.y
	var s := -q - r
	return max(abs(q), max(abs(r), abs(s))) >= radius

func _update_buildable_highlights() -> void:
	if not _ensure_grid_config():
		return

	var highlight_color := grid_config.buildable_highlight_color
	var empty_color := grid_config.get_color(CellType.Type.EMPTY)
	var allow_isolated := grid_config.allow_isolated_builds

	for axial in _cell_states.keys():
		var data: CellData = _cell_states[axial]
		var cell: HexCell = cells.get(axial)
		if not cell:
			continue

		if data.cell_type == CellType.Type.EMPTY:
			var highlight := allow_isolated or is_build_adjacent_to_existing(axial.x, axial.y)
			if highlight:
				cell.set_cell_color(highlight_color)
			else:
				cell.set_cell_color(empty_color)
		else:
			cell.set_cell_color(data.color)
