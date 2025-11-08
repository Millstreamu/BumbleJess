extends CanvasLayer
class_name PreRunSetup

signal setup_finished(totem_id: String, sprout_ids: Array)

const TOTEM_CARD_SCENE_PATH := "res://scenes/ui/TotemCard.tscn"
const SPROUT_CARD_SCENE_PATH := "res://scenes/battle/SproutCard.tscn"
const CORE_TILE_CARD_SCENE_PATH := "res://scenes/ui/CoreTileCard.tscn"

@onready var tabs: TabContainer = $"Panel/Root/Tabs"
@onready var btn_cancel: Button = $"Panel/Root/Header/CloseBtn"
@onready var btn_back: Button = $"Panel/Root/Footer/BackBtn"
@onready var btn_start: Button = $"Panel/Root/Footer/StartRunBtn"

@onready var totem_grid: HFlowContainer = $"Panel/Root/Tabs/Totem/ScrollContainer/TotemGrid"
@onready var totem_info: Label = $"Panel/Root/Tabs/Totem/TotemFooter/TotemInfo"
@onready var btn_totem_confirm: Button = $"Panel/Root/Tabs/Totem/TotemFooter/TotemConfirm"

@onready var sprout_grid: HFlowContainer = $"Panel/Root/Tabs/Sprouts/ScrollContainer/SproutGrid"
@onready var sprout_info: Label = $"Panel/Root/Tabs/Sprouts/SproutFooter/SproutInfo"
@onready var btn_sprout_clear: Button = $"Panel/Root/Tabs/Sprouts/SproutFooter/ClearBtn"
@onready var btn_sprout_confirm: Button = $"Panel/Root/Tabs/Sprouts/SproutFooter/SproutConfirm"

@onready var core_filter: OptionButton = $"Panel/Root/Tabs/CoreTiles/FilterRow/FilterCat"
@onready var core_search: LineEdit = $"Panel/Root/Tabs/CoreTiles/FilterRow/Search"
@onready var core_count: Label = $"Panel/Root/Tabs/CoreTiles/FilterRow/CountLabel"
@onready var core_clear: Button = $"Panel/Root/Tabs/CoreTiles/FilterRow/ClearBtn"
@onready var core_confirm: Button = $"Panel/Root/Tabs/CoreTiles/Footer/ConfirmCoreBtn"
@onready var core_grid: HFlowContainer = $"Panel/Root/Tabs/CoreTiles/ScrollContainer/TileGrid"

var _totems: Array = []
var _sprouts: Array = []
var _totem_by_id: Dictionary = {}
var _sprout_by_id: Dictionary = {}
var _chosen_totem: String = ""
var _chosen_sprouts: Array[String] = []
var _all_tiles: Array = []
var _core_selected: Array[String] = []
var _tree_was_paused: bool = false

var _totem_card_scene: PackedScene = null
var _sprout_card_scene: PackedScene = null
var _core_tile_card_scene: PackedScene = null

const CORE_MAX := 10

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	visible = false
	btn_cancel.pressed.connect(_on_cancel)
	btn_back.pressed.connect(_on_back)
	btn_start.pressed.connect(_on_start)
	btn_totem_confirm.pressed.connect(_on_totem_confirm)
	btn_sprout_clear.pressed.connect(_on_sprout_clear)
	btn_sprout_confirm.pressed.connect(_on_sprout_confirm)
	core_filter.item_selected.connect(_on_core_filter)
	core_search.text_changed.connect(_on_core_search_changed)
	core_clear.pressed.connect(_on_core_clear)
	core_confirm.pressed.connect(_on_core_confirm)
	_totem_card_scene = _load_scene(TOTEM_CARD_SCENE_PATH)
	_sprout_card_scene = _load_scene(SPROUT_CARD_SCENE_PATH)
	_core_tile_card_scene = _load_scene(CORE_TILE_CARD_SCENE_PATH)
	_load_data()
	_load_all_tiles()
	_apply_existing_choices()
	_build_totem_grid()
	_build_sprout_grid()
	_build_core_filters()
	_rebuild_core_grid()
	_refresh_all()
	if Engine.has_singleton("MetaManager"):
		if not MetaManager.library_changed.is_connected(_on_sprout_library_changed):
			MetaManager.library_changed.connect(_on_sprout_library_changed)

