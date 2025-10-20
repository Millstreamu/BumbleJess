extends Node

signal battle_result(victory: bool, rewards: Dictionary)

var _window: BattleWindow = null
var _pending_callback: Callable = Callable()
var _tree_was_paused := false

func open_battle(encounter: Dictionary, callback: Callable) -> void:
	if _window == null:
		_create_window()
	_pending_callback = callback
	_tree_was_paused = get_tree().paused
	get_tree().paused = true
	_window.open(encounter, callback)

func _create_window() -> void:
	var scene := load("res://scenes/battle/BattleWindow.tscn") as PackedScene
	if scene == null:
		return
	_window = scene.instantiate() as BattleWindow
	get_tree().root.add_child(_window)
	_window.battle_finished.connect(_on_window_finished)
	_window.window_closed.connect(_on_window_closed)

func _on_window_finished(result: Dictionary) -> void:
	var rewards: Dictionary = {} if not result.has("rewards") else Dictionary(result["rewards"])
	emit_signal("battle_result", bool(result.get("victory", true)), rewards)
	if _pending_callback.is_valid():
		_pending_callback.call(result)
		_pending_callback = Callable()
	elif _window and _window.on_finish.is_valid():
		_window.on_finish.call(result)
		_window.on_finish = Callable()

func _on_window_closed() -> void:
	get_tree().paused = _tree_was_paused
	_pending_callback = Callable()
