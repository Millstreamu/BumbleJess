extends CanvasLayer
class_name BattleWindow

signal battle_finished(result: Dictionary)
signal window_closed

@onready var sprout_grid: GridContainer = $"Frame/Layout/LeftCol/SproutGrid"
@onready var decay_grid: GridContainer = $"Frame/Layout/RightCol/DecayGrid"
@onready var status_label: Label = $"Frame/Layout/MidCol/StatusLabel"
@onready var select_btn: Button = $"Frame/Layout/MidCol/SelectBtn"
@onready var start_btn: Button = $"Frame/Layout/MidCol/StartButton"
@onready var close_btn: Button = $"Frame/Layout/MidCol/CloseButton"
@onready var time_bar: ProgressBar = $"Frame/Layout/MidCol/TimeBar"

var encounter: Dictionary = {}
var on_finish: Callable = Callable()
var running: bool = false
var time_limit: float = 30.0
var elapsed: float = 0.0

var left_units: Array[Dictionary] = []
var right_units: Array[Dictionary] = []
var selected_team: Array[Dictionary] = []
var _picker: BattlePicker

const SLOT_COUNT := 6
const FRONT_INDICES: Array[int] = [0, 1, 2]
const UNIT_SLOT_SCENE := preload("res://scenes/battle/UnitSlot.tscn")
const LIFE_REWARD := 3

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	set_process(true)
	start_btn.pressed.connect(_on_start_pressed)
	close_btn.pressed.connect(_on_close_pressed)
	select_btn.pressed.connect(_on_select_pressed)
	hide()

func open(enc: Dictionary, finish_cb: Callable) -> void:
	encounter = enc
	on_finish = finish_cb
	running = false
	elapsed = 0.0
	time_bar.min_value = 0
	time_bar.max_value = 100
	time_bar.value = 0
	status_label.text = "Ready"
	selected_team = _clamp_selection(SproutRegistry.get_last_selection())
	_update_team_ready_ui()
	close_btn.disabled = true
	_build_teams()
	_populate_ui()
	_refresh_ui()
	show()

func _process(delta: float) -> void:
	if not visible:
		return
	if not running:
		return
	elapsed += delta
	time_bar.value = clamp(int((elapsed / time_limit) * 100.0), 0, 100)
	_tick_cooldowns(delta)
	_auto_attacks()
	_refresh_ui()
	var state: String = _check_end()
	if state != "":
		_finish(state)
	elif elapsed >= time_limit:
		_finish("timeout")

func _on_start_pressed() -> void:
	running = true
	start_btn.disabled = true
	status_label.text = "Battle…"

func _on_close_pressed() -> void:
	hide()
	emit_signal("window_closed")

func _update_team_ready_ui() -> void:
	if running:
		return
	if selected_team.is_empty():
		status_label.text = "Select a team"
	else:
		status_label.text = "Team ready (%d)" % selected_team.size()
	start_btn.disabled = _should_disable_start()

func _should_disable_start() -> bool:
	if selected_team.size() > 0:
		return false
	var roster: Array = SproutRegistry.get_roster()
	return roster.size() > 0

func _clamp_selection(sel: Array) -> Array:
	var result: Array[Dictionary] = []
	var limit: int = min(sel.size(), SLOT_COUNT)
	for i in range(limit):
		var entry: Variant = sel[i]
		if typeof(entry) == TYPE_DICTIONARY:
			result.append(Dictionary(entry).duplicate(true))
	return result

func _on_select_pressed() -> void:
	if _picker == null:
		var scene: PackedScene = load("res://scenes/battle/BattlePicker.tscn") as PackedScene
		_picker = scene.instantiate()
		var parent: Node = get_tree().current_scene
		if parent == null:
			parent = get_tree().root
		parent.add_child(_picker)
		_picker.selection_done.connect(_on_picker_done)
		_picker.cancelled.connect(_on_picker_cancel)
	_picker.open()

