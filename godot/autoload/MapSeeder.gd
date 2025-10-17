extends Node

var maps_data: Array = []

func _ready() -> void:
    var path := "res://data/maps.json"
    if ResourceLoader.exists(path):
        var file := FileAccess.open(path, FileAccess.READ)
        if file:
            var text := file.get_as_text()
            var parsed := JSON.parse_string(text)
            if typeof(parsed) == TYPE_ARRAY:
                maps_data = parsed
    else:
        push_warning("maps.json not found at " + path)

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

    if world.has_method("draw_debug_grid"):
        world.call("draw_debug_grid")

    var markers := world.get_node_or_null("Markers")
    if markers == null:
        markers = Node2D.new()
        markers.name = "Markers"
        world.add_child(markers)
    else:
        for child in markers.get_children():
            child.queue_free()

    var totem_data := map.get("totem", {})
    var totem_cell := Vector2i(int(totem_data.get("x", 0)), int(totem_data.get("y", 0)))
    var totem_scene := load("res://scenes/world/Totem.tscn") as PackedScene
    if totem_scene:
        var totem := totem_scene.instantiate()
        if totem_data.has("totem_id"):
            totem.set("totem_id", String(totem_data.get("totem_id")))
        totem.position = world.call("cell_to_world", totem_cell)
        markers.add_child(totem)

    var decay_scene := load("res://scenes/world/DecayTotem.tscn") as PackedScene
    var decay_totems := map.get("decay_totems", [])
    for decay_data in decay_totems:
        var decay_cell := Vector2i(int(decay_data.get("x", 0)), int(decay_data.get("y", 0)))
        if decay_scene:
            var decay := decay_scene.instantiate()
            decay.position = world.call("cell_to_world", decay_cell)
            markers.add_child(decay)

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
