extends Button
class_name SproutCardUI

@export var name_label_path: NodePath
@export var stats_label_path: NodePath
@export var attack_label_path: NodePath
@export var passive_label_path: NodePath
@export var description_label_path: NodePath
@export var portrait_rect_path: NodePath

var _name_label: Label
var _stats_label: Label
var _attack_label: Label
var _passive_label: Label
var _description_label: RichTextLabel
var _portrait_rect: TextureRect

func _ready() -> void:
        _ensure_labels()

func set_display_name(display_text: String) -> void:
        _ensure_labels()
        if _name_label:
                _name_label.text = display_text

func set_stats(stats_text: String) -> void:
        _ensure_labels()
        if _stats_label:
                _stats_label.text = stats_text

func set_attack_name(attack_text: String) -> void:
        _ensure_labels()
        if _attack_label:
                _attack_label.text = attack_text

func set_passive_names(passive_text: String) -> void:
        _ensure_labels()
        if _passive_label:
                _passive_label.text = passive_text

func set_description(desc_text: String) -> void:
        _ensure_labels()
        if _description_label:
                var trimmed := desc_text.strip_edges()
                if trimmed.is_empty():
                        _description_label.text = "—"
                else:
                        _description_label.text = trimmed

func set_portrait_texture(texture: Texture2D) -> void:
        _ensure_labels()
        if _portrait_rect:
                _portrait_rect.texture = texture

func _ensure_labels() -> void:
        if _name_label == null:
                _name_label = _resolve_label(name_label_path)
        if _stats_label == null:
                _stats_label = _resolve_label(stats_label_path)
        if _attack_label == null:
                _attack_label = _resolve_label(attack_label_path)
        if _passive_label == null:
                _passive_label = _resolve_label(passive_label_path)
        if _description_label == null:
                _description_label = _resolve_rich_text(description_label_path)
        if _portrait_rect == null:
                _portrait_rect = _resolve_texture_rect(portrait_rect_path)

func _resolve_label(path: NodePath) -> Label:
        if path.is_empty():
                return null
        var node := get_node_or_null(path)
        if node is Label:
                return node
        return null

func _resolve_rich_text(path: NodePath) -> RichTextLabel:
        if path.is_empty():
                return null
        var node := get_node_or_null(path)
        if node is RichTextLabel:
                return node
        return null

func _resolve_texture_rect(path: NodePath) -> TextureRect:
        if path.is_empty():
                return null
        var node := get_node_or_null(path)
        if node is TextureRect:
                return node
        return null
