extends Control
## Keyboard-driven palette that displays buildable tile types and remaining counts.
class_name BuildPalette

const CellType := preload("res://scripts/core/CellType.gd")
const PaletteState := preload("res://scripts/input/PaletteState.gd")

@export var palette_state_path: NodePath
@export var header: String = "Tile Palette"

@onready var _title_label: Label = get_node_or_null("Panel/Margin/VBox/Title")
@onready var _items_container: GridContainer = get_node_or_null("Panel/Margin/VBox/Items")
@onready var _viewport: Viewport = get_viewport()

var _palette_state: PaletteState
var _labels: Dictionary = {}
var _descriptions: Dictionary = {}

func _ready() -> void:
    if palette_state_path.is_empty():
        palette_state_path = NodePath("../PaletteState")
    _palette_state = get_node_or_null(palette_state_path)
    if not _palette_state:
        push_warning("BuildPalette requires a PaletteState node")
        return
    if _title_label:
        _title_label.text = header
    else:
        push_warning("BuildPalette missing Title label; skipping header setup")
    visible = false

    if _viewport:
        _viewport.connect("size_changed", Callable(self, "_center_on_screen"))
    call_deferred("_center_on_screen")

    _palette_state.connect("palette_opened", Callable(self, "_on_palette_opened"))
    _palette_state.connect("palette_closed", Callable(self, "_on_palette_closed"))
    _palette_state.connect("selection_changed", Callable(self, "_on_selection_changed"))
    _palette_state.connect("in_hand_changed", Callable(self, "_on_in_hand_changed"))
    _palette_state.connect("options_changed", Callable(self, "_on_options_changed"))

    _create_labels()

func set_tile_descriptions(descriptions: Dictionary) -> void:
    _descriptions = descriptions.duplicate(true)
    _refresh_label_tooltips()

func _create_labels() -> void:
    if not _items_container:
        push_warning("BuildPalette missing Items container; cannot create labels")
        return
    for child in _items_container.get_children():
        child.queue_free()
    _labels.clear()
    for cell_type in _palette_state.buildable_types:
        var label := Label.new()
        label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
        label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        label.size_flags_vertical = Control.SIZE_EXPAND_FILL
        _items_container.add_child(label)
        _labels[cell_type] = label
    _refresh_selection_visuals(_palette_state.get_selected_type())
    _refresh_counts()
    _refresh_in_hand_visuals(_palette_state.get_in_hand_type())
    _refresh_label_tooltips()
    call_deferred("_center_on_screen")

func _refresh_counts() -> void:
    for cell_type in _labels.keys():
        var label: Label = _labels[cell_type]
        if not label:
            continue
        var base_name := CellType.to_display_name(cell_type)
        var count := _palette_state.get_count(cell_type)
        if count > 0:
            label.text = "%s (x%d)" % [base_name, count]
        else:
            label.text = base_name

func _refresh_label_tooltips() -> void:
    for cell_type in _labels.keys():
        var label: Label = _labels[cell_type]
        if not label:
            continue
        label.tooltip_text = String(_descriptions.get(cell_type, ""))

func _on_palette_opened() -> void:
    visible = true
    _refresh_selection_visuals(_palette_state.get_selected_type())
    _refresh_counts()
    _refresh_in_hand_visuals(_palette_state.get_in_hand_type())
    call_deferred("_center_on_screen")

func _on_palette_closed() -> void:
    visible = false

func _on_selection_changed(cell_type: int) -> void:
    _refresh_selection_visuals(cell_type)

func _on_in_hand_changed(cell_type) -> void:
    _refresh_in_hand_visuals(cell_type)

func _on_options_changed() -> void:
    _create_labels()

func _refresh_selection_visuals(selected_type: int) -> void:
    for cell_type in _labels.keys():
        var label: Label = _labels[cell_type]
        if not label:
            continue
        if cell_type == selected_type:
            label.add_theme_color_override("font_color", Color.WHITE)
            label.self_modulate = Color(1, 1, 1, 1)
        else:
            label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8, 1))
            label.self_modulate = Color(0.9, 0.9, 0.9, 1)
    _refresh_counts()

func _refresh_in_hand_visuals(in_hand_type) -> void:
    for cell_type in _labels.keys():
        var label: Label = _labels[cell_type]
        if not label:
            continue
        var base_name := label.text
        if in_hand_type != null and cell_type == in_hand_type:
            if not base_name.ends_with(" *"):
                label.text = "%s *" % base_name
        else:
            var count := _palette_state.get_count(cell_type)
            var display_name := CellType.to_display_name(cell_type)
            if count > 0:
                label.text = "%s (x%d)" % [display_name, count]
            else:
                label.text = display_name

func _center_on_screen() -> void:
    if not _viewport:
        return
    var viewport_size := _viewport.get_visible_rect().size
    var control_size := size
    if control_size == Vector2.ZERO:
        control_size = get_combined_minimum_size()
    var centered_position := (viewport_size - control_size) * 0.5
    position = centered_position