func _on_picker_done(sel: Array) -> void:
	selected_team = _clamp_selection(sel)
	_update_team_ready_ui()
	_build_teams()
	_populate_ui()
	_refresh_ui()

func _on_picker_cancel() -> void:
	pass

func _build_teams() -> void:
	left_units.clear()
	right_units.clear()
	var sprout_defs: Array = DataLite.load_json_array("res://data/sprouts.json")
	var attack_defs: Array = DataLite.load_json_array("res://data/attacks.json")
	var sprouts: Array = []
	if selected_team.size() > 0:
		sprouts = selected_team.duplicate(true)
	else:
		var registry: Node = get_tree().root.get_node_or_null("SproutRegistry")
		if registry and registry.has_method("pick_for_battle"):
			sprouts = registry.call("pick_for_battle", SLOT_COUNT)
		if sprouts.is_empty():
			for i in range(3):
				sprouts.append({"id": "sprout.woodling", "level": 1})
	for i in range(SLOT_COUNT):
		var entry: Dictionary = {}
		if i < sprouts.size() and typeof(sprouts[i]) == TYPE_DICTIONARY:
			entry = sprouts[i]
		left_units.append(_make_sprout_unit(entry, sprout_defs, attack_defs))
	var turn_engine: Node = get_tree().root.get_node_or_null("TurnEngine")
		var difficulty_scale: float = 1.0
		if turn_engine:
				var turn_value: Variant = turn_engine.get("turn_count")
				if typeof(turn_value) == TYPE_INT:
						difficulty_scale += 0.03 * max(0, int(turn_value))
		for i in range(SLOT_COUNT):
				right_units.append(_make_decay_unit(difficulty_scale, attack_defs))

func _populate_ui() -> void:
	_clear_children(sprout_grid)
	_clear_children(decay_grid)
	for i in range(SLOT_COUNT):
		sprout_grid.add_child(_make_slot_ui(left_units, i))
		decay_grid.add_child(_make_slot_ui(right_units, i))

func _clear_children(container: Node) -> void:
	for child in container.get_children():
		child.queue_free()

func _make_slot_ui(team: Array, idx: int) -> Control:
	var slot: Control = UNIT_SLOT_SCENE.instantiate()
	var unit: Dictionary = team[idx]
	var name_label: Label = slot.get_node("Name") as Label
	name_label.text = unit.get("name", "Empty")
	var hp_bar: TextureProgressBar = slot.get_node("HP") as TextureProgressBar
	hp_bar.min_value = 0
	hp_bar.max_value = 100
	hp_bar.value = 100 if unit.get("alive", false) else 0
	var cd_bar: TextureProgressBar = slot.get_node("CD") as TextureProgressBar
	cd_bar.min_value = 0
	cd_bar.max_value = 100
	cd_bar.value = 0
	var pop_label: Label = slot.get_node("DmgPop")
	pop_label.text = ""
	pop_label.modulate.a = 0.0
	slot.set_meta("team_side", unit.get("side", ""))
	slot.set_meta("unit_index", idx)
	return slot

