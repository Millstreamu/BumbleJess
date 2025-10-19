extends Node2D

const LAYER_GROUND := 0
const LAYER_OBJECTS := 1
const LAYER_LIFE := 2

@export var width := 16 : set = set_width
@export var height := 12 : set = set_height
@export var tile_px := 128 : set = set_tile_px

@onready var hexmap: TileMap = $HexMap
@onready var cursor: Node = $Cursor
@onready var hud: Label = $HUD/DeckLabel

var _is_ready := false
var tiles_name_to_id: Dictionary = {}
var tiles_id_to_name: Dictionary = {}
var origin_cell: Vector2i = Vector2i.ZERO
var rules: PlacementRules = PlacementRules.new()
var turn := 0

func _calculate_hex_cell_size(px: int) -> Vector2i:
	var horizontal_spacing := int(round(float(px) * 0.75))
	var vertical_spacing := int(round(float(px) * (sqrt(3.0) / 2.0)))
	return Vector2i(max(horizontal_spacing, 1), max(vertical_spacing, 1))

func _ready() -> void:
        add_child(rules)
        rules.set_world(self)
        _ensure_hex_config()
        _ensure_layers()
        _build_tileset()
        var growth_manager: Node = get_node_or_null("/root/GrowthManager")
        if growth_manager != null:
                growth_manager.bind_world(self)
                var sprout_registry: Node = get_node_or_null("/root/SproutRegistry")
                if sprout_registry != null and not growth_manager.is_connected("grove_spawned", Callable(sprout_registry, "on_grove_spawned")):
                        growth_manager.connect("grove_spawned", Callable(sprout_registry, "on_grove_spawned"))
        _bind_resource_manager()
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
	if hexmap == null:
		return
	var ts: TileSet = hexmap.tile_set
	if ts != null:
		ts.tile_shape = TileSet.TILE_SHAPE_HEXAGON
		ts.tile_layout = TileSet.TILE_LAYOUT_STACKED
		ts.tile_offset_axis = TileSet.TILE_OFFSET_AXIS_VERTICAL
		var cell_size := _calculate_hex_cell_size(tile_px)
		ts.tile_size = Vector2i(tile_px, cell_size.y)
	hexmap.y_sort_enabled = false

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
	if hexmap == null:
		return
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
		"overgrowth": Color(0.35, 0.7, 0.35, 0.75),
		"grove": Color(0.10, 0.55, 0.25, 1.0),
	}
	tiles_name_to_id = TileSetBuilder.build_named_hex_tiles(hexmap, names_to_colors, tile_px)
	var id_meta: Variant = hexmap.get_meta("tiles_id_to_name") if hexmap.has_meta("tiles_id_to_name") else {}
	tiles_id_to_name = id_meta if id_meta is Dictionary else {}
	_ensure_hex_config()

func clear_tiles() -> void:
	if hexmap == null:
		return
        for layer in range(hexmap.get_layers_count()):
                var used_cells: Array = hexmap.get_used_cells(layer)
                for cell in used_cells:
                        hexmap.erase_cell(layer, cell)
                        if layer == LAYER_LIFE:
                                clear_cell_tile_id(layer, cell)
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
	if hexmap == null:
		return Vector2.ZERO
	return hexmap.map_to_local(c)

func world_to_cell(p: Vector2) -> Vector2i:
	if hexmap == null:
		return Vector2i.ZERO
	return hexmap.local_to_map(p)

func set_cell_named(layer: int, c: Vector2i, tile_name: String) -> void:
        if hexmap == null:
                return
        if tiles_name_to_id.is_empty():
                _build_tileset()
	if not tiles_name_to_id.has(tile_name):
		return
	var tile_info: Dictionary = tiles_name_to_id[tile_name]
	var src_id: int = int(tile_info.get("source_id", -1))
	var atlas_value: Variant = tile_info.get("atlas_coords", Vector2i.ZERO)
	var atlas_coords: Vector2i = atlas_value if atlas_value is Vector2i else Vector2i.ZERO
        if src_id < 0:
                return
        hexmap.set_cell(layer, c, src_id, atlas_coords)
        if layer == LAYER_LIFE:
                clear_cell_tile_id(layer, c)

func set_cell_meta(layer: int, c: Vector2i, key: String, value) -> void:
        if hexmap == null:
                return
        hexmap.set_cell_metadata(layer, c, key, value)

func get_cell_meta(layer: int, c: Vector2i, key: String):
        if hexmap == null:
                return null
        return hexmap.get_cell_metadata(layer, c, key)

func set_cell_tile_id(layer: int, c: Vector2i, id: String) -> void:
        set_cell_meta(layer, c, "id", id)

func get_cell_tile_id(layer: int, c: Vector2i) -> String:
        if hexmap == null:
                return ""
        var value = hexmap.get_cell_metadata(layer, c, "id")
        return value if typeof(value) == TYPE_STRING else ""

