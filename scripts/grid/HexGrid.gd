extends Node2D

## Primary controller for the hex grid. Responsible for generating cells,
## managing the cursor, cell data, growth, and connectivity checks.
class_name HexGrid

const Coord := preload("res://scripts/core/Coord.gd")
const HexCell := preload("res://scripts/grid/HexCell.gd")
const HexCursor := preload("res://scripts/grid/HexCursor.gd")
const CellType := preload("res://scripts/core/CellType.gd")
const CellData := preload("res://scripts/core/CellData.gd")
signal tile_placed(axial: Vector2i, cell_type: int)
signal overgrowth_created(cells: Array[Vector2i])
signal grove_bloomed(cells: Array[Vector2i])

@export var grid_config: GridConfig
@export var cell_scene: PackedScene = preload("res://scenes/HexCell.tscn")
@export var cursor_scene: PackedScene = preload("res://scenes/HexCursor.tscn")

var cells: Dictionary[Vector2i, HexCell] = {}
var _cell_states: Dictionary[Vector2i, CellData] = {}
var _cursor_node: HexCursor
var _cursor_axial: Vector2i = Vector2i.ZERO

func _ready() -> void:
	if not _ensure_grid_config():
		push_error("HexGrid could not load a GridConfig resource")
		return
	_generate_grid()
	_spawn_cursor()

func _ensure_grid_config() -> bool:
	if grid_config:
		return true
	return false

func _generate_grid() -> void:
	for child in get_children():
		if child is HexCell:
			remove_child(child)
			child.queue_free()
	cells.clear()
	_cell_states.clear()

	if not _ensure_grid_config():
		return

	var radius := grid_config.radius
	for q in range(-radius, radius + 1):
		for r in range(-radius, radius + 1):
			if abs(q + r) > radius:
				continue
			var axial := Vector2i(q, r)
			var cell: HexCell = cell_scene.instantiate()
			add_child(cell)
			cell.position = Coord.axial_to_world(axial, grid_config.cell_size)
			var cell_type := CellType.Type.EMPTY
			if axial == Vector2i.ZERO:
				cell_type = CellType.Type.TOTEM
			var color := grid_config.get_color(cell_type)
			cell.configure(axial, grid_config.cell_size, grid_config.selection_color, color)
			cells[axial] = cell

                        var data: CellData = CellData.new()
			data.set_type(cell_type, color)
			if cell_type == CellType.Type.TOTEM:
				data.variant_id = "totem_default"
			_cell_states[axial] = data

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

func move_cursor(delta: Vector2i) -> void:
	var target := _cursor_axial + delta
	if not is_within_grid(target):
		return
	_cursor_axial = target
	_update_cursor_position()

func get_cursor_axial() -> Vector2i:
	return _cursor_axial

func axial_to_world(axial: Vector2i) -> Vector2:
	if not _ensure_grid_config():
		return Vector2.ZERO
	return Coord.axial_to_world(axial, grid_config.cell_size)

func world_to_axial(position: Vector2) -> Vector2i:
	if not _ensure_grid_config():
		return Vector2i.ZERO
	return Coord.world_to_axial(position, grid_config.cell_size)

func is_within_grid(axial: Vector2i) -> bool:
	if not _ensure_grid_config():
		return false
	return Coord.axial_distance(Vector2i.ZERO, axial) <= grid_config.radius

func get_cell_type_at(axial: Vector2i) -> int:
	var data: CellData = _cell_states.get(axial)
	if data:
		return data.cell_type
	return CellType.Type.EMPTY

func get_cell_data(axial: Vector2i) -> CellData:
	return _cell_states.get(axial)

func get_neighbors(axial: Vector2i) -> Array[Vector2i]:
        var result: Array[Vector2i] = []
        for direction: Vector2i in Coord.DIRECTIONS:
                var neighbor: Vector2i = axial + direction
                if _cell_states.has(neighbor):
                        result.append(neighbor)
        return result

func get_cells_of_type(cell_type: int) -> Array[Vector2i]:
	var positions: Array[Vector2i] = []
	for axial in _cell_states.keys():
		var data: CellData = _cell_states[axial]
		if data.cell_type == cell_type:
			positions.append(axial)
	return positions

func count_neighbors_of_type(axial: Vector2i, cell_type: int) -> int:
        var count := 0
        for neighbor: Vector2i in get_neighbors(axial):
                if get_cell_type_at(neighbor) == cell_type:
                        count += 1
        return count

func highlight_cell(axial: Vector2i, selected: bool) -> void:
	var cell: HexCell = cells.get(axial)
	if cell:
		cell.set_selected(selected)

func clear_all_highlights() -> void:
	for cell in cells.values():
		if cell is HexCell:
			(cell as HexCell).set_selected(false)

func try_place_tile(axial: Vector2i, cell_type: int, variant_id: String = "") -> bool:
	if not _cell_states.has(axial):
		_log_build_failure("Cannot build outside the grid.")
		return false
	if not CellType.is_placeable(cell_type):
		_log_build_failure("That tile type cannot be constructed.")
		return false
	var data: CellData = _cell_states[axial]
	if data.cell_type == CellType.Type.TOTEM:
		_log_build_failure("The totem cannot be replaced.")
		return false
	if data.cell_type != CellType.Type.EMPTY:
		_log_build_failure("This cell is already occupied.")
		return false
	if not grid_config.allow_isolated_builds and not _is_connected_to_network(axial):
		_log_build_failure("Placement blocked: tiles must connect to the forest network.")
		return false

	var color := grid_config.get_color(cell_type)
	data.set_type(cell_type, color)
	data.variant_id = variant_id
	data.sprout_capacity = 0
	data.decay_timer = 0
	var cell: HexCell = cells.get(axial)
	if cell:
		cell.set_cell_color(color)
		cell.set_sprout_count(0)
		cell.show_grove_badge(false)
		cell.set_growth_progress(0, 0, false)
		cell.flash()

	_recompute_overgrowth()
	emit_signal("tile_placed", axial, cell_type)
	return true