func _make_sprout_unit(entry: Dictionary, sprout_defs: Array, attack_defs: Array) -> Dictionary:
	if entry.is_empty():
		return _make_blank_unit("left")
	var sprout_id: String = String(entry.get("id", ""))
	var sprout_def: Dictionary = _find_by_id(sprout_defs, sprout_id)
	if sprout_def.is_empty():
		return _make_blank_unit("left")
	var level: int = max(1, int(entry.get("level", 1)))
	var base_stats: Dictionary = sprout_def.get("base_stats", {})
	var base_hp: int = int(base_stats.get("hp", 30))
	var base_attack: int = int(base_stats.get("attack", 6))
	var attack_speed: float = float(base_stats.get("attack_speed", 1.0))
	var hp: int = base_hp + (level - 1) * 3
	var attack_amount: int = base_attack + (level - 1)
	var attack_id: String = String(sprout_def.get("attack_id", ""))
	var attack_def: Dictionary = _find_by_id(attack_defs, attack_id)
	if attack_def.is_empty():
		attack_def = {"id": attack_id, "effects": []}
	attack_def = attack_def.duplicate(true)
	var effects: Array = attack_def.get("effects", [])
	var has_damage: bool = false
	for i in range(effects.size()):
		var eff: Dictionary = effects[i]
		if String(eff.get("type", "")) == "damage":
			eff["amount"] = attack_amount
			effects[i] = eff
			has_damage = true
	if not has_damage:
		effects.append({"type": "damage", "amount": attack_amount})
	attack_def["effects"] = effects
	var cooldown: float = float(attack_def.get("cooldown_sec", 1.5))
	cooldown = cooldown / max(0.1, attack_speed)
	cooldown = max(0.2, cooldown)
	return {
		"side": "left",
		"name": String(sprout_def.get("name", "Sprout")),
		"hp": hp,
		"hp_max": hp,
		"atk": attack_amount,
		"cd": cooldown,
		"cd_curr": 0.0,
		"atk_def": attack_def,
		"alive": true,
	}

func _make_decay_unit(difficulty_scale: float, attack_defs: Array) -> Dictionary:
		var hp: int = int(round(26.0 * max(difficulty_scale, 0.5)))
		var attack_amount: int = int(round(5.0 * max(difficulty_scale, 0.5)))
	var attack_def: Dictionary = _find_by_id(attack_defs, "atk.smog_bite")
	if attack_def.is_empty():
		attack_def = {"id": "atk.smog_bite", "effects": []}
	attack_def = attack_def.duplicate(true)
	var effects: Array = attack_def.get("effects", [])
	var has_damage: bool = false
	for i in range(effects.size()):
		var eff: Dictionary = effects[i]
		if String(eff.get("type", "")) == "damage":
			eff["amount"] = attack_amount
			effects[i] = eff
			has_damage = true
	if not has_damage:
		effects.append({"type": "damage", "amount": attack_amount})
	attack_def["effects"] = effects
	var cooldown: float = float(attack_def.get("cooldown_sec", 1.8))
	return {
		"side": "right",
		"name": "Smogling",
		"hp": hp,
		"hp_max": hp,
		"atk": attack_amount,
		"cd": cooldown,
		"cd_curr": 0.0,
		"atk_def": attack_def,
		"alive": true,
	}

func _make_blank_unit(side: String) -> Dictionary:
	return {
		"side": side,
		"name": "Empty",
		"hp": 0,
		"hp_max": 1,
		"atk": 0,
		"cd": 1.0,
		"cd_curr": 1.0,
		"atk_def": {"effects": []},
		"alive": false,
	}

func _find_by_id(data: Array, target_id: String) -> Dictionary:
	for item in data:
		if String(item.get("id", "")) == target_id:
			return item
	return {}

func _tick_cooldowns(delta: float) -> void:
	for unit in left_units:
		if unit.get("alive", false):
			unit["cd_curr"] = max(0.0, float(unit.get("cd_curr", 0.0)) - delta)
	for unit in right_units:
		if unit.get("alive", false):
			unit["cd_curr"] = max(0.0, float(unit.get("cd_curr", 0.0)) - delta)

func _auto_attacks() -> void:
	for i in range(SLOT_COUNT):
		var attacker: Dictionary = left_units[i]
		if not attacker.get("alive", false):
			continue
		if attacker.get("cd_curr", 0.0) > 0.0:
			continue
		var target_idx: int = _pick_target(right_units)
		if target_idx >= 0:
			_apply_attack(attacker, right_units[target_idx], decay_grid.get_child(target_idx))
			attacker["cd_curr"] = float(attacker.get("cd", 1.0))
	for i in range(SLOT_COUNT):
		var attacker: Dictionary = right_units[i]
		if not attacker.get("alive", false):
			continue
		if attacker.get("cd_curr", 0.0) > 0.0:
			continue
		var target_idx: int = _pick_target(left_units)
		if target_idx >= 0:
			_apply_attack(attacker, left_units[target_idx], sprout_grid.get_child(target_idx))
			attacker["cd_curr"] = float(attacker.get("cd", 1.0))

