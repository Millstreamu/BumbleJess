extends CanvasLayer
class_name WorldHUD

signal end_turn_pressed
signal open_registry_pressed
signal open_resource_list_pressed
signal toggle_info_pressed

const FLOAT_TEXT_SCENE := preload("res://ui/hud/FloatText.tscn")
const THREAT_SCENE := preload("res://ui/hud/ThreatMarker.tscn")

@onready var _turn_phase: Label = $TopBar/TurnPhaseLabel
@onready var _res_panel := $BottomRight/ResourcePanel
@onready var _tile_card := $BottomLeft/TileCard
@onready var _btn_registry: Button = $TopRight/HBoxContainer/BtnRegistry
@onready var _btn_resources: Button = $TopRight/HBoxContainer/BtnResources
@onready var _floaters: Node2D = $WorldFX/Floaters
@onready var _threats: Node2D = $WorldFX/Threats

func _ready() -> void:
	_ensure_input_actions()
	if _btn_registry:
		_btn_registry.pressed.connect(
			func() -> void:
				emit_signal("open_registry_pressed")
		)
	if _btn_resources:
		_btn_resources.pressed.connect(
			func() -> void:
				emit_signal("open_resource_list_pressed")
		)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_info"):
		emit_signal("toggle_info_pressed")
	if event.is_action_pressed("end_turn"):
		emit_signal("end_turn_pressed")

func set_turn_phase(turn_i: int, phase_name: String) -> void:
	if _turn_phase:
		_turn_phase.text = "Turn %d — %s" % [turn_i, phase_name]

func set_resources(nc: int, nm: int, ec: int, em: int, wc: int, wm: int, lc: int, lm: int) -> void:
	var panel := _res_panel as ResourcePanel
	if panel:
		panel.set_values(nc, nm, ec, em, wc, wm, lc, lm)

func set_current_tile_card(data: Dictionary) -> void:
	var card := _tile_card as TileCard
	if card:
		card.update_card(data)

func toggle_tile_info_popups() -> void:
	emit_signal("toggle_info_pressed")

func spawn_floater(world_pos: Vector2, text: String, color: Color) -> void:
	if _floaters == null:
		return
	var node := FLOAT_TEXT_SCENE.instantiate() as Node2D
	if node == null:
		return
	_floaters.add_child(node)
	node.global_position = world_pos
	var floater := node as FloatText
	if floater:
		floater.set_text(text, color)
		floater.play_and_free()

func show_threat_marker(world_pos: Vector2, urgency: int) -> Node:
	if _threats == null:
		return null
	var node := THREAT_SCENE.instantiate() as Node2D
	if node == null:
		return null
	_threats.add_child(node)
	node.global_position = world_pos
	var marker := node as ThreatMarker
	if marker:
		marker.set_urgency(urgency)
	return node

func clear_threat_markers() -> void:
	if _threats == null:
		return
	for child in _threats.get_children():
		child.queue_free()

func _ensure_input_actions() -> void:
	_add_action_if_missing("toggle_info", KEY_M)
	_add_action_if_missing("end_turn", KEY_N)

func _add_action_if_missing(name: String, keycode: int) -> void:
	if not InputMap.has_action(name):
		InputMap.add_action(name)
	var existing := InputMap.action_get_events(name)
	for ev in existing:
		if ev is InputEventKey and ev.physical_keycode == keycode:
			return
	var event := InputEventKey.new()
	event.physical_keycode = keycode
	InputMap.action_add_event(name, event)
