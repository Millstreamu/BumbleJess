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
@export var queen_color: Color = Color("#f2c14e")
@export var cursor_color: Color = Color("#f7f7ff")
@export var selection_color: Color = Color("#f08a4b")
@export var background_color: Color = Color("#2a2a2a")
@export var type_colors: Dictionary = {}
@export var brood_hatch_seconds: float = 10.0
@export var allow_isolated_builds: bool = false

func _init() -> void:
    if type_colors.is_empty():
        _assign_default_colors()

func get_color(cell_type: int) -> Color:
    if cell_type == CellType.Type.QUEEN_SEAT:
        return queen_color
    return type_colors.get(cell_type, cell_color)

func _assign_default_colors() -> void:
    type_colors = {
        CellType.Type.EMPTY: cell_color,
        CellType.Type.WAX: Color("#f6d365"),
        CellType.Type.VAT: Color("#9b5de5"),
        CellType.Type.STORAGE: Color("#6c584c"),
        CellType.Type.GATHERING: Color("#4caf50"),
        CellType.Type.GUARD: Color("#f15bb5"),
        CellType.Type.HALL: Color("#00bbf9"),
        CellType.Type.BROOD: Color("#ff9f1c"),
    }
