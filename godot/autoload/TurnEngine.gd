extends Node

signal phase_started(name: String)
signal turn_changed(turn_index: int)
signal run_started()
signal totem_passives_started(turn_index: int)

var turn_index: int = 1
var _awaiting_commune_pick := false
var _tile_placed_this_turn := false
var _run_active := false

func _ready() -> void:
        begin_run(turn_index)
        _bind_run_config()

func _bind_run_config() -> void:
        var rc := RunConfig if typeof(RunConfig) != TYPE_NIL else null
        if rc == null:
                return
        if not rc.run_ready.is_connected(_on_run_config_ready):
                rc.run_ready.connect(_on_run_config_ready)

func _on_run_config_ready() -> void:
        begin_run(1)

func begin_run(start_turn: int = 1) -> void:
	turn_index = max(1, start_turn)
	_awaiting_commune_pick = false
	_tile_placed_this_turn = false
	_run_active = true
	emit_signal("run_started")
	_start_commune_phase()

func is_run_active() -> bool:
	return _run_active

func _start_commune_phase() -> void:
	emit_signal("phase_started", "commune")
	_awaiting_commune_pick = true
	_tile_placed_this_turn = false

func notify_commune_choice_made() -> void:
	if not _run_active:
		return
	if not _awaiting_commune_pick:
		return
	_awaiting_commune_pick = false
	emit_signal("phase_started", "player")

func notify_tile_placed() -> void:
	_tile_placed_this_turn = true

func can_place_tile() -> bool:
	if _awaiting_commune_pick:
		return false
	return not _tile_placed_this_turn

func is_waiting_for_commune_choice() -> bool:
	return _awaiting_commune_pick

func end_turn() -> void:
	if not _run_active:
		return
	if _awaiting_commune_pick:
		return
	emit_signal("phase_started", "growth")
	_do_growth()
	emit_signal("phase_started", "resources")
	_do_resources()
	emit_signal("phase_started", "decay")
	await _do_decay()
	emit_signal("phase_started", "regen")
	_do_regen()
	emit_signal("phase_started", "totem_passives")
	_do_totem_passives()

	turn_index += 1
	emit_signal("turn_changed", turn_index)

	_start_commune_phase()

func advance_one_turn() -> void:
	end_turn()

func _do_growth() -> void:
	var manager: Node = get_tree().root.get_node_or_null("GrowthManager")
	if manager != null and manager.has_method("tick_growth_phase"):
		manager.call("tick_growth_phase", turn_index)

func _do_resources() -> void:
	var manager: Node = get_tree().root.get_node_or_null("ResourceManager")
	if manager != null and manager.has_method("tick_production_phase"):
		manager.call("tick_production_phase", turn_index)

func _do_decay() -> void:
	var manager: Node = null
	if Engine.has_singleton("DecayManager"):
		var singleton := Engine.get_singleton("DecayManager")
		if singleton is Node:
			manager = singleton
	if manager == null:
		manager = get_tree().root.get_node_or_null("DecayManager")
	if manager == null:
		return
	if manager.has_method("begin_decay_phase_async"):
		manager.call("begin_decay_phase_async", turn_index)
		await manager.decay_phase_complete
	elif manager.has_method("tick_decay_phase"):
		manager.call("tick_decay_phase", turn_index)

func _do_regen() -> void:
	var sprouts: Node = get_tree().root.get_node_or_null("SproutRegistry")
	if sprouts != null and sprouts.has_method("regen_percent_all"):
		sprouts.call("regen_percent_all", 5.0)
	var decay: Node = get_tree().root.get_node_or_null("DecayManager")
	if decay != null and decay.has_method("regen_percent_hostiles"):
		decay.call("regen_percent_hostiles", 5.0)

func _do_totem_passives() -> void:
	emit_signal("totem_passives_started", turn_index)
