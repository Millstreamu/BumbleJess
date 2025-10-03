extends Node

## Handles keyboard input and forwards navigation and build commands.
@export var hex_grid_path: NodePath
@export var palette_state_path: NodePath

const CellType := preload("res://scripts/core/CellType.gd")
const HexGrid := preload("res://scripts/grid/HexGrid.gd")
const PaletteState := preload("res://scripts/input/PaletteState.gd")

var _hex_grid: HexGrid
var _palette_state: PaletteState
var _pending_build_axial: Vector2i = Vector2i.ZERO
var _has_pending_build: bool = false

const MOVE_VECTORS := {
    "ui_left": Vector2i(-1, 0),
    "ui_right": Vector2i(1, 0),
    "ui_up": Vector2i(0, -1),
    "ui_down": Vector2i(0, 1),
}

func _ready() -> void:
    if hex_grid_path.is_empty():
        hex_grid_path = NodePath("../HexGrid")
    if palette_state_path.is_empty():
        palette_state_path = NodePath("../PaletteState")
    _hex_grid = get_node_or_null(hex_grid_path)
    if not _hex_grid:
        push_warning("InputController could not find HexGrid node at %s" % hex_grid_path)
    _palette_state = get_node_or_null(palette_state_path)
    if not _palette_state:
        push_warning("InputController could not find PaletteState node at %s" % palette_state_path)

func _unhandled_input(event: InputEvent) -> void:
    if not _hex_grid:
        return

    if event is InputEventKey and event.pressed and not event.echo:
        if event.physical_keycode == KEY_Z:
            if _palette_state:
                if _palette_state.is_open:
                    _palette_state.close()
                _has_pending_build = false
                _pending_build_axial = Vector2i.ZERO
                if _palette_state.has_in_hand():
                    _palette_state.clear_in_hand()
            get_viewport().set_input_as_handled()
            return

    if _palette_state and _palette_state.is_open:
        if event.is_action_pressed("ui_left") or event.is_action_pressed("ui_up"):
            _palette_state.move_selection(-1)
            get_viewport().set_input_as_handled()
            return
        if event.is_action_pressed("ui_right") or event.is_action_pressed("ui_down"):
            _palette_state.move_selection(1)
            get_viewport().set_input_as_handled()
            return
        if event.is_action_pressed("ui_accept"):
            var selected_type := _palette_state.confirm_selection()
            if _has_pending_build and selected_type != CellType.Type.EMPTY:
                var placed := _hex_grid.try_place_cell(_pending_build_axial, selected_type)
                if placed:
                    _hex_grid.clear_selection()
            if _palette_state.has_in_hand():
                _palette_state.clear_in_hand()
            _has_pending_build = false
            _pending_build_axial = Vector2i.ZERO
            get_viewport().set_input_as_handled()
            return
        return

    if event.is_action_pressed("ui_accept"):
        if _palette_state:
            _pending_build_axial = _hex_grid.get_cursor_axial()
            _has_pending_build = true
            _palette_state.open()
        get_viewport().set_input_as_handled()
        return

    for action in MOVE_VECTORS.keys():
        if event.is_action_pressed(action):
            _hex_grid.move_cursor(MOVE_VECTORS[action])
            get_viewport().set_input_as_handled()
            return
