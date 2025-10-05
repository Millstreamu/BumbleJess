extends Control
## Keyboard-driven roster for managing bees and their assignments.
class_name BeeRoster

const CellType := preload("res://scripts/core/CellType.gd")

const SPECIALISATIONS := [
	"GATHER",
	"BREWER",
	"CONSTRUCTION",
	"GUARD",
	"ARCANIST",
]

@export var hex_grid_path: NodePath

@onready var _bee_list: ItemList = $Panel/Margin/VBox/BeeList
@onready var _spec_label: Label = $Panel/Margin/VBox/SpecLabel
@onready var _status_label: Label = $Panel/Margin/VBox/Status
@onready var _viewport: Viewport = get_viewport()

var _hex_grid: Node = null
var _is_open := false
var _bee_ids: Array[int] = []
var _selected_bee_id: int = -1
var _spec_picker_active := false
var _spec_picker_index := 0
var _pending_assignment := false
var _assignment_armed := false

func _ready() -> void:
	visible = false
	if hex_grid_path.is_empty():
		hex_grid_path = NodePath("../HexGrid")
	_hex_grid = get_node_or_null(hex_grid_path)
	_bee_list.item_selected.connect(_on_item_selected)
	_bee_list.multi_selected.connect(_on_item_selected)
	_connect_bee_signals()

	if _viewport:
		_viewport.connect("size_changed", Callable(self, "_center_on_screen"))
	call_deferred("_center_on_screen")

func open() -> void:
	_is_open = true
	visible = true
	_spec_picker_active = false
	_pending_assignment = false
	_refresh_roster()
	_set_status("")
	_update_assignment_highlight()

func close() -> void:
	_is_open = false
	visible = false
	_spec_picker_active = false
	_pending_assignment = false
	if _hex_grid:
		_hex_grid.clear_assignment_highlights()

func is_open() -> bool:
	return _is_open

func handle_input(event: InputEvent) -> bool:
	if not _is_open:
		return false
	if not (event is InputEventKey and event.pressed and not event.echo):
		return false
	var key: Key = event.physical_keycode
	if _spec_picker_active:
		if key == KEY_LEFT:
			_cycle_spec(-1)
			return true
		if key == KEY_RIGHT:
			_cycle_spec(1)
			return true
		if key == KEY_SPACE:
			_confirm_spec()
			return true
		if key == KEY_Z:
			_cancel_spec_picker()
			return true
		return false

	match key:
		KEY_UP:
			_move_selection(-1)
			return true
		KEY_DOWN:
			_move_selection(1)
			return true
		KEY_SPACE:
			if _assignment_armed and _selected_bee_id != -1:
				_pending_assignment = true
				_assignment_armed = false
				return false
			_begin_spec_picker()
			return true
		KEY_Z:
			return _handle_unassign()
	return false

func consume_assignment_request() -> bool:
	var requested := _pending_assignment
	_pending_assignment = false
	return requested

func try_assign_to_cell(axial: Vector2i) -> bool:
	if _selected_bee_id == -1:
		_set_status("Select a bee first.")
		return false
	if not Engine.has_singleton("BeeManager"):
		_set_status("Bee manager unavailable.")
		return false
	var bee := BeeManager.get_bee(_selected_bee_id)
	if bee.is_empty():
		_set_status("Bee data unavailable.")
		_assignment_armed = false
		return false
        if _hex_grid:
                var cell_type: int = _hex_grid.get_cell_type(axial.x, axial.y)
                if not _hex_grid.cell_is_eligible_for_bee(axial.x, axial.y):
                        _set_status("%s cannot house bees." % CellType.to_display_name(cell_type))
                        _assignment_armed = false
                        _update_assignment_highlight()
                        return false
                var cap: int = _hex_grid.cell_bee_cap(axial.x, axial.y)
                if cap <= 0:
                        _set_status("%s cannot house bees." % CellType.to_display_name(cell_type))
                        _assignment_armed = false
                        _update_assignment_highlight()
                        return false
                if _hex_grid.cell_bee_count(axial.x, axial.y) >= cap:
                        _set_status("%s at (%d,%d) is already full." % [CellType.to_display_name(cell_type), axial.x, axial.y])
                        _assignment_armed = false
                        _update_assignment_highlight()
                        return false
	var success := BeeManager.assign_to_cell(_selected_bee_id, axial.x, axial.y)
	if success:
		_set_status("Bee #%d assigned to (%d,%d)." % [_selected_bee_id, axial.x, axial.y])
	else:
		_set_status("Assignment failed.")
	_assignment_armed = false
	_update_assignment_highlight()
	return success

