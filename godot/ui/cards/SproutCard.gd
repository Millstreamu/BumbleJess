extends Panel
class_name SproutCard

signal pressed(card_id: String)

@export var card_id: String = ""
@export var base_size: Vector2 = Vector2(640, 220)
@export var portrait: Texture2D
@export var name_text: String = ""
@export var hp: int = 0
@export var atk: int = 0
@export var spd: float = 1.0
@export var attack_name: String = ""
@export var passive_name: String = ""
@export var desc: String = ""

@onready var _portrait_wrap: Panel = $HBoxContainer/PortraitWrap
@onready var _portrait: TextureRect = $HBoxContainer/PortraitWrap/Portrait
@onready var _name: Label = $HBoxContainer/Text/Name
@onready var _stats_row: HBoxContainer = $HBoxContainer/Text/StatsRow
@onready var _stats_hp: Label = $HBoxContainer/Text/StatsRow/HP
@onready var _stats_atk: Label = $HBoxContainer/Text/StatsRow/ATK
@onready var _stats_spd: Label = $HBoxContainer/Text/StatsRow/SPD
@onready var _atk_name: Label = $HBoxContainer/Text/AttackName
@onready var _pas_name: Label = $HBoxContainer/Text/PassiveName
@onready var _desc: RichTextLabel = $HBoxContainer/Text/Desc
@onready var _text_box: VBoxContainer = $HBoxContainer/Text
@onready var _chosen: Control = $Chosen

var _name_target_font: int = 20
var _text_target_font: int = 14
var _body_adjust_queued: bool = false
var _disabled: bool = false

func _ready() -> void:
	focus_mode = Control.FOCUS_ALL
	custom_minimum_size = base_size
	_desc.scroll_active = false
	_desc.fit_content = false
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
	name_text = str(p.get("name", name_text))
	hp = int(p.get("hp", hp))
	atk = int(p.get("atk", atk))
	spd = float(p.get("spd", spd))
	attack_name = str(p.get("attack_name", attack_name))
	passive_name = str(p.get("passive_name", passive_name))
	desc = str(p.get("desc", desc))
	portrait = p.get("portrait", portrait)
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
	_name.text = name_text
	_name.tooltip_text = name_text
	_stats_hp.text = "HP: %d" % hp
	_stats_atk.text = "ATK: %d" % atk
	_stats_spd.text = "SPD: %.2f" % spd
	var atk_label := attack_name.strip_edges()
	if atk_label.is_empty():
		atk_label = "Attack: —"
	_atk_name.text = atk_label
	var passive_label := passive_name.strip_edges()
	if passive_label.is_empty():
		passive_label = "Passive: —"
	_pas_name.text = passive_label
	if _desc.bbcode_enabled:
		_desc.bbcode_text = desc
	else:
		_desc.text = desc
	if portrait and portrait is Texture2D:
		_portrait.texture = portrait
	else:
		_portrait.texture = null
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
	var inner_h := max(size.y - 32.0, 1.0)
	_portrait_wrap.custom_minimum_size = Vector2(inner_h, inner_h)
	var inner_w := max(size.x - 32.0, 1.0)
	var scale := clamp(inner_w / max(base_size.x - 32.0, 1.0), 0.6, 1.8)
	_name_target_font = clamp(roundi(20.0 * scale), 16, 26)
	_text_target_font = clamp(roundi(14.0 * scale), 11, 18)
	_name.add_theme_font_size_override("font_size", _name_target_font)
	_atk_name.add_theme_font_size_override("font_size", _text_target_font)
	_pas_name.add_theme_font_size_override("font_size", _text_target_font)
	_stats_hp.add_theme_font_size_override("font_size", _text_target_font)
	_stats_atk.add_theme_font_size_override("font_size", _text_target_font)
	_stats_spd.add_theme_font_size_override("font_size", _text_target_font)
	_desc.add_theme_font_size_override("normal_font_size", _text_target_font)
	_name.clip_text = true
	if not _body_adjust_queued:
		_body_adjust_queued = true
		call_deferred("_update_body_fit")

func _update_body_fit() -> void:
	_body_adjust_queued = false
	if not is_inside_tree():
		return
	var available_height := _compute_body_available_height()
	var sizes: Array = [
		_text_target_font,
		max(_text_target_font - 2, 11),
		max(_text_target_font - 4, 11)
	]
	for size_idx in range(sizes.size()):
		var font_size: int = sizes[size_idx]
		_desc.add_theme_font_size_override("normal_font_size", font_size)
		_desc.reset_size()
		var content_height := _desc.get_content_height()
		if content_height <= available_height or size_idx == sizes.size() - 1:
			_set_desc_line_limit(available_height)
			break

func _compute_body_available_height() -> float:
	var inner_h := max(size.y - 32.0, 0.0)
	var spacing := float(_text_box.separation)
	var used := _name.get_combined_minimum_size().y
	used += spacing + _stats_row.get_combined_minimum_size().y
	used += spacing + _atk_name.get_combined_minimum_size().y
	used += spacing + _pas_name.get_combined_minimum_size().y
	used += spacing
	return max(inner_h - used, 0.0)

func _set_desc_line_limit(available_height: float) -> void:
	if available_height <= 0.0:
		_desc.max_lines_visible = 0
		return
	var line_height := _desc.get_line_height()
	if line_height <= 0.0:
		_desc.max_lines_visible = -1
		return
	var max_lines := int(floor(available_height / line_height))
	if max_lines <= 0:
		_desc.max_lines_visible = 1
	else:
		_desc.max_lines_visible = max_lines
