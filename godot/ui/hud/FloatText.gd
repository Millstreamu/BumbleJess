extends Node2D
class_name FloatText

@onready var _label: Label = $Value

func set_text(text: String, color: Color) -> void:
	if _label:
		_label.text = text
		_label.add_theme_color_override("font_color", color)

func play_and_free() -> void:
	var tw := create_tween()
	if tw == null:
		queue_free()
		return
	tw.tween_property(self, "position:y", position.y - 24.0, 0.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(self, "modulate:a", 0.0, 0.6)
	await tw.finished
	queue_free()
