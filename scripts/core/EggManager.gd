extends Node

const Coord := preload("res://scripts/core/Coord.gd")

signal eggs_changed(current: int)
signal egg_assigned(q: int, r: int)
signal egg_needed(q: int, r: int)

@export var eggs: int = 3
var waiting_brood: Array[Vector2i] = []
var queen_position: Vector2i = Vector2i.ZERO

func _ready() -> void:
	waiting_brood = []
	eggs = max(0, eggs)
	emit_signal("eggs_changed", eggs)

func add_eggs(amount: int) -> void:
	if amount <= 0:
		return
	eggs += amount
	emit_signal("eggs_changed", eggs)
	_dispatch_waiting()

func request_egg(cell_q: int, cell_r: int) -> bool:
	if eggs > 0:
		eggs -= 1
		emit_signal("eggs_changed", eggs)
		emit_signal("egg_assigned", cell_q, cell_r)
		return true

	var coord := Vector2i(cell_q, cell_r)
	if waiting_brood.find(coord) == -1:
		_enqueue_waiting(coord)
		emit_signal("egg_needed", cell_q, cell_r)
	return false

func refund_egg(count: int = 1) -> void:
	if count <= 0:
		return
	eggs += count
	emit_signal("eggs_changed", eggs)
	_dispatch_waiting()

func _dispatch_waiting() -> void:
	while eggs > 0 and not waiting_brood.is_empty():
		var coord: Vector2i = waiting_brood.pop_front()
		eggs -= 1
		emit_signal("eggs_changed", eggs)
		emit_signal("egg_assigned", coord.x, coord.y)

func set_queen_position(q: int, r: int) -> void:
	queen_position = Vector2i(q, r)
	_sort_waiting()
	_dispatch_waiting()

func _enqueue_waiting(coord: Vector2i) -> void:
	waiting_brood.append(coord)
	_sort_waiting()

func _sort_waiting() -> void:
	if waiting_brood.size() <= 1:
		return
	waiting_brood.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		var dist_a := _distance_to_queen(a)
		var dist_b := _distance_to_queen(b)
		if dist_a == dist_b:
			if a.x == b.x:
				return a.y < b.y
			return a.x < b.x
		return dist_a < dist_b
	)

func _distance_to_queen(coord: Vector2i) -> int:
	return Coord.axial_distance(coord, queen_position)
