extends Node

const Coord := preload("res://scripts/core/Coord.gd")

signal eggs_changed(current: int)
signal egg_assigned(q: int, r: int)
signal egg_needed(q: int, r: int)

@export var eggs: int = 0
var waiting_brood: Array[Vector2i] = []
var queen_position: Vector2i = Vector2i.ZERO

func _ready() -> void:
    waiting_brood = []
    eggs = max(0, eggs)
    emit_signal("eggs_changed", eggs)
    print("[EggManager] Initial egg count: %d." % eggs)

func add_eggs(amount: int) -> void:
    if amount <= 0:
        return
    eggs += amount
    emit_signal("eggs_changed", eggs)
    print("[EggManager] Eggs added -> %d available." % eggs)
    _dispatch_waiting()

func request_egg(cell_q: int, cell_r: int) -> bool:
    print("[EggManager] Egg requested by brood (%d,%d); %d eggs available, %d broods waiting." % [cell_q, cell_r, eggs, waiting_brood.size()])
    if eggs > 0:
        eggs -= 1
        emit_signal("eggs_changed", eggs)
        emit_signal("egg_assigned", cell_q, cell_r)
        print("[EggManager] Assigned egg to brood (%d,%d)." % [cell_q, cell_r])
        return true

    var coord := Vector2i(cell_q, cell_r)
    if waiting_brood.find(coord) == -1:
        _enqueue_waiting(coord)
        emit_signal("egg_needed", cell_q, cell_r)
        print("[EggManager] Brood (%d,%d) queued for egg; %d waiting." % [cell_q, cell_r, waiting_brood.size()])
        _debug_waiting_queue()
    return false

func refund_egg(count: int = 1) -> void:
    if count <= 0:
        return
    eggs += count
    emit_signal("eggs_changed", eggs)
    print("[EggManager] Egg refund -> %d available." % eggs)
    _dispatch_waiting()

func _dispatch_waiting() -> void:
    if waiting_brood.is_empty():
        print("[EggManager] Dispatch check -> queue empty, %d eggs available." % eggs)
    else:
        print("[EggManager] Dispatch check -> %d eggs available, queue depth %d." % [eggs, waiting_brood.size()])
        _debug_waiting_queue()

    while eggs > 0 and not waiting_brood.is_empty():
        var coord: Vector2i = waiting_brood.pop_front()
        eggs -= 1
        emit_signal("eggs_changed", eggs)
        emit_signal("egg_assigned", coord.x, coord.y)
        print("[EggManager] Assigned egg to brood (%d,%d)." % [coord.x, coord.y])
        if not waiting_brood.is_empty():
            print("[EggManager] %d broods still waiting after dispatch." % waiting_brood.size())
            _debug_waiting_queue()
    if waiting_brood.is_empty():
        print("[EggManager] Dispatch complete -> %d eggs remaining." % eggs)
    else:
        print("[EggManager] Dispatch paused -> %d eggs remaining, %d broods still waiting." % [eggs, waiting_brood.size()])
        _debug_waiting_queue()

func set_queen_position(q: int, r: int) -> void:
    queen_position = Vector2i(q, r)
    _sort_waiting()
    _dispatch_waiting()

func _enqueue_waiting(coord: Vector2i) -> void:
    waiting_brood.append(coord)
    _sort_waiting()

func _debug_waiting_queue() -> void:
    if waiting_brood.is_empty():
        print("[EggManager] Waiting queue -> (empty)")
        return
    var entries: Array[String] = []
    for queued in waiting_brood:
        entries.append("(%d,%d)" % [queued.x, queued.y])
    print("[EggManager] Waiting queue -> %s" % ", ".join(entries))

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
