extends CanvasLayer
class_name BattlePicker

signal selection_done(selection: Array)
signal cancelled()

const MAX_SELECTION := 6
const SPROUT_CARD_SCENE := preload("res://scenes/battle/SproutCard.tscn")

@onready var roster_grid: GridContainer = $"Frame/Layout/Left/ScrollContainer/RosterGrid"
@onready var selected_grid: GridContainer = $"Frame/Layout/Right/SelectedGrid"
@onready var confirm_btn: Button = $"Frame/Layout/Middle/ConfirmBtn"
@onready var cancel_btn: Button = $"Frame/Layout/Middle/CancelBtn"
@onready var info_label: Label = $"Frame/Layout/Middle/Info"

var _roster: Array = []
var _selected: Array = []
var _sprout_defs: Array = []

func _ready() -> void:
        visible = false
        confirm_btn.pressed.connect(_on_confirm)
        cancel_btn.pressed.connect(_on_cancel)

func open() -> void:
        visible = true
        _sprout_defs = DataLite.load_json_array("res://data/sprouts.json")
        _roster = SproutRegistry.get_roster()
        _selected = _sanitize_selection(SproutRegistry.get_last_selection())
        _build_roster()
        _build_selected()
        _refresh_state()

func close() -> void:
        visible = false

func _sanitize_selection(sel: Array) -> Array:
        var result: Array = []
        var limit := min(sel.size(), MAX_SELECTION)
        for i in range(limit):
                var entry := sel[i]
                if typeof(entry) == TYPE_DICTIONARY:
                        result.append(entry.duplicate(true))
        return result

func _build_roster() -> void:
        _clear_children(roster_grid)
        for i in range(_roster.size()):
                var entry := _roster[i]
                if typeof(entry) != TYPE_DICTIONARY:
                        continue
                var btn := _make_card(entry, i)
                roster_grid.add_child(btn)

func _make_card(entry: Dictionary, idx: int) -> Button:
        var card: Button = SPROUT_CARD_SCENE.instantiate()
        var id := String(entry.get("id", "sprout.woodling"))
        var level := int(entry.get("level", 1))
        var name_label: Label = card.get_node("Name")
        name_label.text = _sprout_name(id)
        var stats_label: Label = card.get_node("Stats")
        stats_label.text = "Lv%d • %s" % [level, _sprout_stats_text(id, level)]
        card.pressed.connect(func() -> void:
                _try_add(idx)
        )
        return card

func _build_selected() -> void:
        _clear_children(selected_grid)
        for i in range(MAX_SELECTION):
                var slot := Button.new()
                slot.focus_mode = Control.FOCUS_NONE
                slot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
                slot.size_flags_vertical = Control.SIZE_EXPAND_FILL
                if i < _selected.size():
                        slot.text = "%s\n(click to remove)" % _slot_label(_selected[i])
                        var slot_index := i
                        slot.pressed.connect(func() -> void:
                                _selected.remove_at(slot_index)
                                _build_selected()
                                _refresh_state()
                        )
                else:
                        slot.text = "(empty)"
                        slot.disabled = true
                selected_grid.add_child(slot)

func _try_add(roster_index: int) -> void:
        if roster_index < 0 or roster_index >= _roster.size():
                return
        if _selected.size() >= MAX_SELECTION:
                return
        var entry := _roster[roster_index]
        if typeof(entry) != TYPE_DICTIONARY:
                return
        _selected.append(entry.duplicate(true))
        _build_selected()
        _refresh_state()

func _slot_label(entry: Dictionary) -> String:
        var id := String(entry.get("id", "sprout.woodling"))
        var level := int(entry.get("level", 1))
        return "%s (Lv%d)" % [_sprout_name(id), level]

func _sprout_name(id: String) -> String:
        for sprout in _sprout_defs:
            if typeof(sprout) != TYPE_DICTIONARY:
                continue
            if String(sprout.get("id", "")) == id:
                return String(sprout.get("name", "Sprout"))
        return "Sprout"

func _sprout_stats_text(id: String, level: int) -> String:
        var def := {}
        for sprout in _sprout_defs:
                if typeof(sprout) != TYPE_DICTIONARY:
                        continue
                if String(sprout.get("id", "")) == id:
                        def = sprout
                        break
        var base_stats: Dictionary = def.get("base_stats", {})
        var base_hp := int(base_stats.get("hp", 30))
        var base_atk := int(base_stats.get("attack", 6))
        var hp := base_hp + max(0, level - 1) * 3
        var atk := base_atk + max(0, level - 1)
        return "HP %d • ATK %d" % [hp, atk]

func _refresh_state() -> void:
        confirm_btn.disabled = _selected.is_empty()
        info_label.text = "Pick up to %d | Chosen: %d" % [MAX_SELECTION, _selected.size()]

func _on_confirm() -> void:
        SproutRegistry.set_last_selection(_selected)
        emit_signal("selection_done", _selected.duplicate(true))
        close()

func _on_cancel() -> void:
        emit_signal("cancelled")
        close()

func _clear_children(node: Node) -> void:
        for child in node.get_children():
                child.queue_free()
