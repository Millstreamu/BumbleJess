extends Node
## Tracks the currently selected build option and the in-hand cell type.
class_name PaletteState

const CellType := preload("res://scripts/core/CellType.gd")

signal palette_opened()
signal palette_closed()
signal selection_changed(selected_type: int)
signal in_hand_changed(in_hand_type)

var buildable_types: Array[int] = CellType.buildable_types()
var is_open: bool = false
var selected_index: int = 0
const NO_IN_HAND := -1

var in_hand_type: int = NO_IN_HAND

func toggle_open() -> void:
    if is_open:
        close()
    else:
        open()

func open() -> void:
    if is_open:
        return
    is_open = true
    if has_in_hand():
        var idx := buildable_types.find(in_hand_type)
        if idx != -1:
            selected_index = idx
    emit_signal("palette_opened")
    emit_signal("selection_changed", get_selected_type())

func close() -> void:
    if not is_open:
        return
    is_open = false
    emit_signal("palette_closed")

func move_selection(delta: int) -> void:
    if buildable_types.is_empty():
        return
    selected_index = wrapi(selected_index + delta, 0, buildable_types.size())
    emit_signal("selection_changed", get_selected_type())

func confirm_selection() -> int:
    if buildable_types.is_empty():
        return CellType.Type.EMPTY
    var selected_type := get_selected_type()
    in_hand_type = selected_type
    emit_signal("in_hand_changed", selected_type)
    close()
    return selected_type

func clear_in_hand() -> void:
    if not has_in_hand():
        return
    in_hand_type = NO_IN_HAND
    emit_signal("in_hand_changed", null)

func has_in_hand() -> bool:
    return in_hand_type != NO_IN_HAND

func get_in_hand_type():
    if not has_in_hand():
        return null
    return in_hand_type

func get_selected_type() -> int:
    if buildable_types.is_empty():
        return CellType.Type.EMPTY
    return buildable_types[selected_index]
