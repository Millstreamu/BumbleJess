extends Panel
class_name BaseCard

signal pressed(card_id: String)

const PANEL_COLOR_DEFAULT := Color(1, 1, 1, 0)
const PANEL_COLOR_FOCUSED := Color(0.85, 0.9, 1, 0.15)
const PANEL_COLOR_SELECTED := Color(1, 0.94, 0.6, 0.35)
const PANEL_COLOR_SELECTED_FOCUSED := Color(0.9, 1, 0.7, 0.45)

@export var card_id: String = ""
@export var base_size: Vector2 = Vector2(280, 360)
@export var art: Texture2D
@export var title: String = ""
@export var body: String = ""

@onready var _root: VBoxContainer = $Root
@onready var _art_wrap: AspectRatioContainer = $Root/ArtWrap
@onready var _art: TextureRect = $Root/ArtWrap/Art
@onready var _title: Label = $Root/Title
@onready var _body: RichTextLabel = $Root/Body

var _body_target_font: int = 14
var _title_target_font: int = 18
var _body_adjust_queued: bool = false
var _selected: bool = false

func _ready() -> void:
	focus_mode = Control.FOCUS_ALL
	custom_minimum_size = base_size
	_body.scroll_active = false
	_body.scroll_following = false
	_body.fit_content = false
	_root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_apply_content()
	_apply_layout()
	connect("gui_input", _on_gui_input)
	connect("focus_entered", _on_focus_entered)
	connect("focus_exited", _on_focus_exited)
	connect("mouse_entered", Callable(self, "_on_mouse_entered"))
	_apply_selection_style()

func _on_mouse_entered() -> void:
	grab_focus()

func _on_gui_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept"):
		emit_signal("pressed", card_id)

func _on_focus_entered() -> void:
	_apply_selection_style()

func _on_focus_exited() -> void:
	_apply_selection_style()

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_apply_layout()

func set_data(p: Dictionary) -> void:
	card_id = str(p.get("id", card_id))
	title = str(p.get("title", title))
	body = str(p.get("body", body))
	art = p.get("art", art)
	_apply_content()
	_apply_layout()
	_apply_selection_style()

func set_selected(selected: bool) -> void:
	var wanted := bool(selected)
	if wanted == _selected:
		return
	_selected = wanted
	_apply_selection_style()

func is_selected() -> bool:
	return _selected

func _apply_content() -> void:
	if is_instance_valid(_title):
		_title.text = title
		_title.tooltip_text = title

	if is_instance_valid(_body):
		if _body.bbcode_enabled:
			_body.clear()
			_body.parse_bbcode(body) # <- use this in Godot 4
		else:
			_body.text = body

	if is_instance_valid(_art):
		if art is Texture2D and art != null:
			_art.texture = art
		else:
			_art.texture = null

func _apply_layout() -> void:
	if not is_inside_tree():
		return

	var w: float = max(size.x, base_size.x)
	var h: float = max(size.y, base_size.y)
	var img_h: float = min(w, h * 0.55)

	# Guard: _art_wrap can be null if the node path is wrong or not ready yet
	if is_instance_valid(_art_wrap):
		_art_wrap.custom_minimum_size = Vector2(0.0, img_h)

	var scale_factor: float = clamp(w / max(base_size.x, 1.0), 0.6, 1.8)
	_title_target_font = clamp(roundi(18.0 * scale_factor), 14, 24)
	_body_target_font  = clamp(roundi(14.0 * scale_factor), 11, 18)

	# Guard title/body too
	if is_instance_valid(_title):
		_title.add_theme_font_size_override("font_size", _title_target_font)
		_title.clip_text = true

	if is_instance_valid(_body):
		_body.add_theme_font_size_override("normal_font_size", _body_target_font)

	# Defer body sizing to next frame once only
	if not _body_adjust_queued:
		_body_adjust_queued = true
		call_deferred("_update_body_fit")


func _update_body_fit() -> void:
	_body_adjust_queued = false
	if not is_inside_tree():
		return
	var available_height: float = _compute_body_available_height()
	var target_sizes: Array[int] = [
		_body_target_font,
		max(_body_target_font - 2, 11),
		max(_body_target_font - 4, 11)
	]
	for size_idx in range(target_sizes.size()):
		var font_size: int = target_sizes[size_idx]
		_body.add_theme_font_size_override("normal_font_size", font_size)
		_body.reset_size()
		var content_height: float = _body.get_content_height()
		if content_height <= available_height or size_idx == target_sizes.size() - 1:
			_set_body_line_limit(available_height)
			break

func _compute_body_available_height() -> float:
	var h: float = max(size.y, 0.0)
	var spacing: float = float(_root.separation)
	var title_h: float = _title.get_combined_minimum_size().y
	var available: float = h - _art_wrap.custom_minimum_size.y - title_h - spacing * 2.0
	return max(available, 0.0)

func _set_body_line_limit(available_height: float) -> void:
	if available_height <= 0.0:
		_body.max_lines_visible = 0
		return
	var line_height: float = _body.get_line_height()
	if line_height <= 0.0:
		_body.max_lines_visible = -1
		return
	var max_lines: int = int(floor(available_height / line_height))
	if max_lines <= 0:
		_body.max_lines_visible = 1
	else:
		_body.max_lines_visible = max_lines

func _apply_selection_style() -> void:
	if not is_inside_tree():
		return
	var color := PANEL_COLOR_DEFAULT
	if _selected:
		color = PANEL_COLOR_SELECTED
	if has_focus():
		color = PANEL_COLOR_FOCUSED if not _selected else PANEL_COLOR_SELECTED_FOCUSED
	add_theme_color_override("panel", color)
