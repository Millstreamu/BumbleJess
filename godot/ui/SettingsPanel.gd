extends Control
class_name SettingsPanel

signal closed

@onready var _back: Button = $"CenterContainer/VBoxContainer/Back"

func _ready() -> void:
	visible = false
	modulate.a = 0.0
	_back.pressed.connect(_on_back)

func open() -> void:
	visible = true
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 1.0, 0.15)
	_back.grab_focus()

func close() -> void:
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.15)
	await tw.finished
	visible = false
	emit_signal("closed")

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel"):
		close()

func _on_back() -> void:
	close()
