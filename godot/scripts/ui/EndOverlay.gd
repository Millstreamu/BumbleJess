extends Control
class_name EndOverlay

@onready var label: Label = $CenterContainer/Label

static var _singleton: EndOverlay

func _ready() -> void:
        _singleton = self
        visible = false

static func show_victory() -> void:
        if not is_instance_valid(_singleton):
                        return
        _singleton._show_victory()

static func show_defeat() -> void:
        if not is_instance_valid(_singleton):
                        return
        _singleton._show_defeat()

func _show_victory() -> void:
        label.text = "Forest Restored 🌿"
        visible = true

func _show_defeat() -> void:
        label.text = "The Forest Fell to Decay"
        visible = true