func id_to_category(id: String) -> String:
        if id.is_empty():
                return ""
        return String(DeckManager.id_to_category.get(id, ""))

func id_to_name(id: String) -> String:
        if id.is_empty():
                return ""
        return String(DeckManager.id_to_name.get(id, id))

func get_cell_name(layer: int, c: Vector2i) -> String:
        if hexmap == null:
                return ""
        if hexmap.get_cell_tile_data(layer, c) == null:
                return ""
	var source_id: int = hexmap.get_cell_source_id(layer, c)
	if source_id < 0:
		return ""
        var atlas_coords: Vector2i = hexmap.get_cell_atlas_coords(layer, c)
        var key := TileSetBuilder.encode_tile_key(source_id, atlas_coords)
        return String(tiles_id_to_name.get(key, ""))

func clear_cell_tile_id(layer: int, c: Vector2i) -> void:
        if hexmap == null:
                return
        hexmap.set_cell_metadata(layer, c, "id", null)

func is_empty(layer: int, c: Vector2i) -> bool:
	if hexmap == null:
		return true
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
        place_current_tile(cell)

func place_current_tile(cell: Vector2i) -> void:
        if DeckManager.next_tile_id.is_empty():
                return
        if not rules.can_place(self, cell):
                return
        var tile_id: String = DeckManager.next_tile_id
        var category: String = id_to_category(tile_id)
        if category.is_empty():
                return
        set_cell_named(LAYER_LIFE, cell, category)
        set_cell_tile_id(LAYER_LIFE, cell, tile_id)
        rules.mark_occupied(cell)
        turn += 1
        DeckManager.draw_one()
        update_hud(DeckManager.peek_name(), DeckManager.remaining())
        if is_instance_valid(cursor):
                cursor.update_highlight_state()
        var growth_manager: Node = get_node_or_null("/root/GrowthManager")
        if growth_manager != null and growth_manager.has_method("request_growth_update"):
                growth_manager.request_growth_update(turn)
        if Engine.has_singleton("ResourceManager"):
                ResourceManager.emit_signal("resources_changed")
        if Engine.has_singleton("TurnEngine"):
                TurnEngine.advance_one_turn()
        elif Engine.has_singleton("Game"):
                Game.advance_one_turn()

func world_to_map(p: Vector2) -> Vector2i:
	return world_to_cell(p)

func _setup_hud() -> void:
        if is_instance_valid(hud):
                hud.text = _build_hud_text("-", 0)

func update_hud(next_name: String, remaining: int) -> void:
        if is_instance_valid(hud):
                hud.text = _build_hud_text(next_name, remaining)

func _update_hud() -> void:
        if not is_instance_valid(hud):
                return
        var tile_id: String = DeckManager.peek()
        var remaining: int = DeckManager.remaining()
        var display_name: String = "-"
        if not tile_id.is_empty():
                var tile_name: String = DeckManager.peek_name()
                var category: String = DeckManager.peek_category()
                if category.is_empty():
                        display_name = tile_name
                else:
                        display_name = "%s (%s)" % [tile_name, category]
        hud.text = _build_hud_text(display_name, remaining)

func _build_hud_text(next_name: String, remaining: int) -> String:
        var text := "Next: %s | Deck: %d" % [next_name, remaining]
        text += "\nOvergrowth: %d | Groves: %d" % [_count_cells_named("overgrowth"), _count_cells_named("grove")]
        if Engine.has_singleton("ResourceManager"):
                text += "\nNature %d/%d Earth %d/%d Water %d/%d Life %d Seeds %d" % [
                        ResourceManager.get_amount("nature"), ResourceManager.get_capacity("nature"),
                        ResourceManager.get_amount("earth"), ResourceManager.get_capacity("earth"),
                        ResourceManager.get_amount("water"), ResourceManager.get_capacity("water"),
                        ResourceManager.get_amount("life"),
                        ResourceManager.soul_seeds,
                ]
        return text

func _bind_resource_manager() -> void:
        if not Engine.has_singleton("ResourceManager"):
                return
        ResourceManager.bind_world(self)
        if not ResourceManager.is_connected("resources_changed", Callable(self, "_on_resources_changed")):
                ResourceManager.connect("resources_changed", Callable(self, "_on_resources_changed"))
        if not ResourceManager.is_connected("item_changed", Callable(self, "_on_item_changed")):
                ResourceManager.connect("item_changed", Callable(self, "_on_item_changed"))
        _on_resources_changed()

func _on_resources_changed() -> void:
        _update_hud()

func _on_item_changed(_item: String) -> void:
        _update_hud()

func _count_cells_named(tile_name: String) -> int:
	var total := 0
	for y in range(height):
		for x in range(width):
			if get_cell_name(LAYER_LIFE, Vector2i(x, y)) == tile_name:
				total += 1
	return total
