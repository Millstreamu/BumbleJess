extends CanvasLayer
class_name PreRunSetup

signal setup_finished(totem_id: String, sprout_ids: Array)

const TOTEM_CARD_SCENE := preload("res://scenes/ui/TotemCard.tscn")
const SPROUT_CARD_SCENE := preload("res://scenes/ui/SproutCard.tscn")

@onready var tabs: TabContainer = $"Panel/Root/Tabs"
@onready var btn_cancel: Button = $"Panel/Root/Header/CloseBtn"
@onready var btn_back: Button = $"Panel/Root/Footer/BackBtn"
@onready var btn_start: Button = $"Panel/Root/Footer/StartRunBtn"

@onready var totem_grid: HFlowContainer = $"Panel/Root/Tabs/Totem/ScrollContainer/TotemGrid"
@onready var totem_info: Label = $"Panel/Root/Tabs/Totem/TotemInfo"
@onready var btn_totem_confirm: Button = $"Panel/Root/Tabs/Totem/TotemConfirm"

@onready var sprout_grid: HFlowContainer = $"Panel/Root/Tabs/Sprouts/ScrollContainer/SproutGrid"
@onready var sprout_info: Label = $"Panel/Root/Tabs/Sprouts/SproutInfo"
@onready var btn_sprout_clear: Button = $"Panel/Root/Tabs/Sprouts/ClearBtn"
@onready var btn_sprout_confirm: Button = $"Panel/Root/Tabs/Sprouts/SproutConfirm"

var _totems: Array = []
var _sprouts: Array = []
var _totem_by_id: Dictionary = {}
var _sprout_by_id: Dictionary = {}
var _chosen_totem: String = ""
var _chosen_sprouts: Array[String] = []
var _tree_was_paused: bool = false

func _ready() -> void:
        process_mode = Node.PROCESS_MODE_WHEN_PAUSED
        visible = false
        btn_cancel.pressed.connect(_on_cancel)
        btn_back.pressed.connect(_on_back)
        btn_start.pressed.connect(_on_start)
        btn_totem_confirm.pressed.connect(_on_totem_confirm)
        btn_sprout_clear.pressed.connect(_on_sprout_clear)
        btn_sprout_confirm.pressed.connect(_on_sprout_confirm)
        _load_data()
        _build_totem_grid()
        _build_sprout_grid()
        _apply_existing_choices()
        _refresh_all()

func open() -> void:
        _apply_existing_choices()
        _update_totem_badges()
        _update_sprout_badges()
        _refresh_all()
        tabs.current_tab = 0
        _tree_was_paused = get_tree().paused if get_tree() != null else false
        if get_tree() != null:
                get_tree().paused = true
        visible = true

func _load_data() -> void:
        _totems = DataLite.load_json_array("res://data/totems.json")
        _sprouts = DataLite.load_json_array("res://data/sprouts.json")
        _totem_by_id.clear()
        for entry_variant in _totems:
                if not (entry_variant is Dictionary):
                        continue
                var entry: Dictionary = entry_variant
                var tid := String(entry.get("id", ""))
                if tid.is_empty():
                        continue
                _totem_by_id[tid] = entry
        _sprout_by_id.clear()
        for sprout_variant in _sprouts:
                if not (sprout_variant is Dictionary):
                        continue
                var sprout: Dictionary = sprout_variant
                var sid := String(sprout.get("id", ""))
                if sid.is_empty():
                        continue
                _sprout_by_id[sid] = sprout

func _apply_existing_choices() -> void:
        _chosen_totem = String(RunConfig.totem_id)
        var collected: Array[String] = []
        var rc_pool: Array = RunConfig.spawn_sprout_ids
        for entry in rc_pool:
                if typeof(entry) != TYPE_STRING:
                        continue
                var sid := String(entry)
                if sid.is_empty():
                        continue
                collected.append(sid)
        _chosen_sprouts = collected

func _build_totem_grid() -> void:
        _clear_children(totem_grid)
        for entry_variant in _totems:
                if not (entry_variant is Dictionary):
                        continue
                var entry: Dictionary = entry_variant
                var tid := String(entry.get("id", ""))
                if tid.is_empty():
                        continue
                var button := TOTEM_CARD_SCENE.instantiate() as Button
                if button == null:
                        continue
                button.set_meta("id", tid)
                var display_name := String(entry.get("name", tid))
                var desc := String(entry.get("desc", ""))
                var name_label := button.get_node_or_null("Name") as Label
                if name_label != null:
                        name_label.text = display_name
                var desc_label := button.get_node_or_null("Desc") as RichTextLabel
                if desc_label != null:
                        if desc.is_empty():
                                desc_label.text = "—"
                        else:
                                desc_label.text = desc
                var icon_path := String(entry.get("icon", ""))
                var icon_rect := button.get_node_or_null("Icon") as TextureRect
                if icon_rect != null:
                        icon_rect.texture = null
                        if not icon_path.is_empty() and ResourceLoader.exists(icon_path):
                                var tex := ResourceLoader.load(icon_path)
                                if tex is Texture2D:
                                        icon_rect.texture = tex
                button.pressed.connect(func():
                        _chosen_totem = tid
                        _update_totem_badges()
                        _refresh_all()
                )
                totem_grid.add_child(button)
        _update_totem_badges()