func open() -> void:
		_apply_existing_choices()
		_update_totem_badges()
		_update_sprout_badges()
		_rebuild_core_grid()
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
		_core_selected.clear()
		for entry in RunConfig.core_tiles:
				if typeof(entry) != TYPE_STRING:
						continue
				var cid := String(entry)
				if cid.is_empty():
						continue
				if _core_selected.has(cid):
						continue
				_core_selected.append(cid)

func _build_totem_grid() -> void:
	_clear_children(totem_grid)

	if _totem_card_scene == null:
		_update_totem_badges()
		return

	for entry_variant in _totems:
		if not (entry_variant is Dictionary):
			continue

		var entry: Dictionary = entry_variant
		var tid := String(entry.get("id", ""))
		if tid.is_empty():
			continue

		var button := _totem_card_scene.instantiate() as Button
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

	if _sprout_card_scene == null:
		_update_sprout_badges()
		return

	var removed_locked := false

	for sprout_variant in _sprouts:
		if not (sprout_variant is Dictionary):
			continue

		var sprout: Dictionary = sprout_variant
		var sid := String(sprout.get("id", ""))
		if sid.is_empty():
			continue

		var button := _sprout_card_scene.instantiate() as Button
		if button == null:
			continue

		button.set_meta("id", sid)

		var display_name := String(sprout.get("name", sid))
		if Engine.has_singleton("SproutRegistry") and SproutRegistry.has_method("get_sprout_name"):
			var registry_name := SproutRegistry.get_sprout_name(sid)
			if not registry_name.is_empty():
				display_name = registry_name

		var stats_text := ""
		if Engine.has_singleton("SproutRegistry") and SproutRegistry.has_method("short_stats_label"):
			stats_text = SproutRegistry.short_stats_label(sid, 1)
		else:
			var base_stats: Variant = sprout.get("base_stats", {})
			if base_stats is Dictionary:
				var base_dict := base_stats as Dictionary
				var hp := int(base_dict.get("hp", 0))
				var atk := int(base_dict.get("attack", 0))
				var aspeed := float(base_dict.get("attack_speed", 0.0))
				stats_text = "Lv1 • HP %d • ATK %d • AS %.2f" % [hp, atk, aspeed]

		var card_ui := button as SproutCardUI
		if card_ui != null:
			card_ui.set_display_name(display_name)
			card_ui.set_stats(stats_text)
		else:
			var name_label := button.get_node_or_null("Name") as Label
			if name_label != null:
				name_label.text = display_name
			var stats_label := button.get_node_or_null("Stats") as Label
			if stats_label != null:
				stats_label.text = stats_text

		if button.get_node_or_null("Chosen") == null:
			var badge := Label.new()
			badge.name = "Chosen"
			badge.text = "✓"
			badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			badge.vertical_alignment   = VERTICAL_ALIGNMENT_TOP
			badge.anchor_left = 1.0
			badge.anchor_right = 1.0
			badge.anchor_top = 0.0
			badge.anchor_bottom = 0.0
			badge.offset_left = -32.0
			badge.offset_right = -8.0
			badge.offset_top = 8.0
			badge.offset_bottom = 32.0
			badge.visible = false
			button.add_child(badge)

		var locked := _is_locked_sprout(sprout)
		if locked and _chosen_sprouts.has(sid):
			_chosen_sprouts.erase(sid)
			removed_locked = true

		button.disabled = locked
		if locked:
			button.modulate = Color(1, 1, 1, 0.5)
			button.tooltip_text = "Locked — discover an Artefact to unlock."
		else:
			button.modulate = Color(1, 1, 1, 1)
			button.tooltip_text = ""

		button.pressed.connect(func():
			_toggle_sprout(sid)
		)

		sprout_grid.add_child(button)

	_update_sprout_badges()

	if removed_locked:
		_refresh_all()



