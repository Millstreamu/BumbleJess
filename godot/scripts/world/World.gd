extends Node2D

const LAYER_GROUND := 0
const LAYER_OBJECTS := 1
const LAYER_LIFE := 2

@export var width := 16 : set = set_width
@export var height := 12 : set = set_height
@export var tile_px := 64 : set = set_tile_px

@onready var hexmap: TileMap = $HexMap
@onready var cursor: Node = $Cursor
@onready var hud_label: Label = $HUD/MarginContainer/Label

var _is_ready := false
var tileset_ids: Dictionary = {}
var tileset_names_by_source: Dictionary = {}
var origin_cell: Vector2i = Vector2i.ZERO
var rules := PlacementRules.new()
var turn := 0

func _ready() -> void:
    add_child(rules)
    rules.set_world(self)
    _is_ready = true
    _configure_tile_map()
    draw_debug_grid()
    _update_hud()

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
    _ensure_layers()
    tileset_ids.clear()
    tileset_names_by_source.clear()
    _ensure_runtime_tiles(tile_set)

func _ensure_layers() -> void:
    while hexmap.get_layers_count() < 3:
        hexmap.add_layer()
    hexmap.set_layer_name(LAYER_GROUND, "ground")
    hexmap.set_layer_name(LAYER_OBJECTS, "objects")
    hexmap.set_layer_name(LAYER_LIFE, "life")
    hexmap.set_layer_z_index(LAYER_GROUND, 0)
    hexmap.set_layer_z_index(LAYER_OBJECTS, 1)
    hexmap.set_layer_z_index(LAYER_LIFE, 2)

func _ensure_runtime_tiles(tile_set: TileSet) -> void:
    tile_set.clear()
    var color_map := {
        "empty": Color(0, 0, 0, 0),
        "totem": Color(0.2, 0.8, 0.4, 1.0),
        "decay": Color(0.55, 0.2, 0.7, 1.0),
        "harvest": Color(0.15, 0.45, 0.15, 1.0),
        "build": Color(0.55, 0.38, 0.2, 1.0),
        "refine": Color(0.2, 0.4, 0.85, 1.0),
        "storage": Color(0.6, 0.6, 0.6, 1.0),
        "guard": Color(0.9, 0.8, 0.2, 1.0),
        "upgrade": Color(0.2, 0.7, 0.7, 1.0),
        "chanting": Color(0.8, 0.2, 0.7, 1.0),
    }
    for name in color_map.keys():
        var texture := _create_hex_texture(tile_px, color_map[name])
        var source := TileSetAtlasSource.new()
        source.texture = texture
        var source_id := tile_set.add_source(source)
        var tile_id := source.create_tile(Vector2i.ZERO)
        source.set_tile_texture_region(tile_id, Rect2i(Vector2i.ZERO, texture.get_size()))
        tile_set.set_tile_name(source_id, tile_id, name)
        tileset_ids[name] = source_id
        tileset_names_by_source[source_id] = name

func _create_hex_texture(size: int, color: Color) -> Texture2D:
    var image := Image.create(size, size, false, Image.FORMAT_RGBA8)
    image.fill(Color(0, 0, 0, 0))
    var center := Vector2(size / 2.0, size / 2.0)
    var radius := size / 2.0 - 1.0
    var polygon: Array[Vector2] = []
    for i in range(6):
        var angle := deg_to_rad(60.0 * i + 30.0)
        polygon.append(center + Vector2(cos(angle), sin(angle)) * radius)
    image.lock()
    for y in range(size):
        for x in range(size):
            var point := Vector2(x + 0.5, y + 0.5)
            if _point_in_polygon(point, polygon):
                image.set_pixel(x, y, color)
    image.unlock()
    return ImageTexture.create_from_image(image)

func _point_in_polygon(point: Vector2, polygon: Array[Vector2]) -> bool:
    var inside := false
    var j := polygon.size() - 1
    for i in range(polygon.size()):
        var pi: Vector2 = polygon[i]
        var pj: Vector2 = polygon[j]
        var intersect := ((pi.y > point.y) != (pj.y > point.y)) and (point.x < (pj.x - pi.x) * (point.y - pi.y) / (pj.y - pi.y + 0.000001) + pi.x)
        if intersect:
            inside = not inside
        j = i
    return inside

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

func clear_tiles() -> void:
    hexmap.clear()
    rules.occupied.clear()
    turn = 0
    origin_cell = Vector2i.ZERO

func set_cell_named(layer: int, c: Vector2i, name: String) -> void:
    if tileset_ids.is_empty():
        _configure_tile_map()
    var source_id := tileset_ids.get(name, -1)
    if source_id == -1:
        return
    hexmap.set_cell(layer, c, source_id, Vector2i.ZERO, 0)

func get_cell_name(layer: int, c: Vector2i) -> String:
    var tile_data := hexmap.get_cell_tile_data(layer, c)
    if tile_data == null:
        return ""
    var source_id := tile_data.get_source_id()
    return String(tileset_names_by_source.get(source_id, ""))

func can_place_at(cell: Vector2i) -> bool:
    if DeckManager.peek().is_empty():
        return false
    return rules.can_place(self, cell)

func attempt_place_at(cell: Vector2i) -> void:
    if not can_place_at(cell):
        return
    var tile_id := DeckManager.peek()
    if tile_id.is_empty():
        return
    var category := DeckManager.get_tile_category(tile_id)
    if category.is_empty():
        return
    set_cell_named(LAYER_LIFE, cell, category)
    rules.mark_occupied(cell)
    turn += 1
    DeckManager.draw_one()
    _update_hud()
    if is_instance_valid(cursor):
        cursor.update_highlight_state()

func set_origin_cell(c: Vector2i) -> void:
    origin_cell = clamp_cell(c)
    rules.set_origin(origin_cell)
    if is_instance_valid(cursor):
        cursor.move_to(origin_cell)
    _update_hud()

func _update_hud() -> void:
    if hud_label == null:
        return
    var tile_id := DeckManager.peek()
    var remaining := DeckManager.remaining()
    var display_name := "-"
    if not tile_id.is_empty():
        var name := DeckManager.get_tile_name(tile_id)
        var category := DeckManager.get_tile_category(tile_id)
        if category.is_empty():
            display_name = name
        else:
            display_name = "%s (%s)" % [name, category]
    hud_label.text = "Next: %s  |  Deck: %d" % [display_name, remaining]
