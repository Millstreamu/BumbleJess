extends Node

var maps_data: Array = []
var _origin_cell: Vector2i = Vector2i.ZERO

func _ready() -> void:
    var path := "res://data/maps.json"
    maps_data = DataLite.load_json_array(path)
    if maps_data.is_empty():
        push_warning("maps.json not found or empty at " + path)

func get_map(id: String) -> Dictionary:
    for m in maps_data:
        if m.get("id", "") == id:
            return m
    return {}

func load_map(map_id: String, world: Node) -> void:
    var map := get_map(map_id)
    if map.is_empty():
        push_error("Map not found: %s" % map_id)
        _show_missing_map_label(world, map_id)
        return

    var grid := map.get("grid", {})
    world.set("width", int(grid.get("width", 16)))
    world.set("height", int(grid.get("height", 12)))
    world.set("tile_px", int(grid.get("tile_px", 64)))

    if world.has_method("clear_tiles"):
        world.call("clear_tiles")
    if world.has_method("draw_debug_grid"):
        world.call("draw_debug_grid")

    var totem_data := map.get("totem", {})
    var totem_cell := Vector2i(int(totem_data.get("x", 0)), int(totem_data.get("y", 0)))
    if world.has_method("set_cell_named"):
        world.call("set_cell_named", world.LAYER_OBJECTS, totem_cell, "totem")
    if world.has_method("set_origin_cell"):
        world.call("set_origin_cell", totem_cell)

    _origin_cell = totem_cell

    var decay_totems := map.get("decay_totems", [])
    for decay_data in decay_totems:
        var decay_cell := Vector2i(int(decay_data.get("x", 0)), int(decay_data.get("y", 0)))
        if world.has_method("set_cell_named"):
            world.call("set_cell_named", world.LAYER_OBJECTS, decay_cell, "decay")

func get_origin_cell() -> Vector2i:
    return _origin_cell

func _show_missing_map_label(world: Node, map_id: String) -> void:
    var label := Label.new()
    label.text = "Map not found: " + map_id
    label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    label.size_flags_vertical = Control.SIZE_EXPAND_FILL
    label.anchor_left = 0.0
    label.anchor_right = 1.0
    label.anchor_top = 0.0
    label.anchor_bottom = 1.0
    label.offset_left = 0.0
    label.offset_right = 0.0
    label.offset_top = 0.0
    label.offset_bottom = 0.0

    var layer := CanvasLayer.new()
    layer.add_child(label)
    world.add_child(layer)
