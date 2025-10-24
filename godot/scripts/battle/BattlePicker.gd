extends CanvasLayer
class_name BattlePicker

signal selection_done(selection: Array)
signal cancelled()

const MAX_SELECTION := 6

@export var sprout_card_scene: PackedScene = preload("res://scenes/battle/SproutCard.tscn")
@export var roster_grid_path: NodePath
@export var selected_grid_path: NodePath
@export var confirm_btn_path: NodePath
@export var cancel_btn_path: NodePath
@export var info_label_path: NodePath

@onready var roster_grid: GridContainer = _resolve_node(roster_grid_path) as GridContainer
@onready var selected_grid: GridContainer = _resolve_node(selected_grid_path) as GridContainer
@onready var confirm_btn: Button = _resolve_node(confirm_btn_path) as Button
@onready var cancel_btn: Button = _resolve_node(cancel_btn_path) as Button
@onready var info_label: Label = _resolve_node(info_label_path) as Label

var _roster: Array = []
var _selected: Array = []

func _ready() -> void:
        process_mode = Node.PROCESS_MODE_ALWAYS
        visible = false
        if confirm_btn:
                confirm_btn.pressed.connect(_on_confirm)
        if cancel_btn:
                cancel_btn.pressed.connect(_on_cancel)
        _bind_sprout_registry()
        _bind_resource_manager()

func open() -> void:
        visible = true
        _refresh_from_registry(true)
        _build_roster()
        _build_selected()
        _refresh_state()

func close() -> void:
        visible = false

func _bind_sprout_registry() -> void:
        var sprout_registry: Node = get_node_or_null("/root/SproutRegistry")
        if sprout_registry == null:
                return
        if not sprout_registry.is_connected("roster_changed", Callable(self, "_on_registry_roster_changed")):
                sprout_registry.connect("roster_changed", Callable(self, "_on_registry_roster_changed"))

func _bind_resource_manager() -> void:
        var resource_manager: Node = get_node_or_null("/root/ResourceManager")
        if resource_manager == null:
                return
        if not resource_manager.is_connected("item_changed", Callable(self, "_on_resource_item_changed")):
                resource_manager.connect("item_changed", Callable(self, "_on_resource_item_changed"))

func _on_registry_roster_changed() -> void:
        _refresh_from_registry()
        _build_roster()
        _build_selected()
        _refresh_state()

func _on_resource_item_changed(item: String) -> void:
        if item != "soul_seeds":
                return
        _build_selected()

func _refresh_from_registry(load_selection: bool = false) -> void:
        _roster = SproutRegistry.get_roster()
        if load_selection:
                _selected = _sanitize_selection(SproutRegistry.get_last_selection())
        else:
                _selected = _sync_selection_with_roster(_selected)

func _sanitize_selection(sel: Array) -> Array:
        var result: Array = []
        var seen: Dictionary = {}
        var limit: int = min(sel.size(), MAX_SELECTION)
        for i in range(limit):
                if sel[i] is Dictionary:
                        var entry: Dictionary = sel[i]
                        var uid := String(entry.get("uid", ""))
                        if not uid.is_empty() and seen.has(uid):
                                continue
                        if not uid.is_empty():
                                seen[uid] = true
                        result.append(entry.duplicate(true))
        return result

func _sync_selection_with_roster(sel: Array) -> Array:
        var result: Array = []
        var seen: Dictionary = {}
        for entry_variant in sel:
                if entry_variant is Dictionary:
                        var entry: Dictionary = entry_variant
                        var uid := String(entry.get("uid", ""))
                        if uid.is_empty():
                                continue
                        if seen.has(uid):
                                continue
                        var roster_entry: Dictionary = SproutRegistry.get_entry_by_uid(uid)
                        if roster_entry.is_empty():
                                continue
                        seen[uid] = true
                        result.append(roster_entry)
        return result

func _build_roster() -> void:
        if roster_grid == null:
                return
        _clear_children(roster_grid)
        var selected_lookup := _selected_uid_lookup()
        for i in range(_roster.size()):
                if _roster[i] is not Dictionary:
                        continue
                var entry: Dictionary = _roster[i]
                var uid := String(entry.get("uid", ""))
                if not uid.is_empty() and selected_lookup.has(uid):
                        continue
                var card := _make_card(entry, i)
                if card:
                        roster_grid.add_child(card)

