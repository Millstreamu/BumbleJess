extends Node2D

## Visual representation of a single hex cell. Handles rendering, selection, and
## simple growth indicators.
class_name HexCell

@onready var polygon: Polygon2D = $Polygon2D
@onready var buildable_overlay: Polygon2D = $BuildableOverlay
@onready var growth_badge: Polygon2D = $GrowthBadge
@onready var sprout_label: Label = $SproutLabel

var axial: Vector2i = Vector2i.ZERO
var _cell_size: float = 52.0
var _cell_color: Color = Color.WHITE
var _selection_color: Color = Color.DARK_GREEN
var _buildable_color: Color = Color(0.8, 0.8, 0.8, 0.35)
var _is_selected := false
var _flash_tween: Tween

var _show_growth_progress: bool = false
var _growth_elapsed: int = 0
var _growth_total: int = 0

func configure(axial_coord: Vector2i, cell_size: float, selection_color: Color, initial_color: Color) -> void:
	axial = axial_coord
	_cell_size = cell_size
	_selection_color = selection_color
	_cell_color = initial_color
	polygon.polygon = _build_polygon_points(cell_size)
	polygon.modulate = Color.WHITE
	buildable_overlay.polygon = _build_polygon_points(cell_size)
	buildable_overlay.visible = false
	buildable_overlay.color = _buildable_color
	growth_badge.polygon = _build_polygon_points(cell_size * 0.35)
	growth_badge.visible = false
	sprout_label.text = ""
	sprout_label.visible = false
	_show_growth_progress = false
	_growth_elapsed = 0
	_growth_total = 0
	_apply_color()

func set_selected(selected: bool) -> void:
	_is_selected = selected
	_apply_color()

func toggle_selected() -> void:
	set_selected(not _is_selected)

func is_selected() -> bool:
	return _is_selected

func set_cell_color(color: Color) -> void:
	_cell_color = color
	_apply_color()

func set_buildable_highlight(active: bool, color: Color) -> void:
	_buildable_color = color
	if buildable_overlay:
		buildable_overlay.color = _buildable_color
		buildable_overlay.visible = active

func flash(duration: float = 0.2) -> void:
	if _flash_tween:
		_flash_tween.kill()
	polygon.modulate = Color(1.4, 1.4, 1.4, 1.0)
	_flash_tween = create_tween()
	_flash_tween.tween_property(polygon, "modulate", Color.WHITE, duration)

func show_grove_badge(active: bool) -> void:
	growth_badge.visible = active

func set_sprout_count(count: int) -> void:
	if count <= 0:
		sprout_label.visible = false
		sprout_label.text = ""
	else:
		sprout_label.visible = true
		sprout_label.text = str(count)

func set_growth_progress(elapsed: int, total: int, active: bool) -> void:
	_growth_elapsed = max(elapsed, 0)
	_growth_total = max(total, 0)
	_show_growth_progress = active and _growth_total > 0
	if not _show_growth_progress:
		queue_redraw()
		return
	_growth_elapsed = clamp(_growth_elapsed, 0, _growth_total)
	queue_redraw()

func _apply_color() -> void:
	polygon.color = _selection_color if _is_selected else _cell_color

func _build_polygon_points(cell_size: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in range(6):
		var angle := PI / 180.0 * (60.0 * i)
		points.append(Vector2(cos(angle), sin(angle)) * cell_size)
	return points

func _draw() -> void:
	if not _show_growth_progress:
		return
	if _growth_total <= 0:
		return
	var progress: float = 0.0
	if _growth_total > 0:
		progress = clamp(float(_growth_elapsed) / float(_growth_total), 0.0, 1.0)
	var radius: float = _cell_size * 0.7
	var ring_width: float = 2.0
	var backdrop_color := Color(1, 1, 1, 0.15)
	draw_circle(Vector2.ZERO, radius + ring_width * 0.5, backdrop_color)
	if progress <= 0.0:
		return
	var start_angle: float = -PI / 2.0
	var end_angle: float = start_angle + TAU * progress
	draw_arc(Vector2.ZERO, radius, start_angle, end_angle, 64, Color(1, 1, 1, 0.85), ring_width, true)
