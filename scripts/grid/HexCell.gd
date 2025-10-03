extends Node2D

## Visual representation of a single hex cell. Handles rendering of the hexagon
## and state transitions for highlighting and selection.
class_name HexCell

@onready var polygon: Polygon2D = $Polygon2D

var axial: Vector2i = Vector2i.ZERO
var _cell_size: float = 52.0
var _base_color: Color = Color.WHITE
var _selection_color: Color = Color.DARK_GOLDENROD
var _queen_color: Color = Color.GOLD
var _is_selected := false
var _is_queen := false

func configure(axial_coord: Vector2i, cell_size: float, base_color: Color, selection_color: Color, queen_color: Color, is_queen: bool) -> void:
    axial = axial_coord
    _cell_size = cell_size
    _base_color = base_color
    _selection_color = selection_color
    _queen_color = queen_color
    _is_queen = is_queen
    polygon.polygon = _build_polygon_points(cell_size)
    _apply_color()

func set_selected(selected: bool) -> void:
    _is_selected = selected
    _apply_color()

func toggle_selected() -> void:
    set_selected(not _is_selected)

func is_selected() -> bool:
    return _is_selected

func _apply_color() -> void:
    if _is_selected:
        polygon.color = _selection_color
    elif _is_queen:
        polygon.color = _queen_color
    else:
        polygon.color = _base_color

func _build_polygon_points(cell_size: float) -> PackedVector2Array:
    var points := PackedVector2Array()
    for i in range(6):
        var angle := PI / 180.0 * (60.0 * i)
        points.append(Vector2(cos(angle), sin(angle)) * cell_size)
    return points
