extends RefCounted
## Stores the simulation data for a single hex cell.
class_name CellData

const CellType := preload("res://scripts/core/CellType.gd")

var cell_type: int = CellType.Type.EMPTY
var variant_id: String = ""
var complex_id: int = 0
var color: Color = Color.WHITE
var growth_timer: int = 0
var growth_duration: int = 0
var sprout_count: int = 0
var sprout_capacity: int = 0
var decay_timer: int = 0

func set_type(new_type: int, new_color: Color) -> void:
	cell_type = new_type
	color = new_color
	if new_type != CellType.Type.OVERGROWTH:
		growth_timer = 0
		growth_duration = 0
	if new_type != CellType.Type.GROVE:
		sprout_count = 0