func _build_sprout_grid() -> void:
        _clear_children(sprout_grid)
        for sprout_variant in _sprouts:
                if not (sprout_variant is Dictionary):
                        continue
                var sprout: Dictionary = sprout_variant
                if _is_locked_sprout(sprout):
                        continue
                var sid := String(sprout.get("id", ""))
                if sid.is_empty():
                        continue
                var button := SPROUT_CARD_SCENE.instantiate() as Button
                if button == null:
                        continue
                button.set_meta("id", sid)
                var display_name := String(sprout.get("name", sid))
                var name_label := button.get_node_or_null("Name") as Label
                if name_label != null:
                        name_label.text = display_name
                var icon_rect := button.get_node_or_null("Icon") as TextureRect
                if icon_rect != null:
                        icon_rect.texture = null
                        var icon_path := String(sprout.get("icon", ""))
                        if not icon_path.is_empty() and ResourceLoader.exists(icon_path):
                                var tex := ResourceLoader.load(icon_path)
                                if tex is Texture2D:
                                        icon_rect.texture = tex
                button.pressed.connect(func():
                        _toggle_sprout(sid)
                )
                sprout_grid.add_child(button)
        _update_sprout_badges()

func _is_locked_sprout(sprout: Dictionary) -> bool:
        if not Engine.has_singleton("MetaManager"):
                return false
        if not MetaManager.has_method("is_unlocked_sprout"):
                return false
        var sid := String(sprout.get("id", ""))
        if sid.is_empty():
                return false
        return not MetaManager.is_unlocked_sprout(sid)

func _toggle_sprout(id: String) -> void:
        if _chosen_sprouts.has(id):
                _chosen_sprouts.erase(id)
        else:
                if _chosen_sprouts.size() >= 4:
                        return
                _chosen_sprouts.append(id)
        _update_sprout_badges()
        _refresh_all()

func _update_totem_badges() -> void:
        for child in totem_grid.get_children():
                if not (child is Button):
                        continue
                var button := child as Button
                var id := String(button.get_meta("id", "")) if button.has_meta("id") else ""
                var badge := button.get_node_or_null("Chosen") as Label
                if badge != null:
                        badge.visible = (id == _chosen_totem)
        var label_text := "—"
        if not _chosen_totem.is_empty():
                var entry_variant: Variant = _totem_by_id.get(_chosen_totem, {})
                if entry_variant is Dictionary:
                        label_text = String((entry_variant as Dictionary).get("name", _chosen_totem))
                else:
                        label_text = _chosen_totem
                label_text = "Selected: %s" % label_text
        totem_info.text = label_text

func _update_sprout_badges() -> void:
        for child in sprout_grid.get_children():
                if not (child is Button):
                        continue
                var button := child as Button
                var id := String(button.get_meta("id", "")) if button.has_meta("id") else ""
                var badge := button.get_node_or_null("Chosen") as Label
                if badge != null:
                        badge.visible = _chosen_sprouts.has(id)
        sprout_info.text = "Selected: %d / 4" % _chosen_sprouts.size()

func _on_totem_confirm() -> void:
        if _chosen_totem.is_empty():
                return
        RunConfig.set_totem(_chosen_totem)
        tabs.current_tab = 1
        _refresh_all()

func _on_sprout_clear() -> void:
        _chosen_sprouts.clear()
        _update_sprout_badges()
        _refresh_all()

func _on_sprout_confirm() -> void:
        if _chosen_sprouts.size() != 4:
                return
        RunConfig.set_spawn_sprouts(_chosen_sprouts)
        _refresh_all()

func _on_back() -> void:
        if tabs.current_tab > 0:
                tabs.current_tab -= 1
        else:
                _close(true)

func _on_start() -> void:
        if _chosen_totem.is_empty():
                return
        if _chosen_sprouts.size() != 4:
                return
        RunConfig.set_totem(_chosen_totem)
        RunConfig.set_spawn_sprouts(_chosen_sprouts)
        emit_signal("setup_finished", _chosen_totem, _chosen_sprouts.duplicate())
        _close()

func _on_cancel() -> void:
        _close(true)

func _refresh_all() -> void:
        btn_totem_confirm.disabled = _chosen_totem.is_empty()
        btn_sprout_confirm.disabled = _chosen_sprouts.size() != 4
        btn_start.disabled = _chosen_totem.is_empty() or _chosen_sprouts.size() != 4

func _close(clear_config: bool = false) -> void:
        visible = false
        if clear_config:
                RunConfig.clear_for_new_run()
        if get_tree() != null:
                get_tree().paused = _tree_was_paused

func _clear_children(node: Node) -> void:
        for child in node.get_children():
                child.queue_free()
