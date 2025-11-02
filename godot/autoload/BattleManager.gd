extends Node

signal battle_result(victory: bool, rewards: Dictionary)
signal battle_started(target_cell: Vector2i)
signal battle_finished(target_cell: Vector2i, victory: bool)

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

func open_battle_for_cell(target_cell: Vector2i, opts: Dictionary = {}) -> void:
		var encounter: Dictionary = {
				"target": target_cell,
		}
		if opts.has("attacker_cell"):
				encounter["attacker"] = opts["attacker_cell"]
		elif opts.has("attacker"):
				encounter["attacker"] = opts["attacker"]
		if opts.has("encounter") and typeof(opts["encounter"]) == TYPE_DICTIONARY:
				var extra := opts["encounter"] as Dictionary
				for key in extra.keys():
						encounter[key] = extra[key]
		var callback: Callable = Callable()
		if opts.has("callback") and opts["callback"] is Callable:
				callback = opts["callback"]
		emit_signal("battle_started", target_cell)
		var audio_bus := get_node_or_null("/root/AudioBus")
		if audio_bus != null and audio_bus.has_method("play"):
				audio_bus.play("res://assets/sfx/battle_start.wav")
		open_battle(encounter, callback)

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
	var target_cell: Vector2i = result.get("target_cell", Vector2i.ZERO)
	var victory := bool(result.get("victory", true))
	emit_signal("battle_result", victory, rewards)
	emit_signal("battle_finished", target_cell, victory)
	if _pending_callback.is_valid():
		_pending_callback.call(result)
		_pending_callback = Callable()
	elif _window and _window.on_finish.is_valid():
		_window.on_finish.call(result)
		_window.on_finish = Callable()

func _on_window_closed() -> void:
	get_tree().paused = _tree_was_paused
	_pending_callback = Callable()