func _on_sprout_library_changed() -> void:
		_build_sprout_grid()
		_update_sprout_badges()
		_refresh_all()

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

func _load_all_tiles() -> void:
		_all_tiles = DataLite.load_json_array("res://data/tiles.json")

func _build_core_filters() -> void:
		if core_filter == null:
				return
		core_filter.clear()
		core_filter.add_item("All")
		core_filter.set_item_metadata(0, "")
		var categories := CategoryMap.canonical_categories()
		for cat in categories:
				var display := CategoryMap.display_name(cat)
				core_filter.add_item(display)
				var idx := core_filter.get_item_count() - 1
				core_filter.set_item_metadata(idx, cat)
		if core_filter.get_item_count() > 0:
				core_filter.select(0)

func _rebuild_core_grid() -> void:
	if core_grid == null:
		return

	_clear_children(core_grid)

	if _core_tile_card_scene == null:
		_refresh_core_ui()
		return

	var sel_cat := ""
	var idx := core_filter.selected if core_filter != null else -1
	if idx >= 0:
		var meta: Variant = core_filter.get_item_metadata(idx)
		if typeof(meta) == TYPE_STRING:
			sel_cat = String(meta)

	var query := ""
	if core_search != null:
		query = core_search.text.strip_edges().to_lower()

	for entry_variant in _all_tiles:
		if not (entry_variant is Dictionary):
			continue

		var entry: Dictionary = entry_variant
		var id := String(entry.get("id", ""))
		if id.is_empty():
			continue

		var cat := CategoryMap.canonical(String(entry.get("category", "")))
		if not sel_cat.is_empty() and cat != sel_cat:
			continue

		if query != "":
			var hay := String(entry.get("name", id)) + " " + id
			var tags_variant: Variant = entry.get("tags", [])
			if tags_variant is PackedStringArray:
				for tag in tags_variant:
					hay += " " + String(tag)
			elif tags_variant is Array:
				for tag in tags_variant:
					hay += " " + String(tag)
			hay = hay.to_lower()
			if not hay.contains(query):
				continue

		var button := _core_tile_card_scene.instantiate() as Button
		if button == null:
			continue

		button.set_meta("id", id)

		var name_label := button.get_node_or_null("Content/Header/Name") as Label
		if name_label != null:
			name_label.text = String(entry.get("name", id))

		var cat_label := button.get_node_or_null("Content/Header/Cat") as Label
		if cat_label != null:
			cat_label.text = CategoryMap.display_name(cat)

		var summary_label := button.get_node_or_null("Content/Summary") as RichTextLabel
		if summary_label != null:
			summary_label.bbcode_text = _summarize_tile(entry)

		var chosen_label := button.get_node_or_null("Chosen") as Label
		if chosen_label != null:
			chosen_label.visible = _core_selected.has(id)

		button.pressed.connect(func():
			_toggle_core(id)
		)

		core_grid.add_child(button)

	_refresh_core_ui()


func _load_scene(path: String) -> PackedScene:
		if path.is_empty():
				return null
		if not ResourceLoader.exists(path):
				push_warning("PreRunSetup: missing scene at %s" % path)
				return null
		var resource := ResourceLoader.load(path)
		if resource is PackedScene:
				return resource
		push_warning("PreRunSetup: resource at %s is not a PackedScene" % path)
		return null

func _summarize_tile(def: Dictionary) -> String:
		var lines: Array[String] = []
		var outputs_variant: Variant = def.get("outputs", {})
		if outputs_variant is Dictionary:
				var output_pairs: Array[String] = []
				for key in (outputs_variant as Dictionary).keys():
						var amount := int((outputs_variant as Dictionary).get(key, 0))
						var display := CategoryMap.display_name(String(key))
						output_pairs.append("%s +%d" % [display, amount])
				output_pairs.sort()
				if not output_pairs.is_empty():
						lines.append("[b]Outputs:[/b] " + ", ".join(output_pairs))
		var syn_variant: Variant = def.get("synergies", [])
		var syn_count := 0
		if syn_variant is Array:
				syn_count = (syn_variant as Array).size()
		elif syn_variant is PackedStringArray:
				syn_count = int((syn_variant as PackedStringArray).size())
		if syn_count > 0:
				lines.append("Synergies x%d" % syn_count)
		if lines.is_empty():
				return "—"
		return "\n".join(lines)

