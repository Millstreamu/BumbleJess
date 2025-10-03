extends Node

## Handles keyboard input and forwards navigation commands to the hex grid.
@export var hex_grid_path: NodePath

const HexGrid := preload("res://scripts/grid/HexGrid.gd")

var _hex_grid: HexGrid

const MOVE_VECTORS := {
    "ui_left": Vector2i(-1, 0),
    "ui_right": Vector2i(1, 0),
    "ui_up": Vector2i(0, -1),
    "ui_down": Vector2i(0, 1),
}

func _ready() -> void:
    if hex_grid_path.is_empty():
        hex_grid_path = NodePath("../HexGrid")
    _hex_grid = get_node_or_null(hex_grid_path)
    if not _hex_grid:
        push_warning("InputController could not find HexGrid node at %s" % hex_grid_path)

func _unhandled_input(event: InputEvent) -> void:
    if not _hex_grid:
        return
    for action in MOVE_VECTORS.keys():
        if event.is_action_pressed(action):
            _hex_grid.move_cursor(MOVE_VECTORS[action])
            get_viewport().set_input_as_handled()
            return
    if event.is_action_pressed("ui_accept"):
        _hex_grid.select_current_hex()
        get_viewport().set_input_as_handled()
