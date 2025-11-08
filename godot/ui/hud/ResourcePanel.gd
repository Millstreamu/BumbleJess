extends Panel
class_name ResourcePanel

@onready var _n_val: Label = $"VBoxContainer/N/Value"
@onready var _e_val: Label = $"VBoxContainer/E/Value"
@onready var _w_val: Label = $"VBoxContainer/W/Value"
@onready var _l_val: Label = $"VBoxContainer/L/Value"

func set_values(nc: int, nm: int, ec: int, em: int, wc: int, wm: int, lc: int, lm: int) -> void:
	if _n_val:
		_n_val.text = "%d/%d" % [nc, nm]
	if _e_val:
		_e_val.text = "%d/%d" % [ec, em]
	if _w_val:
		_w_val.text = "%d/%d" % [wc, wm]
	if _l_val:
		_l_val.text = "%d/%d" % [lc, lm]
