extends Control
class_name ReviewBanner

const RunState := preload("res://autoload/RunState.gd")
const CombatLog := preload("res://scripts/ui/CombatLogPanel.gd")

@onready var header_label: Label = $PanelContainer/MarginContainer/VBox/Header
@onready var list: VBoxContainer = $PanelContainer/MarginContainer/VBox/List

var turn_controller: TurnController
var _turn_index := 0
var _active_panel_name := ""

func _ready() -> void:
	visible = false
	set_process_unhandled_input(true)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_update_header()

func show_for_turn(turn: int) -> void:
	_turn_index = max(turn, 0)
	_update_header()
	for child in list.get_children():
		child.queue_free()
	for note_variant in RunState.turn_notes:
		var note := String(note_variant)
		if note.is_empty():
			continue
		var lbl := Label.new()
		lbl.text = "• " + note
		list.add_child(lbl)
	if RunState.turn_notes.is_empty():
		var empty_label := Label.new()
		empty_label.text = "• No major events this turn."
		list.add_child(empty_label)
	RunState.turn_notes.clear()
	visible = true

func hide_banner() -> void:
	if not visible:
		return
	visible = false
	for child in list.get_children():
		if child is Label:
			var text := (child as Label).text
			if not CombatLog.has_line(text):
				CombatLog.log(text)
	if turn_controller:
		turn_controller.ack_review_and_resume()

func set_active_panel(name: String) -> void:
	_active_panel_name = name
	_update_header()

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_accept"):
		hide_banner()
		get_viewport().set_input_as_handled()

func _update_header() -> void:
	if not header_label:
		return
	var text := "Turn %d — Review (Space to continue)" % _turn_index
	if _active_panel_name != "":
		text += " — Viewing %s" % _active_panel_name
	header_label.text = text
