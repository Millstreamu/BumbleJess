extends Panel
class_name TotemCard

signal pressed(card_id: String)

@export var card_id: String = ""
@export var base_size: Vector2 = Vector2(640, 220)
@export var art: Texture2D
@export var title: String = ""
@export var body: String = ""

@onready var _art_wrap: AspectRatioContainer = $HBoxContainer/ArtWrap
@onready var _art: TextureRect = $HBoxContainer/ArtWrap/Art
@onready var _text_box: VBoxContainer = $HBoxContainer/Text
@onready var _title: Label = $HBoxContainer/Text/Title
@onready var _body: RichTextLabel = $HBoxContainer/Text/Body
@onready var _chosen: Control = $Chosen

var _title_target_font: int = 18
var _body_target_font: int = 14
var _body_adjust_queued: bool = false
var _disabled: bool = false

func _ready() -> void:
	focus_mode = Control.FOCUS_ALL
	custom_minimum_size = base_size
	_body.scroll_active = false
	_body.fit_content = false
	set_selected(false)
	_apply()
	connect("gui_input", _on_gui_input)
	connect("focus_entered", _on_focus_entered)
	connect("focus_exited", _on_focus_exited)
	connect("mouse_entered", Callable(self, "_on_mouse_entered"))

func _on_mouse_entered() -> void:
	if _disabled:
		return
	grab_focus()

func set_data(p: Dictionary) -> void:
	card_id = str(p.get("id", card_id))
	title = str(p.get("title", title))
	body = str(p.get("body", body))
	art = p.get("art", art)
	_apply()

func set_selected(selected: bool) -> void:
	if _chosen != null:
		_chosen.visible = selected

func set_disabled(value: bool) -> void:
	_disabled = value
	focus_mode = Control.FOCUS_ALL if not value else Control.FOCUS_NONE
	mouse_filter = Control.MOUSE_FILTER_IGNORE if value else Control.MOUSE_FILTER_STOP
	if value and has_focus():
		release_focus()

func _apply() -> void:
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
	_refresh_layout()

func _on_gui_input(event: InputEvent) -> void:
	if _disabled:
		return
	if event.is_action_pressed("ui_accept"):
		emit_signal("pressed", card_id)
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MouseButton.LEFT and mb.pressed:
			emit_signal("pressed", card_id)

func _on_focus_entered() -> void:
	add_theme_color_override("panel", Color(0.85, 0.9, 1, 0.15))

func _on_focus_exited() -> void:
	add_theme_color_override("panel", Color(1, 1, 1, 0))

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_refresh_layout()

func _refresh_layout() -> void:
	if not is_inside_tree():
		return
	var inner_w := max(size.x - 32.0, 1.0)
	var inner_h := max(size.y - 32.0, 1.0)
	var art_side := min(inner_h, inner_w * 0.4)
	_art_wrap.custom_minimum_size = Vector2(art_side, art_side)
	var scale := clamp(inner_w / max(base_size.x - 32.0, 1.0), 0.6, 1.8)
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
	var available_height := _compute_body_available_height()
	var target_sizes: Array = [
		_body_target_font,
		max(_body_target_font - 2, 11),
		max(_body_target_font - 4, 11)
	]
	for size_idx in range(target_sizes.size()):
		var font_size: int = target_sizes[size_idx]
		_body.add_theme_font_size_override("normal_font_size", font_size)
		_body.reset_size()
		var content_height := _body.get_content_height()
		if content_height <= available_height or size_idx == target_sizes.size() - 1:
			_set_body_line_limit(available_height)
			break

func _compute_body_available_height() -> float:
	var inner_h := max(size.y - 32.0, 0.0)
	var spacing := float(_text_box.separation)
	var title_h := _title.get_combined_minimum_size().y
	var available := inner_h - title_h - spacing
	return max(available, 0.0)

func _set_body_line_limit(available_height: float) -> void:
	if available_height <= 0.0:
		_body.max_lines_visible = 0
		return
	var line_height := _body.get_line_height()
	if line_height <= 0.0:
		_body.max_lines_visible = -1
		return
	var max_lines := int(floor(available_height / line_height))
	if max_lines <= 0:
		_body.max_lines_visible = 1
	else:
		_body.max_lines_visible = max_lines
