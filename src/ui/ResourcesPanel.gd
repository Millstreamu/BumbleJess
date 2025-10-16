extends Control
## Simple HUD displaying current resource amounts and caps.
class_name ResourcesPanel

const AudioController := preload("res://src/audio/AudioController.gd")

@onready var lbl_nature: Label = %Nature
@onready var lbl_earth: Label = %Earth
@onready var lbl_water: Label = %Water
@onready var lbl_life: Label = %Life

var _previous := {
        "Nature": {"amount": 0, "cap": 0},
        "Earth": {"amount": 0, "cap": 0},
        "Water": {"amount": 0, "cap": 0},
        "Life": {"amount": 0, "cap": 0},
}

func _ready() -> void:
        _sync_all(true)

func _process(_dt: float) -> void:
        _sync_all()

func _sync_all(force: bool = false) -> void:
        _update_entry("Nature", lbl_nature, force)
        _update_entry("Earth", lbl_earth, force)
        _update_entry("Water", lbl_water, force)
        _update_entry("Life", lbl_life, force)

func _update_entry(key: String, label: Label, force: bool) -> void:
        if label == null:
                        return
        var amount := int(Resources.amount.get(key, 0))
        var cap_value := int(Resources.cap.get(key, 0))
        var previous: Dictionary = _previous.get(key, {"amount": amount, "cap": cap_value})
        var changed := force or previous.get("amount", amount) != amount or previous.get("cap", cap_value) != cap_value
        label.text = "%s: %d / %d" % [key, amount, cap_value]
        if changed:
                        _previous[key] = {"amount": amount, "cap": cap_value}
                        _pulse(label)
                        if amount > previous.get("amount", amount):
                                        AudioController.play(AudioController.SFX.RESOURCE_GAIN)

func _pulse(label: Label) -> void:
        var highlight := Color(1.2, 1.2, 1.2, 1.0)
        label.modulate = highlight
        var tween := create_tween()
        tween.tween_property(label, "modulate", Color(1, 1, 1, 1), 0.2)
