extends Node
class_name PlacementRules

var occupied: Dictionary = {}
var origin: Vector2i = Vector2i.ZERO
var _world: Node = null

func set_world(world: Node) -> void:
    _world = world

func set_origin(c: Vector2i) -> void:
    origin = c
    occupied.clear()

func mark_occupied(cell: Vector2i) -> void:
    occupied[cell] = true

func is_cell_empty(world: Node, cell: Vector2i) -> bool:
    var in_bounds: bool = cell.x >= 0 and cell.x < world.width and cell.y >= 0 and cell.y < world.height
    if not in_bounds:
        return false
    var life_data: TileData = world.hexmap.get_cell_tile_data(world.LAYER_LIFE, cell)
    if life_data != null:
        return false
    var object_data: TileData = world.hexmap.get_cell_tile_data(world.LAYER_OBJECTS, cell)
    if object_data != null:
        return false
    return true

func neighbors_even_q(c: Vector2i) -> Array[Vector2i]:
    if _world != null and _world.has_method("neighbors_even_q"):
        return _world.neighbors_even_q(c)
    return []

func is_adjacent_to_network(world: Node, cell: Vector2i) -> bool:
    set_world(world)
    for neighbor in neighbors_even_q(cell):
        if neighbor == origin:
            return true
        var life_data := world.hexmap.get_cell_tile_data(world.LAYER_LIFE, neighbor)
        if life_data != null:
            return true
    return false

func can_place(world: Node, cell: Vector2i) -> bool:
    set_world(world)
    return is_cell_empty(world, cell) and is_adjacent_to_network(world, cell)
