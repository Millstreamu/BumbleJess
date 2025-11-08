extends Panel
class_name LockedCard

@onready var _icon: TextureRect = $VBoxContainer/TextureRect
@onready var _name: Label = $VBoxContainer/Name
@onready var _index: Label = $VBoxContainer/Index

func set_locked(index: int) -> void:
	_name.text = "Locked"
	_index.text = str(index)
	modulate = Color(0.4, 0.4, 0.4, 1.0)
	_icon.modulate = Color(0.2, 0.2, 0.2, 1.0)

func set_unlocked(index: int, name: String) -> void:
	_name.text = name
	_index.text = str(index)
	modulate = Color(1, 1, 1, 1)
	_icon.modulate = Color(1, 1, 1, 1)
