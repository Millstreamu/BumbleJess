extends Node2D

@export var cell: Vector2i = Vector2i.ZERO

@onready var world: Node = get_parent()
@onready var camera: Camera2D = get_node("../Camera")
@onready var highlight := $Highlight

func _ready() -> void:
    set_process_unhandled_input(true)
    _update_position()

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

    if moved:
        cell = world.call("clamp_cell", cell)
        _update_position()
        _ping()

func _update_position() -> void:
    position = world.call("cell_to_world", cell)
    if camera:
        camera.global_position = global_position

func _ping() -> void:
    if highlight == null:
        return
    highlight.scale = Vector2(0.9, 0.9)
    var tween := create_tween()
    tween.tween_property(highlight, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
