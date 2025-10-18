extends Node2D

const LAYER_GROUND := 0
const LAYER_OBJECTS := 1
const LAYER_LIFE := 2

@export var width := 16 : set = set_width
@export var height := 12 : set = set_height
@export var tile_px := 64 : set = set_tile_px

@onready var hexmap: TileMap = $HexMap
@onready var cursor: Node = $Cursor
@onready var hud: Label = $HUD/DeckLabel

var _is_ready := false
var tiles_name_to_id: Dictionary = {}
var tiles_id_to_name: Dictionary = {}
var origin_cell: Vector2i = Vector2i.ZERO
var rules: PlacementRules = PlacementRules.new()
var turn := 0

func _ready() -> void:
    add_child(rules)
    rules.set_world(self)
    _ensure_hex_config()
    _ensure_layers()
    _build_tileset()
    _is_ready = true
    draw_debug_grid()
    _setup_hud()
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
        _ensure_hex_config()
        _build_tileset()
        draw_debug_grid()

func _ensure_hex_config() -> void:
    var ts: TileSet = hexmap.tile_set
    if ts != null:
        ts.tile_shape = TileSet.TILE_SHAPE_HEXAGON
        ts.tile_layout = TileSet.TILE_LAYOUT_STACKED
        ts.tile_size = Vector2i(tile_px, tile_px)
    hexmap.y_sort_enabled = false
    hexmap.cell_size = Vector2i(tile_px, tile_px)

func _ensure_layers() -> void:
    while hexmap.get_layers_count() < 3:
        hexmap.add_layer(hexmap.get_layers_count())
    hexmap.set_layer_name(LAYER_GROUND, "ground")
    hexmap.set_layer_name(LAYER_OBJECTS, "objects")
    hexmap.set_layer_name(LAYER_LIFE, "life")
    hexmap.set_layer_z_index(LAYER_GROUND, 0)
    hexmap.set_layer_z_index(LAYER_OBJECTS, 1)
    hexmap.set_layer_z_index(LAYER_LIFE, 2)

func _build_tileset() -> void:
    var names_to_colors: Dictionary = {
        "empty": Color(0, 0, 0, 0),
        "totem": Color(0.2, 0.85, 0.4, 1),
        "decay": Color(0.6, 0.2, 0.8, 1),
        "harvest": Color(0.15, 0.5, 0.2, 1),
        "build": Color(0.5, 0.35, 0.2, 1),
        "refine": Color(0.2, 0.4, 0.9, 1),
        "storage": Color(0.55, 0.55, 0.55, 1),
        "guard": Color(0.85, 0.75, 0.2, 1),
        "upgrade": Color(0.1, 0.7, 0.7, 1),
        "chanting": Color(0.8, 0.2, 0.6, 1),
    }
    tiles_name_to_id = TileSetBuilder.build_named_hex_tiles(hexmap, names_to_colors, tile_px)
    var id_meta: Variant = hexmap.get_meta("tiles_id_to_name") if hexmap.has_meta("tiles_id_to_name") else {}
    tiles_id_to_name = id_meta if id_meta is Dictionary else {}

func clear_tiles() -> void:
    hexmap.clear()
    rules.occupied.clear()
    turn = 0
    origin_cell = Vector2i.ZERO

func set_origin_cell(c: Vector2i) -> void:
    origin_cell = clamp_cell(c)
    rules.set_origin(origin_cell)
    if is_instance_valid(cursor):
        cursor.move_to(origin_cell)
    _update_hud()

func clamp_cell(c: Vector2i) -> Vector2i:
    return HexUtil.clamp_cell(c, width, height)

func neighbors_even_q(c: Vector2i) -> Array[Vector2i]:
    return HexUtil.neighbors_even_q(c, width, height)

func cell_to_world(c: Vector2i) -> Vector2:
    return hexmap.map_to_local(c)

func world_to_cell(p: Vector2) -> Vector2i:
    return hexmap.local_to_map(p)

func set_cell_named(layer: int, c: Vector2i, name: String) -> void:
    if tiles_name_to_id.is_empty():
        _build_tileset()
    if not tiles_name_to_id.has(name):
        return
    var tile_info: Dictionary = tiles_name_to_id[name]
    var src_id: int = int(tile_info.get("source_id", -1))
    var atlas_value: Variant = tile_info.get("atlas_coords", Vector2i.ZERO)
    var atlas_coords: Vector2i = atlas_value if atlas_value is Vector2i else Vector2i.ZERO
    if src_id < 0:
        return
    hexmap.set_cell(layer, c, src_id, atlas_coords)

func get_cell_name(layer: int, c: Vector2i) -> String:
    var td: TileData = hexmap.get_cell_tile_data(layer, c)
    if td == null:
        return ""
    var atlas_value: Variant = td.get_tile_id()
    var atlas_coords: Vector2i = atlas_value if atlas_value is Vector2i else Vector2i(int(atlas_value), 0)
    var key := TileSetBuilder.encode_tile_key(td.get_source_id(), atlas_coords)
    return String(tiles_id_to_name.get(key, ""))

func is_empty(layer: int, c: Vector2i) -> bool:
    return hexmap.get_cell_tile_data(layer, c) == null

func draw_debug_grid() -> void:
    var existing: Node = get_node_or_null("DebugGrid")
    if existing:
        existing.queue_free()
    var grid: Node2D = Node2D.new()
    grid.name = "DebugGrid"
    grid.z_index = -10
    add_child(grid)

    for x in range(width):
        for y in range(height):
            var marker: ColorRect = ColorRect.new()
            marker.color = Color(1, 1, 1, 0.08)
            marker.size = Vector2(6, 6)
            marker.pivot_offset = marker.size * 0.5
            marker.position = cell_to_world(Vector2i(x, y))
            marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
            marker.z_index = -10
            grid.add_child(marker)

func can_place_at(cell: Vector2i) -> bool:
    if DeckManager.peek().is_empty():
        return false
    return rules.can_place(self, cell)

func attempt_place_at(cell: Vector2i) -> void:
    if not can_place_at(cell):
        return
    var tile_id: String = DeckManager.peek()
    if tile_id.is_empty():
        return
    var category: String = DeckManager.get_tile_category(tile_id)
    if category.is_empty():
        return
    set_cell_named(LAYER_LIFE, cell, category)
    rules.mark_occupied(cell)
    turn += 1
    DeckManager.draw_one()
    _update_hud()
    if is_instance_valid(cursor):
        cursor.update_highlight_state()

func world_to_map(p: Vector2) -> Vector2i:
    return world_to_cell(p)

func _setup_hud() -> void:
    if is_instance_valid(hud):
        hud.text = "Next: — | Deck: —"

func update_hud(next_name: String, remaining: int) -> void:
    if is_instance_valid(hud):
        hud.text = "Next: %s | Deck: %d" % [next_name, remaining]

func _update_hud() -> void:
    if not is_instance_valid(hud):
        return
    var tile_id: String = DeckManager.peek()
    var remaining: int = DeckManager.remaining()
    var display_name: String = "-"
    if not tile_id.is_empty():
        var name: String = DeckManager.get_tile_name(tile_id)
        var category: String = DeckManager.get_tile_category(tile_id)
        if category.is_empty():
            display_name = name
        else:
            display_name = "%s (%s)" % [name, category]
    hud.text = "Next: %s | Deck: %d" % [display_name, remaining]
