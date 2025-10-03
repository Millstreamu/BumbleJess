extends Node2D

## Primary controller for the hex grid. Responsible for generating cells,
## managing the cursor, and offering helper conversion functions.
class_name HexGrid

const Coord := preload("res://scripts/core/Coord.gd")
const HexCell := preload("res://scripts/grid/HexCell.gd")
const HexCursor := preload("res://scripts/grid/HexCursor.gd")

@export var grid_config: GridConfig
@export var cell_scene: PackedScene = preload("res://scenes/HexCell.tscn")
@export var cursor_scene: PackedScene = preload("res://scenes/HexCursor.tscn")

var cells: Dictionary = {}
var _cursor_axial: Vector2i = Vector2i.ZERO
var _cursor_node: HexCursor
var _selected_cells: Dictionary = {}

func _ready() -> void:
    if not _ensure_grid_config():
        push_error("HexGrid could not load a GridConfig resource")
        return
    _generate_grid()
    _spawn_cursor()

func _generate_grid() -> void:
    if not _ensure_grid_config():
        return
    for child in get_children():
        if child is HexCell:
            remove_child(child)
            child.queue_free()
    cells.clear()

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
            var is_queen := axial == Vector2i.ZERO
            cell.configure(axial, grid_config.cell_size, grid_config.cell_color, grid_config.selection_color, grid_config.queen_color, is_queen)
            cells[axial] = cell

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

func select_current_hex() -> void:
    if not cells.has(_cursor_axial):
        return
    var cell: HexCell = cells[_cursor_axial]
    cell.toggle_selected()
    if cell.is_selected():
        _selected_cells[_cursor_axial] = cell
    else:
        _selected_cells.erase(_cursor_axial)

func is_within_grid(axial: Vector2i) -> bool:
    if not _ensure_grid_config():
        return false
    return Coord.axial_distance(Vector2i.ZERO, axial) <= grid_config.radius

func axial_to_world(axial: Vector2i) -> Vector2:
    if not _ensure_grid_config():
        return Vector2.ZERO
    return Coord.axial_to_world(axial, grid_config.cell_size)

func world_to_axial(position: Vector2) -> Vector2i:
    if not _ensure_grid_config():
        return Vector2i.ZERO
    return Coord.world_to_axial(position, grid_config.cell_size)

func _update_cursor_position() -> void:
    if not _cursor_node:
        return
    _cursor_node.global_position = axial_to_world(_cursor_axial)

func _ensure_grid_config() -> bool:
    if grid_config:
        return true
    grid_config = load("res://resources/GridConfig.tres")
    return grid_config != null