func get_selected_bee_id() -> int:
	return _selected_bee_id

func is_assignment_armed() -> bool:
	return _assignment_armed and _selected_bee_id != -1

func _center_on_screen() -> void:
	if not _viewport:
		return
	var viewport_size := _viewport.get_visible_rect().size
	position = viewport_size * 0.5 - size * 0.5

func _connect_bee_signals() -> void:
	if not Engine.has_singleton("BeeManager"):
		return
	if not BeeManager.bee_spawned.is_connected(_on_bee_list_changed):
		BeeManager.bee_spawned.connect(_on_bee_list_changed)
	if not BeeManager.bee_assigned.is_connected(_on_bee_list_changed):
		BeeManager.bee_assigned.connect(_on_bee_list_changed)
	if not BeeManager.bee_unassigned.is_connected(_on_bee_list_changed):
		BeeManager.bee_unassigned.connect(_on_bee_list_changed)
	if not BeeManager.bee_specialisation_changed.is_connected(_on_bee_list_changed):
		BeeManager.bee_specialisation_changed.connect(_on_bee_list_changed)

func _on_bee_list_changed(_a = null, _b = null, _c = null) -> void:
	_refresh_roster()
	if _is_open:
		_update_assignment_highlight()

func _refresh_roster() -> void:
	_bee_list.clear()
	_bee_ids.clear()
	if not Engine.has_singleton("BeeManager"):
		_selected_bee_id = -1
		_spec_label.text = "Specialisation: —"
		return
	var bees := BeeManager.list_bees()
	var previous_id := _selected_bee_id
	for bee in bees:
		var bee_id: int = bee.get("id", 0)
		_bee_ids.append(bee_id)
		var state: String = bee.get("state", "UNASSIGNED")
		var spec: String = bee.get("specialisation", "GATHER")
		var assigned_cell = bee.get("assigned_cell")
		var location := "Unassigned"
		if state == BeeManager.STATE_ASSIGNED and typeof(assigned_cell) == TYPE_VECTOR2I:
			var coords: Vector2i = assigned_cell
			location = "(%d,%d)" % [coords.x, coords.y]
		var label := "Bee #%d  %s  [%s]  %s" % [bee_id, state.capitalize(), _format_spec(spec), location]
		var index := _bee_list.add_item(label)
		if state == BeeManager.STATE_ASSIGNED:
			_bee_list.set_item_custom_fg_color(index, Color(0.9, 0.85, 0.6, 1.0))
	if _bee_ids.is_empty():
		_selected_bee_id = -1
		_spec_label.text = "Specialisation: —"
		_assignment_armed = false
		return
	var selection_changed := true
	if previous_id != -1 and _bee_ids.has(previous_id):
		_selected_bee_id = previous_id
		selection_changed = false
	else:
		_selected_bee_id = _bee_ids[0]
		selection_changed = true
	var selected_index := _bee_ids.find(_selected_bee_id)
	if selected_index >= 0:
		_bee_list.select(selected_index)
		_bee_list.ensure_current_is_visible()
	if selection_changed:
		_assignment_armed = false
	_update_selected_bee_info()

func _move_selection(delta: int) -> void:
	if _bee_ids.is_empty():
		return
	var index := _bee_ids.find(_selected_bee_id)
	if index == -1:
		index = 0
	index = clamp(index + delta, 0, _bee_ids.size() - 1)
	_bee_list.select(index)
	_bee_list.ensure_current_is_visible()
	_selected_bee_id = _bee_ids[index]
	if _spec_picker_active:
		_cancel_spec_picker()
	_assignment_armed = false
	_update_selected_bee_info()

