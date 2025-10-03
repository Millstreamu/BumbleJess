extends RefCounted
## Stores the simulation data for a single hex cell.
class_name CellData

var cell_type: int = 0
var complex_id: int = 0
var color: Color = Color.WHITE

func set_type(new_type: int, new_color: Color) -> void:
    cell_type = new_type
    color = new_color
