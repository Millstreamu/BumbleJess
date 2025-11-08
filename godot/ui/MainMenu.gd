extends Control
class_name MainMenu

signal start_run_requested

@onready var _btn_start: Button = $"MarginContainer/VBoxContainer/MenuStack/StartRun"
@onready var _btn_library: Button = $"MarginContainer/VBoxContainer/MenuStack/Library"
@onready var _btn_settings: Button = $"MarginContainer/VBoxContainer/MenuStack/Settings"
@onready var _btn_exit: Button = $"MarginContainer/VBoxContainer/MenuStack/Exit"
@onready var _library: LibraryPanel = $LibraryPanel
@onready var _settings: SettingsPanel = $SettingsPanel

func _ready() -> void:
	_btn_start.pressed.connect(_on_start)
	_btn_library.pressed.connect(_on_library)
	_btn_settings.pressed.connect(_on_settings)
	_btn_exit.pressed.connect(_on_exit)
	_library.closed.connect(_restore_focus_to_library)
	_settings.closed.connect(_restore_focus_to_settings)
	_btn_start.grab_focus()

func _on_start() -> void:
	emit_signal("start_run_requested")

func _on_library() -> void:
	if _library.visible:
		return
	_library.open()

func _on_settings() -> void:
	if _settings.visible:
		return
	_settings.open()

func _on_exit() -> void:
	get_tree().quit()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if _library.visible:
			_library.close()
			return
		if _settings.visible:
			_settings.close()
			return

func _restore_focus_to_library() -> void:
	_btn_library.grab_focus()

func _restore_focus_to_settings() -> void:
	_btn_settings.grab_focus()
