extends Control
## Simple HUD displaying current resource amounts and caps.
class_name ResourcesPanel

@onready var lbl_nature: Label = %Nature
@onready var lbl_earth: Label = %Earth
@onready var lbl_water: Label = %Water
@onready var lbl_life: Label = %Life

func _process(_dt: float) -> void:
        lbl_nature.text = "Nature: %d / %d" % [Resources.amount["Nature"], Resources.cap["Nature"]]
        lbl_earth.text = "Earth:  %d / %d" % [Resources.amount["Earth"], Resources.cap["Earth"]]
        lbl_water.text = "Water:  %d / %d" % [Resources.amount["Water"], Resources.cap["Water"]]
        lbl_life.text = "Life:   %d / %d" % [Resources.amount["Life"], Resources.cap["Life"]]