func _pick_target(team: Array) -> int:
	for idx in FRONT_INDICES:
		if idx < team.size() and team[idx].get("alive", false):
			return idx
	for i in range(team.size()):
		if team[i].get("alive", false):
			return i
	return -1

func _apply_attack(attacker: Dictionary, defender: Dictionary, slot_ui: Node) -> void:
	var attack_def: Dictionary = attacker.get("atk_def", {})
	var damage: int = 0
	for eff in attack_def.get("effects", []):
		if String(eff.get("type", "")) == "damage":
			damage += int(eff.get("amount", 0))
	if damage <= 0:
		return
	defender["hp"] = max(0, int(defender.get("hp", 0)) - damage)
	if defender.get("hp", 0) <= 0:
		defender["alive"] = false
		_pop_text(slot_ui, "KO")
	else:
		_pop_text(slot_ui, "-" + str(damage))

func _pop_text(slot_ui: Node, text: String) -> void:
	if slot_ui == null:
		return
	var label: Label = slot_ui.get_node_or_null("DmgPop") as Label
	if label == null:
		return
	label.text = text
	label.modulate.a = 1.0
	var tween: Tween = slot_ui.create_tween()
	tween.tween_property(label, "modulate:a", 0.0, 0.45).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

func _refresh_ui() -> void:
	for i in range(SLOT_COUNT):
		var left_unit: Dictionary = left_units[i]
		var slot: Node = sprout_grid.get_child(i)
		_update_slot(slot, left_unit)
		var right_unit: Dictionary = right_units[i]
		var right_slot: Node = decay_grid.get_child(i)
		_update_slot(right_slot, right_unit)

func _update_slot(slot: Node, unit: Dictionary) -> void:
	if slot == null:
		return
	var name_label: Label = slot.get_node_or_null("Name") as Label
	if name_label:
		var display_name: String = String(unit.get("name", ""))
		if not unit.get("alive", false) and unit.get("hp", 0) <= 0:
			display_name += " (X)"
		name_label.text = display_name
	var hp_bar: TextureProgressBar = slot.get_node_or_null("HP") as TextureProgressBar
	if hp_bar:
		var hp_max: float = max(1.0, float(unit.get("hp_max", 1)))
		hp_bar.value = clamp(int((float(unit.get("hp", 0)) / hp_max) * 100.0), 0, 100)
	var cd_bar: TextureProgressBar = slot.get_node_or_null("CD") as TextureProgressBar
	if cd_bar:
		var cd: float = max(0.01, float(unit.get("cd", 1.0)))
		var cd_curr: float = clamp(float(unit.get("cd_curr", 0.0)) / cd, 0.0, 1.0)
		cd_bar.value = int((1.0 - cd_curr) * 100.0)

func _check_end() -> String:
	var left_alive: bool = false
	var right_alive: bool = false
	for unit in left_units:
		if unit.get("alive", false):
			left_alive = true
	for unit in right_units:
		if unit.get("alive", false):
			right_alive = true
	if not left_alive and not right_alive:
		return "draw"
	if not left_alive:
		return "defeat"
	if not right_alive:
		return "victory"
	return ""

func _finish(state: String) -> void:
	running = false
	start_btn.disabled = true
	close_btn.disabled = false
	status_label.text = state.capitalize()
	_refresh_ui()
	var victory: bool = state == "victory"
	var rewards: Dictionary = {"life": LIFE_REWARD if victory else 0}
	var result: Dictionary = {
		"victory": victory,
		"outcome": state,
		"rewards": rewards,
		"target_cell": encounter.get("target", Vector2i.ZERO),
	}
	emit_signal("battle_finished", result)
