extends Node2D

## Visual representation of a single hex cell. Handles rendering of the hexagon
## and state transitions for highlighting and selection.
class_name HexCell

@onready var polygon: Polygon2D = $Polygon2D

var axial: Vector2i = Vector2i.ZERO
var _cell_size: float = 52.0
var _cell_color: Color = Color.WHITE
var _selection_color: Color = Color.DARK_GOLDENROD
var _is_selected := false
var _flash_tween: Tween

func configure(axial_coord: Vector2i, cell_size: float, selection_color: Color, initial_color: Color) -> void:
    axial = axial_coord
    _cell_size = cell_size
    _selection_color = selection_color
    _cell_color = initial_color
    polygon.polygon = _build_polygon_points(cell_size)
    polygon.modulate = Color.WHITE
    _apply_color()

func set_selected(selected: bool) -> void:
    _is_selected = selected
    _apply_color()

func toggle_selected() -> void:
    set_selected(not _is_selected)

func is_selected() -> bool:
    return _is_selected

func set_cell_color(color: Color) -> void:
    _cell_color = color
    _apply_color()

func flash(duration: float = 0.2) -> void:
    if _flash_tween:
        _flash_tween.kill()
    polygon.modulate = Color(1.4, 1.4, 1.4, 1.0)
    _flash_tween = create_tween()
    _flash_tween.tween_property(polygon, "modulate", Color.WHITE, duration)

func _apply_color() -> void:
    if _is_selected:
        polygon.color = _selection_color
    else:
        polygon.color = _cell_color

func _build_polygon_points(cell_size: float) -> PackedVector2Array:
    var points := PackedVector2Array()
    for i in range(6):
        var angle := PI / 180.0 * (60.0 * i)
        points.append(Vector2(cos(angle), sin(angle)) * cell_size)
    return points
