extends Control
class_name LibraryPanel

signal closed

const CARD_SCENE: PackedScene = preload("res://ui/shared/LockedCard.tscn")
const TABS := ["Totems", "Sprouts", "Tiles"]

@onready var _tab_totems: Button = $"MarginContainer/VBoxContainer/HBoxContainer/Totems"
@onready var _tab_sprouts: Button = $"MarginContainer/VBoxContainer/HBoxContainer/Sprouts"
@onready var _tab_tiles: Button = $"MarginContainer/VBoxContainer/HBoxContainer/Tiles"
@onready var _tab_back: Button = $"MarginContainer/VBoxContainer/HBoxContainer/Back"
@onready var _grid: GridContainer = $"MarginContainer/VBoxContainer/ScrollContainer/GridContainer"

var _current_tab: String = "Totems"

func _ready() -> void:
	visible = false
	modulate.a = 0.0
	_connect_tabs()
	_grid.columns = 4
	_refresh()

func open() -> void:
	_current_tab = "Totems"
	_refresh()
	visible = true
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 1.0, 0.15)
	_focus_tab(_current_tab)

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
		return
	if event.is_action_pressed("ui_left"):
		_cycle_tabs(-1)
		return
	if event.is_action_pressed("ui_right"):
		_cycle_tabs(1)
		return

func _connect_tabs() -> void:
	_tab_totems.pressed.connect(func() -> void:
		_set_tab("Totems")
	)
	_tab_sprouts.pressed.connect(func() -> void:
		_set_tab("Sprouts")
	)
	_tab_tiles.pressed.connect(func() -> void:
		_set_tab("Tiles")
	)
	_tab_back.pressed.connect(close)

func _focus_tab(tab: String) -> void:
	_get_tab_button(tab).grab_focus()

func _get_tab_button(tab: String) -> Button:
	match tab:
		"Totems":
			return _tab_totems
		"Sprouts":
			return _tab_sprouts
		"Tiles":
			return _tab_tiles
		_:
			return _tab_totems

func _set_tab(tab: String) -> void:
	_current_tab = tab
	_refresh()
	_focus_tab(tab)

func _cycle_tabs(direction: int) -> void:
	var idx := TABS.find(_current_tab)
	if idx == -1:
		idx = 0
	idx = (idx + direction + TABS.size()) % TABS.size()
	_set_tab(TABS[idx])

func _refresh() -> void:
	for child in _grid.get_children():
		child.queue_free()
	var entries := _fake_data(_current_tab)
	for entry in entries:
		var card := CARD_SCENE.instantiate() as LockedCard
		if card == null:
			continue
		_grid.add_child(card)
		var index := entry.get("index", 0)
		var name := entry.get("name", "?")
		var unlocked := entry.get("unlocked", false)
		if unlocked:
			card.set_unlocked(index, name)
		else:
			card.set_locked(index)

func _fake_data(tab: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for i in range(1, 25):
		var unlocked := (i % 3) != 0
		var name := "%s %d" % [tab, i]
		out.append({
			"index": i,
			"name": name,
			"unlocked": unlocked,
		})
	return out
