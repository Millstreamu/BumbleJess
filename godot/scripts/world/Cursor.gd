extends Node2D

@export var cell: Vector2i = Vector2i.ZERO

@onready var world: Node = get_parent()
@onready var cam: Camera2D = get_node("../Camera")
@onready var highlight := $Highlight

func _ready() -> void:
    set_process_unhandled_input(true)
    position = world.call("cell_to_world", cell)
    if cam:
        cam.global_position = global_position
    _update_highlight()

func _unhandled_input(event: InputEvent) -> void:
    var moved := false
    if event.is_action_pressed("ui_left"):
        cell.x -= 1
        moved = true
    elif event.is_action_pressed("ui_right"):
        cell.x += 1
        moved = true
    elif event.is_action_pressed("ui_up"):
        cell.y -= 1
        moved = true
    elif event.is_action_pressed("ui_down"):
        cell.y += 1
        moved = true
    elif event.is_action_pressed("ui_accept"):
        world.call("attempt_place_at", cell)
        _update_highlight()

    if moved:
        cell = world.call("clamp_cell", cell)
        position = world.call("cell_to_world", cell)
        if cam:
            cam.global_position = global_position
        var tw := create_tween()
        scale = Vector2.ONE * 0.95
        tw.tween_property(self, "scale", Vector2.ONE, 0.08)
        _update_highlight()

func _update_highlight() -> void:
    if highlight == null:
        return
    var can_place := false
    if world.has_method("can_place_at"):
        can_place = world.call("can_place_at", cell)
    highlight.color = can_place ? Color(1, 1, 1, 0.4) : Color(1, 0.3, 0.3, 0.5)

func move_to(new_cell: Vector2i) -> void:
    cell = world.call("clamp_cell", new_cell)
    position = world.call("cell_to_world", cell)
    if cam:
        cam.global_position = global_position
    _update_highlight()

func update_highlight_state() -> void:
    _update_highlight()
