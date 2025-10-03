extends Control
## Simple keyboard-driven palette that displays buildable cell types.
class_name BuildPalette

const CellType := preload("res://scripts/core/CellType.gd")
const PaletteState := preload("res://scripts/input/PaletteState.gd")

@export var palette_state_path: NodePath
@export var header: String = "Build Palette"

@onready var _title_label: Label = $Panel/Margin/VBox/Title
@onready var _items_container: HBoxContainer = $Panel/Margin/VBox/Items

var _palette_state: PaletteState
var _labels: Dictionary = {}

func _ready() -> void:
    if palette_state_path.is_empty():
        palette_state_path = NodePath("../PaletteState")
    _palette_state = get_node_or_null(palette_state_path)
    if not _palette_state:
        push_warning("BuildPalette requires a PaletteState node")
        return
    _title_label.text = header
    _create_labels()
    visible = false

    _palette_state.connect("palette_opened", Callable(self, "_on_palette_opened"))
    _palette_state.connect("palette_closed", Callable(self, "_on_palette_closed"))
    _palette_state.connect("selection_changed", Callable(self, "_on_selection_changed"))
    _palette_state.connect("in_hand_changed", Callable(self, "_on_in_hand_changed"))

func _create_labels() -> void:
    for child in _items_container.get_children():
        child.queue_free()
    _labels.clear()
    for cell_type in _palette_state.buildable_types:
        var label := Label.new()
        label.text = CellType.to_display_name(cell_type)
        label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
        label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        _items_container.add_child(label)
        _labels[cell_type] = label
    _refresh_selection_visuals(_palette_state.get_selected_type())
    _refresh_in_hand_visuals(_palette_state.get_in_hand_type())

func _on_palette_opened() -> void:
    visible = true
    _refresh_selection_visuals(_palette_state.get_selected_type())
    _refresh_in_hand_visuals(_palette_state.get_in_hand_type())

func _on_palette_closed() -> void:
    visible = false

func _on_selection_changed(cell_type: int) -> void:
    _refresh_selection_visuals(cell_type)

func _on_in_hand_changed(cell_type) -> void:
    _refresh_in_hand_visuals(cell_type)

func _refresh_selection_visuals(selected_type: int) -> void:
    for cell_type in _labels.keys():
        var label: Label = _labels[cell_type]
        if cell_type == selected_type:
            label.add_theme_color_override("font_color", Color.WHITE)
            label.self_modulate = Color(1, 1, 1, 1)
        else:
            label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8, 1))
            label.self_modulate = Color(0.9, 0.9, 0.9, 1)

func _refresh_in_hand_visuals(in_hand_type) -> void:
    for cell_type in _labels.keys():
        var label: Label = _labels[cell_type]
        var base_name := CellType.to_display_name(cell_type)
        if in_hand_type != null and cell_type == in_hand_type:
            label.text = "%s *" % base_name
        else:
            label.text = base_name
