extends Control

signal draft_completed

var _categories := ["Harvest","Build","Refine","Storage","Guard","Upgrade","Chanting"]
var _index := 0
var _choices : Array = []
var _picked : Dictionary = {}
var _rng := RandomNumberGenerator.new()
var _selection := 0

@onready var _category_label: Label = %CategoryLabel
@onready var _card_container: HBoxContainer = %CardContainer
@onready var _instructions_label: Label = %InstructionsLabel

func _ready():
    _rng.seed = Time.get_unix_time_from_system()
    _index = 0
    _picked.clear()
    _next_category()

func _next_category():
    if _index >= _categories.size():
        RunState.chosen_variants = _picked.duplicate(true)
        emit_signal("draft_completed")
        return
    _show_category(_index)

func _show_category(idx:int) -> void:
    var cat := _categories[idx]
    _choices = _sample_three(cat)
    _render_cards(cat, _choices)

func _sample_three(cat:String) -> Array:
    var variants := []
    if Config.tiles().has("variants"):
        var pool = Config.tiles()["variants"].get(cat, [])
        if typeof(pool) == TYPE_ARRAY:
            variants = pool.duplicate(true)
    var available := variants.size()
    if available <= 0:
        return []
    var count := min(3, available)
    var results : Array = []
    for i in range(count):
        var idx := _rng.randi_range(0, variants.size() - 1)
        results.append(variants[idx])
        variants.remove_at(idx)
    return results

func _render_cards(cat:String, choices:Array) -> void:
    _selection = 0
    if _category_label:
        _category_label.text = "Select a %s tile" % cat
    if _instructions_label:
        _instructions_label.text = "Use ←/→ to choose, Space to confirm, Z to go back"
    if _card_container:
        while _card_container.get_child_count() > 0:
            var child := _card_container.get_child(0)
            _card_container.remove_child(child)
            child.queue_free()
        for choice in choices:
            var card := _create_card(choice)
            _card_container.add_child(card)
    _update_highlight()

func _create_card(choice:Dictionary) -> Control:
    var card := VBoxContainer.new()
    card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    card.alignment = BoxContainer.ALIGNMENT_CENTER
    card.custom_minimum_size = Vector2(180, 0)
    var name_label := Label.new()
    name_label.text = str(choice.get("name", choice.get("id", "Unknown")))
    name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    var id_label := Label.new()
    id_label.text = str(choice.get("id", ""))
    id_label.modulate = Color(0.7, 0.7, 0.9)
    id_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    var effects_label := Label.new()
    effects_label.text = _summarize_effects(choice.get("effects", {}))
    effects_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    effects_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    card.add_child(name_label)
    card.add_child(id_label)
    card.add_child(effects_label)
    return card

func _summarize_effects(effects:Variant) -> String:
    if typeof(effects) != TYPE_DICTIONARY:
        return ""
    var parts : Array = []
    for key in effects.keys():
        var value = effects[key]
        if typeof(value) in [TYPE_DICTIONARY, TYPE_ARRAY]:
            parts.append("%s: %s" % [key, JSON.stringify(value)])
        else:
            parts.append("%s: %s" % [key, str(value)])
    return ", ".join(parts)

func _unhandled_input(event: InputEvent) -> void:
    if event.is_action_pressed("ui_left"):
        _move_sel(-1)
    elif event.is_action_pressed("ui_right"):
        _move_sel(1)
    elif event.is_action_pressed("ui_accept"):
        _confirm_pick()
    elif event.is_action_pressed("ui_cancel"):
        _go_back()

func _move_sel(delta:int) -> void:
    if _choices.is_empty():
        return
    var size := _choices.size()
    _selection = (_selection + delta) % size
    if _selection < 0:
        _selection += size
    _update_highlight()

func _update_highlight() -> void:
    if not _card_container:
        return
    var idx := 0
    for child in _card_container.get_children():
        if child is Control:
            child.modulate = Color(1, 1, 1, 1) if idx == _selection else Color(0.7, 0.7, 0.7, 1)
        idx += 1

func _current_sel() -> int:
    return _selection

func _confirm_pick():
    if _choices.is_empty():
        return
    var cat := _categories[_index]
    var sel := clamp(_current_sel(), 0, _choices.size() - 1)
    var picked_id := str(_choices[sel].get("id", ""))
    if picked_id != "":
        _picked[cat] = picked_id
        _index += 1
        _next_category()

func _go_back():
    if _index <= 0:
        return
    _index -= 1
    var cat := _categories[_index]
    if _picked.has(cat):
        _picked.erase(cat)
    _show_category(_index)
