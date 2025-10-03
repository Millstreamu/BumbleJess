extends Resource
class_name GridConfig

## Resource-driven configuration for the hex grid. Adjusting values in the
## associated .tres file changes how the grid is generated without modifying
## code.
@export var radius: int = 3
@export var cell_size: float = 48.0
@export var cell_color: Color = Color("#f5e9c6")
@export var queen_color: Color = Color("#f2c14e")
@export var cursor_color: Color = Color("#f7f7ff")
@export var selection_color: Color = Color("#f08a4b")
@export var background_color: Color = Color("#2a2a2a")
