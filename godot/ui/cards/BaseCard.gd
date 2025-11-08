extends Panel
class_name BaseCard

signal pressed(card_id: String)

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

func _on_mouse_entered() -> void:
	grab_focus()

func _on_gui_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept"):
		emit_signal("pressed", card_id)

func _on_focus_entered() -> void:
	add_theme_color_override("panel", Color(0.85, 0.9, 1, 0.15))

func _on_focus_exited() -> void:
	add_theme_color_override("panel", Color(1, 1, 1, 0))

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

func _apply_content() -> void:
	_title.text = title
	_title.tooltip_text = title
	if _body.bbcode_enabled:
		_body.bbcode_text = body
	else:
		_body.text = body
	if art and art is Texture2D:
		_art.texture = art
	else:
		_art.texture = null

func _apply_layout() -> void:
	if not is_inside_tree():
		return
	var w: float = max(size.x, base_size.x)
	var h: float = max(size.y, base_size.y)
	var img_h: float = min(w, h * 0.55)
	_art_wrap.custom_minimum_size = Vector2(0, img_h)
	var scale: float = clamp(w / max(base_size.x, 1.0), 0.6, 1.8)
	_title_target_font = clamp(roundi(18.0 * scale), 14, 24)
	_body_target_font = clamp(roundi(14.0 * scale), 11, 18)
	_title.add_theme_font_size_override("font_size", _title_target_font)
	_body.add_theme_font_size_override("normal_font_size", _body_target_font)
	_title.clip_text = true
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
