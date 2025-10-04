extends Node
class_name EggManager

signal eggs_changed(current: int)
signal egg_assigned(q: int, r: int)
signal egg_needed(q: int, r: int)

@export var eggs: int = 0
var waiting_brood: Array[Vector2i] = []

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
        print("[EggManager] Assigned egg to brood (%d,%d)." % [cell_q, cell_r])
        return true

    var coord := Vector2i(cell_q, cell_r)
    if waiting_brood.find(coord) == -1:
        waiting_brood.append(coord)
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
        print("[EggManager] Assigned egg to brood (%d,%d)." % [coord.x, coord.y])
