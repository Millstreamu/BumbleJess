extends Node2D

@export var cell: Vector2i = Vector2i.ZERO

@onready var world: Node = get_parent()
@onready var cam: Camera2D = get_node("../Camera")
@onready var highlight: CanvasItem = $Highlight

func _ready() -> void:
	set_process_unhandled_input(true)
	position = world.call("cell_to_world", cell)
	if cam:
		cam.global_position = global_position
	_configure_highlight_shape()
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
		elif event is InputEventMouseMotion:
				_update_from_mouse_motion()
		elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
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

func _update_from_mouse_motion() -> void:
		if world == null:
				return
		var mouse_world: Vector2 = world.to_local(get_global_mouse_position())
		var hovered_cell: Vector2i = world.call("world_to_map", mouse_world)
		hovered_cell = world.call("clamp_cell", hovered_cell)
		if hovered_cell == cell:
				return
		cell = hovered_cell
		position = world.call("cell_to_world", cell)
		if cam:
				cam.global_position = global_position
		_update_highlight()

func _update_highlight() -> void:
	if highlight == null:
		return
	var can_place := false
	if world.has_method("can_place_at"):
		can_place = world.call("can_place_at", cell)
	highlight.color = Color(1, 1, 1, 0.4) if can_place else Color(1, 0.3, 0.3, 0.5)

func move_to(new_cell: Vector2i) -> void:
	cell = world.call("clamp_cell", new_cell)
	position = world.call("cell_to_world", cell)
	if cam:
		cam.global_position = global_position
	_configure_highlight_shape()
	_update_highlight()

func update_highlight_state() -> void:
	_configure_highlight_shape()
	_update_highlight()

func _configure_highlight_shape() -> void:
	if highlight == null or world == null:
		return
	if highlight is Polygon2D:
		var poly := PackedVector2Array()
		var tile_size := float(world.tile_px)
		var radius := max(tile_size * 0.5 - 2.0, 1.0)
		for i in range(6):
			var angle := deg_to_rad(60.0 * i - 30.0)
			poly.push_back(Vector2(cos(angle), sin(angle)) * radius)
		(highlight as Polygon2D).polygon = poly
