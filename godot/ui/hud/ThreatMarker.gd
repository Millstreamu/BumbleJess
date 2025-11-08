extends Node2D
class_name ThreatMarker

@onready var _mark: Label = $Mark

func set_urgency(urgency: int) -> void:
	var col := Color(1, 0.835, 0.309)
	if urgency == 2:
		col = Color(1, 0.541, 0.396)
	elif urgency >= 3:
		col = Color(0.937, 0.325, 0.313)
	if _mark:
		_mark.add_theme_color_override("font_color", col)
		_mark.text = "!"
