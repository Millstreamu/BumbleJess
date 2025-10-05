extends Control
## Lightweight modal picker for assigning unassigned bees to a cell.
class_name AssignBeePicker

@export var empty_close_delay: float = 0.7

@onready var _list: ItemList = $Panel/Margin/VBox/BeeList
@onready var _status_label: Label = $Panel/Margin/VBox/Status
@onready var _hint_label: Label = $Panel/Margin/VBox/Hint
@onready var _timer: Timer = $AutoCloseTimer

var _target_cell: Vector2i = Vector2i.ZERO
var _bee_ids: Array[int] = []
var _selected_index: int = 0
var _is_open := false
var _close_on_any_input := false

func _ready() -> void:
        visible = false
        _timer.one_shot = true
        _timer.timeout.connect(_on_auto_close_timeout)
        _connect_bee_signals()

func is_open() -> bool:
        return _is_open

func open_for_cell(axial: Vector2i) -> void:
        _target_cell = axial
        _is_open = true
        visible = true
        _close_on_any_input = false
        _timer.stop()
        _timer.wait_time = empty_close_delay
        _populate_bee_list()
        if _bee_ids.is_empty():
                _status_label.text = "No bees available"
                _hint_label.text = ""
                _close_on_any_input = true
                _timer.start(empty_close_delay)
        else:
                _status_label.text = "Assign to (%d,%d)." % [axial.x, axial.y]
                _hint_label.text = "↑/↓ select · Space assign · Z cancel"
                _selected_index = 0
                _apply_selection()

func close_picker() -> void:
        if not _is_open:
                return
        _is_open = false
        visible = false
        _timer.stop()
        _bee_ids.clear()
        _list.clear()
        _status_label.text = ""
        _hint_label.text = ""
        _close_on_any_input = false

func handle_input(event: InputEvent) -> bool:
        if not _is_open:
                return false
        if event is InputEventAction and event.pressed:
                if _close_on_any_input:
                        close_picker()
                        return true
                if event.action == "ui_up":
                        _move_selection(-1)
                        return true
                if event.action == "ui_down":
                        _move_selection(1)
                        return true
                if event.action == "ui_left" or event.action == "ui_right":
                        return true
                if event.action == "ui_accept":
                        return _confirm_selection()
                if event.action == "ui_cancel":
                        close_picker()
                        return true
        if event is InputEventKey and event.pressed and not event.echo:
                if _close_on_any_input:
                        close_picker()
                        return true
                match event.physical_keycode:
                        KEY_UP:
                                _move_selection(-1)
                                return true
                        KEY_DOWN:
                                _move_selection(1)
                                return true
                        KEY_LEFT, KEY_RIGHT:
                                return true
                        KEY_SPACE:
                                return _confirm_selection()
                        KEY_Z:
                                close_picker()
                                return true
        return false

func _confirm_selection() -> bool:
        if _bee_ids.is_empty():
                close_picker()
                return true
        if not Engine.has_singleton("BeeManager"):
                _status_label.text = "Bee manager unavailable."
                return true
        var index := clamp(_selected_index, 0, _bee_ids.size() - 1)
        var bee_id := _bee_ids[index]
        var success := BeeManager.assign_to_cell(bee_id, _target_cell.x, _target_cell.y)
        if success:
                close_picker()
        else:
                _status_label.text = "Assignment failed."
        return true

func _move_selection(delta: int) -> void:
        if _bee_ids.is_empty():
                return
        _selected_index = clamp(_selected_index + delta, 0, _bee_ids.size() - 1)
        _apply_selection()

func _apply_selection() -> void:
        if _bee_ids.is_empty():
                _list.unselect_all()
                return
        _selected_index = clamp(_selected_index, 0, _bee_ids.size() - 1)
        _list.select(_selected_index)
        _list.ensure_current_is_visible()

func _populate_bee_list() -> void:
        _list.clear()
        _bee_ids.clear()
        if not Engine.has_singleton("BeeManager"):
                return
        var ids: Array[int] = BeeManager.list_unassigned()
        for bee_id in ids:
                var bee := BeeManager.get_bee(bee_id)
                var origin := bee.get("origin_brood", Vector2i.ZERO)
                var origin_text := ""
                if typeof(origin) == TYPE_VECTOR2I:
                        origin_text = " (from %d,%d)" % [origin.x, origin.y]
                var label := "Bee #%d%s" % [bee_id, origin_text]
                _bee_ids.append(bee_id)
                _list.add_item(label)

func _on_auto_close_timeout() -> void:
        close_picker()

func _connect_bee_signals() -> void:
        if not Engine.has_singleton("BeeManager"):
                return
        if not BeeManager.bee_spawned.is_connected(_on_bee_list_changed):
                BeeManager.bee_spawned.connect(_on_bee_list_changed)
        if not BeeManager.bee_unassigned.is_connected(_on_bee_list_changed):
                BeeManager.bee_unassigned.connect(_on_bee_list_changed)
        if not BeeManager.bee_assigned.is_connected(_on_bee_list_changed):
                BeeManager.bee_assigned.connect(_on_bee_list_changed)

func _on_bee_list_changed(_a = 0, _b = 0, _c = 0) -> void:
        if not _is_open:
                return
        var previous_id := -1
        if not _bee_ids.is_empty():
                previous_id = _bee_ids[clamp(_selected_index, 0, _bee_ids.size() - 1)]
        _populate_bee_list()
        if _bee_ids.is_empty():
                _status_label.text = "No bees available"
                _hint_label.text = ""
                _close_on_any_input = true
                _timer.wait_time = empty_close_delay
                _timer.start(empty_close_delay)
                return
        _close_on_any_input = false
        var new_index := _bee_ids.find(previous_id)
        if new_index == -1:
                new_index = 0
        _selected_index = new_index
        _apply_selection()