func process_turn() -> Dictionary:
	var matured: Array[Vector2i] = _advance_overgrowth()
	if not matured.is_empty():
		emit_signal("grove_bloomed", matured.duplicate())
	return {
		"groves_bloomed": matured,
	}

func get_total_sprouts() -> int:
        var total := 0
        for data: CellData in _cell_states.values():
                total += data.sprout_count
        return total

func collect_clusters(cell_type: int) -> Array:
        var clusters: Array = []
        var visited: Dictionary[Vector2i, bool] = {}
	for axial in _cell_states.keys():
		var data: CellData = _cell_states[axial]
		if data.cell_type != cell_type:
			continue
		if visited.has(axial):
			continue
                var cluster: Array[Vector2i] = []
                var pending: Array[Vector2i] = [axial]
                while not pending.is_empty():
                        var current: Vector2i = pending.pop_back()
                        if visited.has(current):
                                continue
                        visited[current] = true
                        cluster.append(current)
                        for neighbor: Vector2i in get_neighbors(current):
                                if visited.has(neighbor):
                                        continue
                                if get_cell_type_at(neighbor) == cell_type:
                                        pending.append(neighbor)
		if not cluster.is_empty():
			clusters.append(cluster)
	return clusters

func _update_cursor_position() -> void:
	if not _cursor_node:
		return
	_cursor_node.position = axial_to_world(_cursor_axial)

func _is_connected_to_network(axial: Vector2i) -> bool:
        for neighbor: Vector2i in get_neighbors(axial):
                var neighbor_type: int = get_cell_type_at(neighbor)
                if CellType.is_network_member(neighbor_type):
                        return true
        return false

func _recompute_overgrowth() -> void:
	var empty_cells: Array[Vector2i] = []
	for axial in _cell_states.keys():
		var data: CellData = _cell_states[axial]
		if data.cell_type == CellType.Type.EMPTY:
			empty_cells.append(axial)
		elif data.cell_type == CellType.Type.OVERGROWTH:
			# Reset timers to ensure they continue maturing.
			data.growth_duration = grid_config.overgrowth_maturation_turns
			if data.growth_timer <= 0:
				data.growth_timer = grid_config.overgrowth_maturation_turns
	if empty_cells.is_empty():
		return

        var boundary: Array[Vector2i] = []
        for axial in empty_cells:
                if _is_boundary(axial):
                        boundary.append(axial)

        var outside: Dictionary[Vector2i, bool] = {}
        var queue: Array[Vector2i] = boundary.duplicate()
        while not queue.is_empty():
                var current: Vector2i = queue.pop_back()
                if outside.has(current):
                        continue
                outside[current] = true
                for direction: Vector2i in Coord.DIRECTIONS:
                        var neighbor: Vector2i = current + direction
                        if not _cell_states.has(neighbor):
                                continue
                        var neighbor_data: CellData = _cell_states[neighbor]
			if neighbor_data.cell_type != CellType.Type.EMPTY:
				continue
			if outside.has(neighbor):
				continue
			queue.append(neighbor)

	var newly_overgrown: Array[Vector2i] = []
	for axial in empty_cells:
		if outside.has(axial):
			continue
		var data: CellData = _cell_states[axial]
		_convert_to_overgrowth(axial, data)
		newly_overgrown.append(axial)

	if not newly_overgrown.is_empty():
		emit_signal("overgrowth_created", newly_overgrown)

func _convert_to_overgrowth(axial: Vector2i, data: CellData) -> void:
	data.cell_type = CellType.Type.OVERGROWTH
	data.color = grid_config.get_color(CellType.Type.OVERGROWTH)
	data.growth_duration = grid_config.overgrowth_maturation_turns
	data.growth_timer = grid_config.overgrowth_maturation_turns
	var cell: HexCell = cells.get(axial)
	if cell:
		cell.set_cell_color(data.color)
		cell.set_sprout_count(0)
		cell.show_grove_badge(false)
		cell.set_growth_progress(0, data.growth_duration, true)

func _advance_overgrowth() -> Array[Vector2i]:
	var matured: Array[Vector2i] = []
	for axial in _cell_states.keys():
		var data: CellData = _cell_states[axial]
		if data.cell_type != CellType.Type.OVERGROWTH:
			continue
		if data.growth_duration <= 0:
			data.growth_duration = grid_config.overgrowth_maturation_turns
		if data.growth_timer <= 0:
			data.growth_timer = grid_config.overgrowth_maturation_turns
		else:
			data.growth_timer = max(0, data.growth_timer - 1)
		var elapsed := data.growth_duration - data.growth_timer
		var cell: HexCell = cells.get(axial)
		if cell:
			cell.set_growth_progress(elapsed, data.growth_duration, true)
		if data.growth_timer <= 0:
			data.cell_type = CellType.Type.GROVE
			data.color = grid_config.get_color(CellType.Type.GROVE)
			data.sprout_count = grid_config.grove_spawn_count
			data.growth_duration = 0
			data.growth_timer = 0
			matured.append(axial)
			if cell:
				cell.set_cell_color(data.color)
				cell.set_growth_progress(0, 0, false)
				cell.show_grove_badge(true)
				cell.set_sprout_count(data.sprout_count)
				cell.flash()
	return matured

func _is_boundary(axial: Vector2i) -> bool:
	if not is_within_grid(axial):
		return true
	return Coord.axial_distance(Vector2i.ZERO, axial) == grid_config.radius

func _log_build_failure(message: String) -> void:
	push_warning("[Grid] %s" % message)
