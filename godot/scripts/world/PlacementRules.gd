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
	if world == null or not world.has_method("is_empty"):
		return false
	var in_bounds: bool = cell.x >= 0 and cell.x < world.width and cell.y >= 0 and cell.y < world.height
	if not in_bounds:
		return false
	if not world.is_empty(world.LAYER_LIFE, cell):
		return false
	if not world.is_empty(world.LAYER_OBJECTS, cell):
		return false
	return true

func neighbors_even_q(c: Vector2i) -> Array[Vector2i]:
	if _world != null and _world.has_method("neighbors_even_q"):
		return _world.neighbors_even_q(c)
	return [] as Array[Vector2i]

func is_adjacent_to_network(world: Node, cell: Vector2i) -> bool:
	set_world(world)
	if world == null or not world.has_method("is_empty"):
		return false
	for neighbor in neighbors_even_q(cell):
		if neighbor == origin:
			return true
		if not world.is_empty(world.LAYER_LIFE, neighbor):
			return true
	return false

func can_place(world: Node, cell: Vector2i) -> bool:
	set_world(world)
	return is_cell_empty(world, cell) and is_adjacent_to_network(world, cell)
