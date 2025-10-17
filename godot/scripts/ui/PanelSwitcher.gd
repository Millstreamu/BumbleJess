extends Node
class_name PanelSwitcher

var _panels: Dictionary = {}
var _order: Array[String] = []
var _current: String = ""

func _ready() -> void:
	ensure_draft_panel()

func register_panel(name:String, node:Node) -> void:
	if node == null:
		return
	_panels[name] = node
	if not _order.has(name):
		_order.append(name)
	if _current == "":
		_current = name

func ensure_draft_panel() -> void:
	if _panels.has("Draft"):
		return
	if has_node("Draft"):
		register_panel("Draft", get_node("Draft"))

func show(name:String) -> void:
	if not _panels.has(name):
		return
	for raw_key in _panels.keys():
		var key: String = str(raw_key)
		var panel_value: Variant = _panels[key]
		if panel_value is CanvasItem:
			var panel: CanvasItem = panel_value
			panel.visible = key == name
	_current = name

func cycle(direction:int = 1) -> void:
	if _order.is_empty():
		return
	ensure_draft_panel()
	var idx := _order.find(_current)
	if idx == -1:
		idx = 0
	else:
		idx = (idx + direction) % _order.size()
		if idx < 0:
			idx += _order.size()
	var name := _order[idx]
	show(name)