func _make_card(entry: Dictionary, idx: int) -> Button:
        var card: Button
        if sprout_card_scene:
                card = sprout_card_scene.instantiate() as Button
        if card == null:
                card = Button.new()
        var id := String(entry.get("id", "sprout.woodling"))
        var level := int(entry.get("level", 1))
        var uid := String(entry.get("uid", ""))
        var display_name: String = SproutRegistry.get_sprout_name(id)
        if not uid.is_empty():
                display_name = "%s [%s]" % [display_name, uid]
        var stats_text := SproutRegistry.short_stats_label(id, level)
        var card_ui := card as SproutCardUI
        if card_ui:
                card_ui.set_display_name(display_name)
                card_ui.set_stats(stats_text)
        else:
                var name_label: Label = card.get_node_or_null("Name")
                if name_label:
                        name_label.text = display_name
                var stats_label: Label = card.get_node_or_null("Stats")
                if stats_label:
                        stats_label.text = stats_text
        card.pressed.connect(func() -> void:
                _try_add(idx)
        )
        return card

func _build_selected() -> void:
        if selected_grid == null:
                return
        _clear_children(selected_grid)
        for i in range(MAX_SELECTION):
                var slot := Button.new()
                slot.focus_mode = Control.FOCUS_NONE
                slot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
                slot.size_flags_vertical = Control.SIZE_EXPAND_FILL
                if i < _selected.size():
                        var entry: Dictionary = _selected[i]
                        var slot_index := i
                        var uid := String(entry.get("uid", ""))
                        var display_uid := uid if not uid.is_empty() else "-"
                        slot.text = "%s\nUID: %s\n(click to remove)" % [_slot_label(entry), display_uid]
                        slot.pressed.connect(func() -> void:
                                _selected.remove_at(slot_index)
                                _build_roster()
                                _build_selected()
                                _refresh_state()
                        )
                        var btn := Button.new()
                        btn.text = "+1 Lv (1 Seed)"
                        btn.focus_mode = Control.FOCUS_NONE
                        btn.disabled = _current_soul_seeds() <= 0 or uid.is_empty()
                        btn.pressed.connect(func() -> void:
                                if uid.is_empty():
                                        return
                                if SproutRegistry.level_up(uid, 1):
                                        _refresh_from_registry()
                                        _build_roster()
                                        _build_selected()
                                        _refresh_state()
                        )
                        slot.add_child(btn)
                else:
                        slot.text = "(empty)"
                        slot.disabled = true
                selected_grid.add_child(slot)

func _current_soul_seeds() -> int:
        var resource_manager: Node = get_node_or_null("/root/ResourceManager")
        if resource_manager == null:
                return 0
        return int(resource_manager.get("soul_seeds"))

func _try_add(roster_index: int) -> void:
                if roster_index < 0 or roster_index >= _roster.size():
                                return
                var entry_value = _roster[roster_index]
                if entry_value is not Dictionary:
                                return
                var entry: Dictionary = entry_value
                var uid := String(entry.get("uid", ""))
                var existing_index := -1
                if not uid.is_empty():
                                existing_index = _find_selected_index(uid)
                if existing_index == -1 and _selected.size() >= MAX_SELECTION:
                                return
                if not uid.is_empty():
                                if existing_index != -1:
                                                _selected.remove_at(existing_index)
                _selected.append(entry.duplicate(true))
                _build_roster()
                _build_selected()
                _refresh_state()

func _find_selected_index(uid: String) -> int:
                if uid.is_empty():
                                return -1
                for i in range(_selected.size()):
                                var entry_variant: Variant = _selected[i]
                                if entry_variant is Dictionary:
                                                var entry: Dictionary = entry_variant
                                                if String(entry.get("uid", "")) == uid:
                                                                return i
                return -1

func _slot_label(entry: Dictionary) -> String:
        var id := String(entry.get("id", "sprout.woodling"))
        var level := int(entry.get("level", 1))
        return "%s (Lv%d)" % [SproutRegistry.get_sprout_name(id), level]

func _refresh_state() -> void:
        if confirm_btn:
                confirm_btn.disabled = _selected.is_empty()
        if info_label:
                info_label.text = "Pick up to %d | Chosen: %d" % [MAX_SELECTION, _selected.size()]

func _selected_uid_lookup() -> Dictionary:
        var result: Dictionary = {}
        for entry_variant in _selected:
                if entry_variant is Dictionary:
                        var entry: Dictionary = entry_variant
                        var uid := String(entry.get("uid", ""))
                        if uid.is_empty():
                                continue
                        result[uid] = true
        return result

func _on_confirm() -> void:
        _selected = _sanitize_selection(_selected)
        SproutRegistry.set_last_selection(_selected)
        emit_signal("selection_done", _selected.duplicate(true))
        close()

func _on_cancel() -> void:
        emit_signal("cancelled")
        close()

func _clear_children(node: Node) -> void:
        if node == null:
                return
        for child in node.get_children():
                child.queue_free()

func _resolve_node(path: NodePath) -> Node:
        if path.is_empty():
                return null
        return get_node_or_null(path)
