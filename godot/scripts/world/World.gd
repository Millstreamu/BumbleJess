extends Node2D

@export var width := 16 : set = set_width
@export var height := 12 : set = set_height
@export var tile_px := 64 : set = set_tile_px

@onready var hexmap: TileMap = $HexMap

var _is_ready := false

func _ready() -> void:
    _is_ready = true
    _configure_tile_map()
    draw_debug_grid()

func set_width(value: int) -> void:
    width = max(1, value)
    if _is_ready:
        draw_debug_grid()

func set_height(value: int) -> void:
    height = max(1, value)
    if _is_ready:
        draw_debug_grid()

func set_tile_px(value: int) -> void:
    tile_px = max(1, value)
    if _is_ready:
        _configure_tile_map()
        draw_debug_grid()

func _configure_tile_map() -> void:
    if hexmap.tile_set == null:
        hexmap.tile_set = TileSet.new()
    var tile_set := hexmap.tile_set
    tile_set.tile_shape = TileSet.TILE_SHAPE_HEXAGONAL
    tile_set.tile_layout = TileSet.TILE_LAYOUT_STAGGERED
    tile_set.tile_offset_axis = TileSet.TILE_OFFSET_AXIS_HORIZONTAL
    tile_set.tile_offset = TileSet.TILE_OFFSET_EVEN
    tile_set.tile_size = Vector2i(tile_px, tile_px)
    hexmap.cell_size = Vector2i(tile_px, tile_px)

func clamp_cell(c: Vector2i) -> Vector2i:
    return Vector2i(clamp(c.x, 0, width - 1), clamp(c.y, 0, height - 1))

func neighbors_even_q(c: Vector2i) -> Array[Vector2i]:
    var deltas: Array[Vector2i]
    if c.x % 2 == 0:
        deltas = [
            Vector2i(1, 0),
            Vector2i(-1, 0),
            Vector2i(0, -1),
            Vector2i(0, 1),
            Vector2i(1, -1),
            Vector2i(-1, -1),
        ]
    else:
        deltas = [
            Vector2i(1, 0),
            Vector2i(-1, 0),
            Vector2i(0, -1),
            Vector2i(0, 1),
            Vector2i(1, 1),
            Vector2i(-1, 1),
        ]
    var results: Array[Vector2i] = []
    for d in deltas:
        var candidate := c + d
        if candidate.x >= 0 and candidate.x < width and candidate.y >= 0 and candidate.y < height:
            results.append(candidate)
    return results

func cell_to_world(c: Vector2i) -> Vector2:
    return hexmap.map_to_local(c)

func world_to_cell(p: Vector2) -> Vector2i:
    return hexmap.local_to_map(p)

func draw_debug_grid() -> void:
    # Remove the previous debug markers if they exist.
    var existing := get_node_or_null("DebugGrid")
    if existing:
        existing.queue_free()
    var grid := Node2D.new()
    grid.name = "DebugGrid"
    grid.z_index = -10
    add_child(grid)

    for x in range(width):
        for y in range(height):
            var marker := ColorRect.new()
            marker.color = Color(1, 1, 1, 0.08)
            marker.size = Vector2(6, 6)
            marker.pivot_offset = marker.size * 0.5
            marker.position = cell_to_world(Vector2i(x, y))
            marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
            marker.z_index = -10
            grid.add_child(marker)
