extends Node2D
## Draws a debug hex grid and manages a cursor that moves in axial space.
class_name HexGridDebug

const Hex := preload("res://src/core/Hex.gd")
const InputMapConfig := preload("res://src/core/InputMap.gd")
const CursorScene := preload("res://scenes/Cursor.tscn")

@export var radius: int = 7
@export var cell_size: float = 32.0
@export var grid_color: Color = Color(0.4, 0.4, 0.4, 0.8)

var _cursor_axial := Hex.Axial.new()
var _cursor_node: HexCursorDisplay

func _ready() -> void:
		InputMapConfig.apply()
		_spawn_cursor()
		queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
		if event.is_action_pressed("ui_left"):
				_try_move_cursor(Vector2i(-1, 0))
		elif event.is_action_pressed("ui_right"):
				_try_move_cursor(Vector2i(1, 0))
		elif event.is_action_pressed("ui_up"):
				_try_move_cursor(Vector2i(0, -1))
		elif event.is_action_pressed("ui_down"):
				_try_move_cursor(Vector2i(0, 1))

func _draw() -> void:
		for axial in _enumerate_hexes():
				var center := Hex.axial_to_world(axial, cell_size)
				var points := _hex_outline(center)
				if points.size() > 1:
						draw_polyline(points, grid_color, 1.0)

func _spawn_cursor() -> void:
		if _cursor_node:
				remove_child(_cursor_node)
				_cursor_node.queue_free()
		_cursor_node = CursorScene.instantiate()
		add_child(_cursor_node)
		_cursor_node.set_cell_size(cell_size)
		_cursor_node.position = Hex.axial_to_world(_cursor_axial, cell_size)

func _try_move_cursor(delta: Vector2i) -> void:
		var target := Hex.Axial.new(_cursor_axial.q + delta.x, _cursor_axial.r + delta.y)
		if Hex.distance(target, Hex.Axial.new()) > radius:
				return
		_cursor_axial = target
		if _cursor_node:
				_cursor_node.position = Hex.axial_to_world(_cursor_axial, cell_size)

func _enumerate_hexes() -> Array[Hex.Axial]:
		var results: Array[Hex.Axial] = []
		for q in range(-radius, radius + 1):
				for r in range(-radius, radius + 1):
						if abs(q + r) > radius:
								continue
						results.append(Hex.Axial.new(q, r))
		return results

func _hex_outline(center: Vector2) -> PackedVector2Array:
		var outline := PackedVector2Array()
		var radius_world := cell_size
		for index in range(6):
				var angle := deg_to_rad(60.0 * index + 30.0)
				var point := center + Vector2(cos(angle), sin(angle)) * radius_world
				outline.append(point)
		outline.append(outline[0])
		return outline
