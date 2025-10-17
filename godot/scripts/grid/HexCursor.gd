extends Node2D

## Simple cursor that outlines the currently hovered hex cell.
class_name HexCursor

@onready var outline: Line2D = $Line2D
var _cell_size: float = 52.0

func configure(cell_size: float, outline_color: Color) -> void:
	_cell_size = cell_size
	outline.width = 3.0
	outline.default_color = outline_color
	outline.closed = true
	outline.points = _build_outline_points(_cell_size)

func set_cell_size(cell_size: float) -> void:
	_cell_size = cell_size
	outline.points = _build_outline_points(_cell_size)

func _build_outline_points(cell_size: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in range(7):
		var angle := PI / 180.0 * (60.0 * i)
		points.append(Vector2(cos(angle), sin(angle)) * cell_size * 1.02)
	return points
