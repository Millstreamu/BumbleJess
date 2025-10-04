extends Node2D

## Visual representation of a single hex cell. Handles rendering of the hexagon
## and state transitions for highlighting and selection.
class_name HexCell

@onready var polygon: Polygon2D = $Polygon2D
@onready var ready_badge: Polygon2D = $ReadyBadge

enum BroodState { IDLE, INCUBATING, READY, DAMAGED }

var axial: Vector2i = Vector2i.ZERO
var _cell_size: float = 52.0
var _cell_color: Color = Color.WHITE
var _selection_color: Color = Color.DARK_GOLDENROD
var _is_selected := false
var _flash_tween: Tween
var _base_modulate: Color = Color.WHITE

var is_brood: bool = false
var brood_state: int = BroodState.IDLE
var hatch_remaining: float = 0.0
var hatch_duration: float = 0.0
var has_egg: bool = false
var progress_ring_width: float = 2.0
var progress_ring_color: Color = Color(1, 1, 1, 0.9)
var damaged_tint: Color = Color.WHITE

func configure(axial_coord: Vector2i, cell_size: float, selection_color: Color, initial_color: Color, ring_width: float = 2.0, ring_color: Color = Color(1, 1, 1, 0.9), damaged_color: Color = Color.WHITE) -> void:
    axial = axial_coord
    _cell_size = cell_size
    _selection_color = selection_color
    _cell_color = initial_color
    progress_ring_width = ring_width
    progress_ring_color = ring_color
    damaged_tint = damaged_color
    _base_modulate = Color.WHITE
    polygon.polygon = _build_polygon_points(cell_size)
    polygon.modulate = _base_modulate
    ready_badge.polygon = _build_polygon_points(cell_size * 0.35)
    clear_brood_state()
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

func flash(duration: float = 0.2) -> void:
    if _flash_tween:
        _flash_tween.kill()
    polygon.modulate = Color(1.4, 1.4, 1.4, 1.0)
    _flash_tween = create_tween()
    _flash_tween.tween_property(polygon, "modulate", _base_modulate, duration)

func set_ready_state(is_ready: bool) -> void:
    ready_badge.visible = is_ready

func clear_brood_state() -> void:
    is_brood = false
    brood_state = BroodState.IDLE
    has_egg = false
    hatch_remaining = 0.0
    hatch_duration = 0.0
    ready_badge.visible = false
    _set_base_modulate(Color.WHITE)
    queue_redraw()

func set_brood_state(state: int, has_egg_value: bool, remaining: float, duration: float) -> void:
    is_brood = true
    brood_state = state
    has_egg = has_egg_value
    hatch_duration = max(duration, 0.0)
    hatch_remaining = max(remaining, 0.0)
    ready_badge.visible = state == BroodState.READY
    if state == BroodState.DAMAGED:
        _set_base_modulate(damaged_tint)
    else:
        _set_base_modulate(Color.WHITE)
    queue_redraw()

func update_brood_progress(remaining: float) -> void:
    hatch_remaining = max(remaining, 0.0)
    queue_redraw()

func _apply_color() -> void:
    if _is_selected:
        polygon.color = _selection_color
    else:
        polygon.color = _cell_color

func _set_base_modulate(color: Color) -> void:
    _base_modulate = color
    polygon.modulate = _base_modulate

func _build_polygon_points(cell_size: float) -> PackedVector2Array:
    var points := PackedVector2Array()
    for i in range(6):
        var angle := PI / 180.0 * (60.0 * i)
        points.append(Vector2(cos(angle), sin(angle)) * cell_size)
    return points

func _draw() -> void:
    if not is_brood:
        return
    if brood_state != BroodState.INCUBATING:
        return
    if hatch_duration <= 0.0:
        return

    var progress := clamp(1.0 - (hatch_remaining / hatch_duration), 0.0, 1.0)
    var radius := _cell_size * 0.7
    var ring_width := max(1.0, progress_ring_width)
    var backdrop_color := progress_ring_color.with_alpha(progress_ring_color.a * 0.25)
    draw_circle(Vector2.ZERO, radius + ring_width * 0.5, backdrop_color)
    if progress <= 0.0:
        return
    var start_angle := -PI / 2.0
    var end_angle := start_angle + TAU * progress
    draw_arc(Vector2.ZERO, radius, start_angle, end_angle, 64, progress_ring_color, ring_width, true)