func _begin_spec_picker() -> void:
	if _selected_bee_id == -1:
		return
	if not Engine.has_singleton("BeeManager"):
		return
	var bee := BeeManager.get_bee(_selected_bee_id)
	if bee.is_empty():
		return
	_spec_picker_active = true
	_assignment_armed = false
	var current_spec: String = bee.get("specialisation", "GATHER")
	_spec_picker_index = max(0, SPECIALISATIONS.find(current_spec))
	_update_spec_picker_label()
	_set_status("Pick specialisation: ←/→ change, Space confirm, Z cancel")

func _cycle_spec(delta: int) -> void:
	_spec_picker_index = (_spec_picker_index + delta) % SPECIALISATIONS.size()
	if _spec_picker_index < 0:
		_spec_picker_index = SPECIALISATIONS.size() - 1
	_update_spec_picker_label()

func _confirm_spec() -> void:
	if not _spec_picker_active:
		return
	if not Engine.has_singleton("BeeManager"):
		return
	var spec: String = SPECIALISATIONS[_spec_picker_index]
	BeeManager.set_specialisation(_selected_bee_id, spec)
	_spec_picker_active = false
	_update_selected_bee_info()
	if Engine.has_singleton("BeeManager"):
		var bee := BeeManager.get_bee(_selected_bee_id)
		_assignment_armed = bee.get("state", "") == BeeManager.STATE_UNASSIGNED
	if _assignment_armed:
		_set_status("Specialisation set. Move cursor and press Space to assign.")
	else:
		_set_status("Specialisation updated.")

func _cancel_spec_picker() -> void:
	if not _spec_picker_active:
		return
	_spec_picker_active = false
	_update_selected_bee_info()
	_set_status("Specialisation unchanged.")

func _handle_unassign() -> bool:
	if _selected_bee_id == -1:
		return false
	if not Engine.has_singleton("BeeManager"):
		return false
	var bee := BeeManager.get_bee(_selected_bee_id)
	if bee.is_empty():
		return false
	if bee.get("state", "") != BeeManager.STATE_ASSIGNED:
		_set_status("Bee is already unassigned.")
		return true
	BeeManager.unassign(_selected_bee_id)
	_assignment_armed = false
	_set_status("Bee #%d returned to the roster." % _selected_bee_id)
	return true

func _on_item_selected(index: int, _selected: bool = false) -> void:
	if index < 0 or index >= _bee_ids.size():
		return
	_selected_bee_id = _bee_ids[index]
	if _spec_picker_active:
		_cancel_spec_picker()
	_assignment_armed = false
	_update_selected_bee_info()

func _update_selected_bee_info() -> void:
	if not Engine.has_singleton("BeeManager"):
		_spec_label.text = "Specialisation: —"
		return
	var bee := BeeManager.get_bee(_selected_bee_id)
	if bee.is_empty():
		_spec_label.text = "Specialisation: —"
		_assignment_armed = false
		if _hex_grid:
			_hex_grid.clear_assignment_highlights()
		return
	var spec: String = bee.get("specialisation", "GATHER")
	_spec_label.text = "Specialisation: %s" % _format_spec(spec)
	_update_assignment_highlight()

func _update_assignment_highlight() -> void:
	if not _hex_grid:
		return
	if not _is_open:
		return
	if _spec_picker_active:
		var preview_spec: String = SPECIALISATIONS[_spec_picker_index]
		_hex_grid.set_assignment_highlights_for_spec(preview_spec)
		return
	if _selected_bee_id == -1:
		_hex_grid.clear_assignment_highlights()
		return
	if not Engine.has_singleton("BeeManager"):
		_hex_grid.clear_assignment_highlights()
		return
	var bee := BeeManager.get_bee(_selected_bee_id)
	if bee.is_empty():
		_hex_grid.clear_assignment_highlights()
		return
	var spec: String = bee.get("specialisation", "GATHER")
	if spec == "":
		_hex_grid.clear_assignment_highlights()
		return
	_hex_grid.set_assignment_highlights_for_spec(spec)

func _update_spec_picker_label() -> void:
	var spec: String = SPECIALISATIONS[_spec_picker_index]
	_spec_label.text = "Specialisation: ‹ %s ›" % _format_spec(spec)
	_update_assignment_highlight()

func _format_spec(spec: String) -> String:
	if spec.is_empty():
		return "—"
	return spec.capitalize()

func _set_status(message: String) -> void:
	_status_label.text = message
