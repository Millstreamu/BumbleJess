extends Node

## Handles keyboard input and forwards navigation and build commands.
@export var hex_grid_path: NodePath
@export var palette_state_path: NodePath

const HexGrid := preload("res://scripts/grid/HexGrid.gd")
const PaletteState := preload("res://scripts/input/PaletteState.gd")

var _hex_grid: HexGrid
var _palette_state: PaletteState

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
        if event.physical_keycode == KEY_TAB:
            if _palette_state:
                _palette_state.toggle_open()
            get_viewport().set_input_as_handled()
            return
        if event.physical_keycode == KEY_Z:
            if _palette_state:
                if _palette_state.is_open:
                    _palette_state.close()
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
            _palette_state.confirm_selection()
            get_viewport().set_input_as_handled()
            return
        return

    for action in MOVE_VECTORS.keys():
        if event.is_action_pressed(action):
            _hex_grid.move_cursor(MOVE_VECTORS[action])
            get_viewport().set_input_as_handled()
            return

    if event.is_action_pressed("ui_accept"):
        if _palette_state and _palette_state.has_in_hand():
            var placed := _hex_grid.try_place_cell(_hex_grid.get_cursor_axial(), _palette_state.get_in_hand_type())
            if placed:
                _hex_grid.clear_selection()
        else:
            _hex_grid.select_current_hex()
        get_viewport().set_input_as_handled()
