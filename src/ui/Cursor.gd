extends Node2D
## Simple visual representation of the grid cursor.
class_name HexCursorDisplay

@export var color: Color = Color(1, 1, 0, 1)
@export var line_width: float = 2.0

var cell_size: float = 32.0 : set = set_cell_size

func _ready() -> void:
        queue_redraw()

func set_cell_size(value: float) -> void:
        cell_size = value
        queue_redraw()

func _draw() -> void:
        var points := _hex_points()
        if points.is_empty():
                return
        var outline := PackedVector2Array(points)
        outline.append(points[0])
        draw_polyline(outline, color, line_width)

func _hex_points() -> Array[Vector2]:
        var points: Array[Vector2] = []
        var radius := cell_size
        for index in range(6):
                var angle := deg_to_rad(60.0 * index + 30.0)
                points.append(Vector2(cos(angle), sin(angle)) * radius)
        return points
