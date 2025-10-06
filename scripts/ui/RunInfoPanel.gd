extends Control
## Displays high-level run information such as turn number, deck state, and resources.
class_name RunInfoPanel

const CellType := preload("res://scripts/core/CellType.gd")

@onready var _turn_label: Label = $Panel/Margin/VBox/TurnLabel
@onready var _deck_label: Label = $Panel/Margin/VBox/DeckLabel
@onready var _sprout_label: Label = $Panel/Margin/VBox/SproutLabel
@onready var _nature_label: Label = $Panel/Margin/VBox/ResourceGrid/NatureValue
@onready var _earth_label: Label = $Panel/Margin/VBox/ResourceGrid/EarthValue
@onready var _water_label: Label = $Panel/Margin/VBox/ResourceGrid/WaterValue
@onready var _life_label: Label = $Panel/Margin/VBox/ResourceGrid/LifeValue

func update_turn(turn: int) -> void:
    _turn_label.text = "Turn: %d" % max(turn, 0)

func update_deck(total_remaining: int, counts: Dictionary) -> void:
    _deck_label.text = "Deck: %d tiles remaining" % max(total_remaining, 0)
    var breakdown: Array[String] = []
    for cell_type in CellType.buildable_types():
        var count := int(counts.get(cell_type, 0))
        if count > 0:
            breakdown.append("%s x%d" % [CellType.to_display_name(cell_type), count])
    _deck_label.tooltip_text = ", ".join(breakdown)

func update_resources(resources: Dictionary, generation: Dictionary) -> void:
    _nature_label.text = _format_resource("nature", resources, generation)
    _earth_label.text = _format_resource("earth", resources, generation)
    _water_label.text = _format_resource("water", resources, generation)
    _life_label.text = _format_resource("life", resources, generation)

func update_sprouts(total: int) -> void:
    _sprout_label.text = "Sprouts: %d" % max(total, 0)

func _format_resource(key: String, resources: Dictionary, generation: Dictionary) -> String:
    var entry: Dictionary = resources.get(key, {})
    var current := int(entry.get("current", 0))
    var capacity := int(entry.get("capacity", 0))
    var text := ""
    if capacity > 0 and key != "life":
        text = "%d/%d" % [current, capacity]
    else:
        text = str(current)
    var delta := int(generation.get(key, 0))
    if delta != 0:
        text += " (+%d)" % delta
    return text
