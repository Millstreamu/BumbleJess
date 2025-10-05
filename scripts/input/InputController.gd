extends Node

## Handles keyboard input and forwards navigation and build commands.
@export var hex_grid_path: NodePath
@export var palette_state_path: NodePath
@export var bee_roster_path: NodePath
@export var assign_bee_picker_path: NodePath

const CellType := preload("res://scripts/core/CellType.gd")
const HexGrid := preload("res://scripts/grid/HexGrid.gd")
const PaletteState := preload("res://scripts/input/PaletteState.gd")
const BeeRoster := preload("res://scripts/ui/BeeRoster.gd")
const AssignBeePicker := preload("res://scripts/ui/AssignBeePicker.gd")

var _hex_grid: HexGrid
var _palette_state: PaletteState
var _bee_roster: BeeRoster
var _assign_picker: AssignBeePicker
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
	if bee_roster_path.is_empty():
		bee_roster_path = NodePath("../BeeRoster")
	_bee_roster = get_node_or_null(bee_roster_path)
	if not _bee_roster:
		push_warning("InputController could not find BeeRoster node at %s" % bee_roster_path)
	if assign_bee_picker_path.is_empty():
		assign_bee_picker_path = NodePath("../AssignBeePicker")
	_assign_picker = get_node_or_null(assign_bee_picker_path)
	if not _assign_picker:
		push_warning("InputController could not find AssignBeePicker node at %s" % assign_bee_picker_path)

func _unhandled_input(event: InputEvent) -> void:
	if not _hex_grid:
		return

	if event is InputEventKey and event.pressed and not event.echo:
		if _assign_picker and _assign_picker.is_open():
			if _assign_picker.handle_input(event):
				get_viewport().set_input_as_handled()
				return
		if event.physical_keycode == KEY_TAB:
			if _bee_roster:
				if _bee_roster.is_open():
					_bee_roster.close()
				else:
					if _palette_state and _palette_state.is_open:
						_palette_state.close()
					_bee_roster.open()
			get_viewport().set_input_as_handled()
			return
		if event.physical_keycode == KEY_SPACE:
			if not (_bee_roster and _bee_roster.is_open()):
				if _try_open_assign_picker():
					get_viewport().set_input_as_handled()
					return
		if event.physical_keycode == KEY_Z:
			if not (_bee_roster and _bee_roster.is_open()):
				if _assign_picker and _assign_picker.is_open():
					if _assign_picker.handle_input(event):
						get_viewport().set_input_as_handled()
						return
				if _try_unassign_current_cell():
					get_viewport().set_input_as_handled()
					return
				if _palette_state:
					if _palette_state.is_open:
						_palette_state.close()
					_has_pending_build = false
					_pending_build_axial = Vector2i.ZERO
					if _palette_state.has_in_hand():
						_palette_state.clear_in_hand()
				get_viewport().set_input_as_handled()
				return

	if _bee_roster and _bee_roster.is_open():
		var roster_handled := _bee_roster.handle_input(event)
		if _bee_roster.consume_assignment_request():
			var axial := _hex_grid.get_cursor_axial()
			_bee_roster.try_assign_to_cell(axial)
			get_viewport().set_input_as_handled()
			return
		if roster_handled:
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

	if _assign_picker and _assign_picker.is_open():
		if _assign_picker.handle_input(event):
			get_viewport().set_input_as_handled()
			return

	if event.is_action_pressed("ui_accept"):
		if _bee_roster and _bee_roster.is_assignment_armed():
			var target := _hex_grid.get_cursor_axial()
			_bee_roster.try_assign_to_cell(target)
			get_viewport().set_input_as_handled()
			return
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

func _try_open_assign_picker() -> bool:
	if not _hex_grid or not _assign_picker:
		return false
	var axial := _hex_grid.get_cursor_axial()
	if not _hex_grid.cell_is_eligible_for_bee(axial.x, axial.y):
		print("[Bees] No slot available at (%d,%d)." % [axial.x, axial.y])
		return true
	var cap := _hex_grid.cell_bee_cap(axial.x, axial.y)
	var used := _hex_grid.cell_bee_count(axial.x, axial.y)
	if used >= cap:
		print("[Bees] No slot available at (%d,%d)." % [axial.x, axial.y])
		return true
	_assign_picker.open_for_cell(axial)
	return true

func _try_unassign_current_cell() -> bool:
	if not _hex_grid:
		return false
	var axial := _hex_grid.get_cursor_axial()
	if _hex_grid.cell_bee_count(axial.x, axial.y) <= 0:
		return false
	if not Engine.has_singleton("BeeManager"):
		return false
	var bee_id := BeeManager.get_last_assigned_bee_for_cell(axial)
	if bee_id == -1:
		return false
	BeeManager.unassign_from_cell(bee_id)
	print("[Bees] Bee #%d unassigned from (%d,%d)." % [bee_id, axial.x, axial.y])
	return true