func _toggle_core(id: String) -> void:
		var tid := String(id)
		if tid.is_empty():
				return
		if _core_selected.has(tid):
				_core_selected.erase(tid)
		else:
				if _core_selected.size() >= CORE_MAX:
						return
				_core_selected.append(tid)
		_rebuild_core_grid()

func _refresh_core_ui() -> void:
		if core_count != null:
				core_count.text = "%d / %d" % [_core_selected.size(), CORE_MAX]
		if core_confirm != null:
				core_confirm.disabled = (_core_selected.size() == 0 or _core_selected.size() > CORE_MAX)

func _on_core_filter(_idx: int) -> void:
		_rebuild_core_grid()

func _on_core_search_changed(_text: String) -> void:
		_rebuild_core_grid()

func _on_core_clear() -> void:
		_core_selected.clear()
		_rebuild_core_grid()

func _on_core_confirm() -> void:
		RunConfig.set_core_tiles(_core_selected)
		_refresh_core_ui()

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
		tabs.current_tab = 2
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
		if _core_selected.size() > 0:
				RunConfig.set_core_tiles(_core_selected)
		else:
				var seeded := _seed_core_defaults()
				if seeded.is_empty():
						RunConfig.set_core_tiles([])
				else:
						RunConfig.set_core_tiles(seeded)
		emit_signal("setup_finished", _chosen_totem, _chosen_sprouts.duplicate())
		_close()

func _on_cancel() -> void:
		_close(true)

func _refresh_all() -> void:
		btn_totem_confirm.disabled = _chosen_totem.is_empty()
		btn_sprout_confirm.disabled = _chosen_sprouts.size() != 4
		btn_start.disabled = _chosen_totem.is_empty() or _chosen_sprouts.size() != 4
		_refresh_core_ui()

func _close(clear_config: bool = false) -> void:
		visible = false
		if clear_config:
				RunConfig.clear_for_new_run()
		if get_tree() != null:
				get_tree().paused = _tree_was_paused

func _clear_children(node: Node) -> void:
		for child in node.get_children():
				child.queue_free()

func _seed_core_defaults() -> Array[String]:
		var path := "res://data/core_defaults.json"
		var defaults := DataLite.load_json_dict(path)
		if defaults.is_empty():
				return []
		var max_core := int(defaults.get("max_core", CORE_MAX))
		if max_core <= 0:
				max_core = CORE_MAX
		var picks: Array[String] = []
		var categories_variant: Variant = defaults.get("seed_with_categories", [])
		var categories: Array = []
		if categories_variant is PackedStringArray:
				categories = Array(categories_variant)
		elif categories_variant is Array:
				categories = categories_variant
		for entry in categories:
				var cat := String(entry)
				if cat.is_empty():
						continue
				var canonical := CategoryMap.canonical(cat)
				var pick := _first_tile_for_category(canonical)
				if pick.is_empty() and canonical != cat:
						pick = _first_tile_for_category(cat)
				if pick.is_empty():
						continue
				if picks.has(pick):
						continue
				picks.append(pick)
				if picks.size() >= max_core:
						break
		return picks

func _first_tile_for_category(cat: String) -> String:
		if _all_tiles.is_empty():
				_load_all_tiles()
		var canonical_target := CategoryMap.canonical(cat)
		var fallback_target := String(cat)
		for entry_variant in _all_tiles:
				if not (entry_variant is Dictionary):
						continue
				var entry: Dictionary = entry_variant
				var id := String(entry.get("id", ""))
				if id.is_empty():
						continue
				var entry_cat := CategoryMap.canonical(String(entry.get("category", "")))
				if not canonical_target.is_empty() and entry_cat == canonical_target:
						return id
				if fallback_target != canonical_target:
						var raw_cat := String(entry.get("category", ""))
						if not raw_cat.is_empty() and raw_cat == fallback_target:
								return id
		return ""
