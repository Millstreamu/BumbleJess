extends Node

## Handles keyboard input and forwards navigation and build commands.
@export var hex_grid_path: NodePath
@export var palette_state_path: NodePath
@export var run_state_path: NodePath

const CellType := preload("res://scripts/core/CellType.gd")
const HexGrid := preload("res://scripts/grid/HexGrid.gd")
const PaletteState := preload("res://scripts/input/PaletteState.gd")
const RunState := preload("res://scripts/core/RunState.gd")

var _hex_grid: HexGrid
var _palette_state: PaletteState
var _run_state: RunState
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
    if run_state_path.is_empty():
        run_state_path = NodePath("../RunState")

    _hex_grid = get_node_or_null(hex_grid_path)
    if not _hex_grid:
        push_warning("InputController could not find HexGrid node at %s" % hex_grid_path)
    _palette_state = get_node_or_null(palette_state_path)
    if not _palette_state:
        push_warning("InputController could not find PaletteState node at %s" % palette_state_path)
    _run_state = get_node_or_null(run_state_path)
    if not _run_state:
        push_warning("InputController could not find RunState node at %s" % run_state_path)

func _unhandled_input(event: InputEvent) -> void:
    if not _hex_grid:
        return

    if event is InputEventKey and event.pressed and not event.echo:
        if event.physical_keycode == KEY_TAB:
            if _run_state:
                _run_state.toggle_info_panel()
            get_viewport().set_input_as_handled()
            return
        if event.physical_keycode == KEY_Z:
            _cancel_pending_build()
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
            var selected_type: int = _palette_state.confirm_selection()
            if selected_type != CellType.Type.EMPTY and _has_pending_build and _run_state:
                var placed := _run_state.try_place_tile(_pending_build_axial, selected_type)
                if placed:
                    _has_pending_build = false
                    if _palette_state and _palette_state.has_in_hand():
                        _palette_state.clear_in_hand()
                    if _hex_grid:
                        _hex_grid.clear_all_highlights()
            get_viewport().set_input_as_handled()
            return
        if event.is_action_pressed("ui_cancel"):
            _cancel_pending_build()
            get_viewport().set_input_as_handled()
            return
        return

    if event.is_action_pressed("ui_accept"):
        if _palette_state and _run_state and not _run_state.is_deck_empty():
            _pending_build_axial = _hex_grid.get_cursor_axial()
            _has_pending_build = true
            _hex_grid.clear_all_highlights()
            _hex_grid.highlight_cell(_pending_build_axial, true)
            _palette_state.open()
        elif _run_state and _run_state.is_deck_empty():
            print("[Run] The deck is empty. Reset the run to continue.")
        get_viewport().set_input_as_handled()
        return

    for action in MOVE_VECTORS.keys():
        if event.is_action_pressed(action):
            _hex_grid.move_cursor(MOVE_VECTORS[action])
            if _has_pending_build:
                _pending_build_axial = _hex_grid.get_cursor_axial()
                _hex_grid.clear_all_highlights()
                _hex_grid.highlight_cell(_pending_build_axial, true)
            get_viewport().set_input_as_handled()
            return

func _cancel_pending_build() -> void:
    if _palette_state and _palette_state.is_open:
        _palette_state.close()
    if _palette_state and _palette_state.has_in_hand():
        _palette_state.clear_in_hand()
    _has_pending_build = false
    if _hex_grid:
        _hex_grid.clear_all_highlights()
