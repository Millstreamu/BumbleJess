extends Resource
class_name GridConfig

const CellType := preload("res://scripts/core/CellType.gd")

## Resource-driven configuration for the hex grid. Adjusting values in the
## associated .tres file changes how the grid is generated without modifying
## code.
@export var radius: int = 6
@export var cell_size: float = 41.6
@export var cell_color: Color = Color.TRANSPARENT
@export var buildable_highlight_color: Color = Color(0.8, 0.8, 0.8, 0.35)
@export var totem_color: Color = Color("#d0f4a7")
@export var cursor_color: Color = Color("#f7f7ff")
@export var selection_color: Color = Color("#a0e3b2")
@export var background_color: Color = Color("#1e2a22")
@export var type_colors: Dictionary = {}
@export var overgrowth_maturation_turns: int = 3
@export var grove_spawn_count: int = 1
@export var allow_isolated_builds: bool = false

func _init() -> void:
	if type_colors.is_empty():
		_assign_default_colors()

func get_color(cell_type: int) -> Color:
	if cell_type == CellType.Type.TOTEM:
		return totem_color
	return type_colors.get(cell_type, cell_color)

func _assign_default_colors() -> void:
	type_colors = {
		CellType.Type.EMPTY: cell_color,
		CellType.Type.HARVEST: Color("#7bc96f"),
		CellType.Type.BUILD: Color("#a26a42"),
		CellType.Type.REFINE: Color("#6ec6ff"),
		CellType.Type.STORAGE: Color("#7c6f64"),
		CellType.Type.GUARD: Color("#ef798a"),
		CellType.Type.UPGRADE: Color("#f9a03f"),
		CellType.Type.CHANTING: Color("#b497d6"),
		CellType.Type.GROVE: Color("#4caf50"),
		CellType.Type.OVERGROWTH: Color("#2e7d32"),
		CellType.Type.DECAY: Color("#46364a"),
	}
