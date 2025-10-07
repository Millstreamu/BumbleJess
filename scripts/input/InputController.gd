extends Node

## Handles keyboard input and forwards navigation and build commands.
@export var hex_grid_path: NodePath
@export var run_state_path: NodePath
@export var turn_controller_path: NodePath

const HexGrid := preload("res://scripts/grid/HexGrid.gd")
const RunStateController := preload("res://scripts/core/RunState.gd")
const TurnController := preload("res://src/systems/TurnController.gd")

var _hex_grid: HexGrid
var _run_state: RunStateController
var _turn_controller: TurnController

const MOVE_VECTORS := {
		"ui_left": Vector2i(-1, 0),
		"ui_right": Vector2i(1, 0),
		"ui_up": Vector2i(0, -1),
		"ui_down": Vector2i(0, 1),
}

func _ready() -> void:
		if hex_grid_path.is_empty():
				hex_grid_path = NodePath("../HexGrid")
		if run_state_path.is_empty():
				run_state_path = NodePath("../RunState")
		if turn_controller_path.is_empty():
				turn_controller_path = NodePath("../TurnController")

		_hex_grid = get_node_or_null(hex_grid_path)
		if not _hex_grid:
				push_warning("InputController could not find HexGrid node at %s" % hex_grid_path)
		_run_state = get_node_or_null(run_state_path)
		if not _run_state:
				push_warning("InputController could not find RunState node at %s" % run_state_path)
		_turn_controller = get_node_or_null(turn_controller_path)
		if not _turn_controller:
				push_warning("InputController could not find TurnController node at %s" % turn_controller_path)

func _unhandled_input(event: InputEvent) -> void:
		if not _hex_grid:
				return

		if event is InputEventKey and event.pressed and not event.echo:
				if event.physical_keycode == KEY_TAB:
						if _run_state:
								_run_state.toggle_info_panel()
						get_viewport().set_input_as_handled()
						return

				if event.is_action_pressed("ui_accept"):
						if _turn_controller and _turn_controller.is_in_review:
								get_viewport().set_input_as_handled()
								return
						if _run_state and not _run_state.is_deck_empty():
								var axial := _hex_grid.get_cursor_axial()
								_hex_grid.clear_all_highlights()
								var placed: bool = _run_state.try_place_tile(axial)
								if not placed:
										_hex_grid.highlight_cell(axial, true)
						elif _run_state and _run_state.is_deck_empty():
								print("[Run] The deck is empty. Reset the run to continue.")
						get_viewport().set_input_as_handled()
						return

		for action in MOVE_VECTORS.keys():
				if event.is_action_pressed(action):
						_hex_grid.move_cursor(MOVE_VECTORS[action])
						_hex_grid.clear_all_highlights()
						get_viewport().set_input_as_handled()
						return
