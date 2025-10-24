extends Button
class_name SproutCardUI

@export var name_label_path: NodePath
@export var stats_label_path: NodePath

var _name_label: Label
var _stats_label: Label

func _ready() -> void:
		_name_label = _resolve_label(name_label_path)
		_stats_label = _resolve_label(stats_label_path)

func set_display_name(text: String) -> void:
		if _name_label:
				_name_label.text = text

func set_stats(text: String) -> void:
		if _stats_label:
				_stats_label.text = text

func _resolve_label(path: NodePath) -> Label:
		if path.is_empty():
				return null
		var node := get_node_or_null(path)
		if node is Label:
				return node
		return null
