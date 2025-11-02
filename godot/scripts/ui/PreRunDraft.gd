extends CanvasLayer
class_name PreRunDraft

signal draft_done

const CATEGORIES := ["harvest", "build", "refine", "storage", "guard", "upgrade", "chanting"]

const CARD_SCENE_PATH := "res://scenes/ui/VariantCard.tscn"

var _card_scene: PackedScene
var _tree_was_paused := false

@onready var tabs: TabContainer = $"Frame/VBox/Tabs"
@onready var confirm_btn: Button = $"Frame/VBox/Bottom/ConfirmBtn"
@onready var reroll_btn: Button = $"Frame/VBox/Bottom/RerollBtn"
@onready var cancel_btn: Button = $"Frame/VBox/Bottom/CancelBtn"

var _tiles_by_cat: Dictionary = {}
var _choices: Dictionary = {}
var _tab_nodes: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	_card_scene = load(CARD_SCENE_PATH)
	if _card_scene == null:
		push_error("Unable to load variant card scene at %s" % CARD_SCENE_PATH)
	visible = false
	cancel_btn.pressed.connect(_on_cancel)
	confirm_btn.pressed.connect(_on_confirm)
	reroll_btn.pressed.connect(_on_reroll_current)
	if not RunConfig.is_connected("selections_changed", Callable(self, "_refresh_confirm")):
		RunConfig.connect("selections_changed", Callable(self, "_refresh_confirm"))
	_load_tiles()
	_build_tabs()
	_roll_all()
	_refresh_confirm()


func open() -> void:
	RunConfig.clear_draft_selections()
	_roll_all()
	_refresh_confirm()
	tabs.current_tab = 0
	_tree_was_paused = get_tree().paused
	get_tree().paused = true
	visible = true


func _on_cancel() -> void:
	_close()


func _load_tiles() -> void:
	_tiles_by_cat.clear()
	var arr: Array = DataLite.load_json_array("res://data/tiles.json")
	for entry in arr:
		if not (entry is Dictionary):
			continue
		var tile: Dictionary = entry
		var raw_cat := String(tile.get("category", ""))
		var cat := _canonical(raw_cat)
		var tile_id := String(tile.get("id", ""))
		if cat.is_empty() or tile_id.is_empty():
			continue
		if not _tiles_by_cat.has(cat):
			_tiles_by_cat[cat] = []
		var list: Array = _tiles_by_cat[cat]
		list.append(tile)
		_tiles_by_cat[cat] = list


func _build_tabs() -> void:
	for child in tabs.get_children():
		child.queue_free()
	_tab_nodes.clear()
	for cat in CATEGORIES:
		var canonical_cat := _canonical(cat)
		var display := CategoryMap.display_name(canonical_cat)
		var vb := VBoxContainer.new()
		vb.name = canonical_cat
		vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		vb.size_flags_vertical = Control.SIZE_EXPAND_FILL
		var label := Label.new()
		label.text = display
		var row := HBoxContainer.new()
		row.name = "Cards"
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.size_flags_vertical = Control.SIZE_EXPAND_FILL
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		vb.add_child(label)
		vb.add_child(row)
		tabs.add_child(vb)
		tabs.set_tab_title(tabs.get_child_count() - 1, display)
		_tab_nodes[canonical_cat] = vb


func _roll_all() -> void:
	for cat in CATEGORIES:
		_roll_cat(cat)


func _roll_cat(cat: String) -> void:
	var canonical_cat := _canonical(cat)
	var pool_variant: Variant = _tiles_by_cat.get(canonical_cat, [])
	if not (pool_variant is Array) and canonical_cat != cat:
		pool_variant = _tiles_by_cat.get(cat, [])
	var pool: Array = pool_variant if pool_variant is Array else []
	var tiles := pool.duplicate()
	tiles.shuffle()
	var picks: Array = []
	var seen: Dictionary = {}
	for entry in tiles:
		if not (entry is Dictionary):
			continue
		var tile: Dictionary = entry
		var tile_id := String(tile.get("id", ""))
		if tile_id.is_empty() or seen.has(tile_id):
			continue
		seen[tile_id] = true
		picks.append(tile)
		if picks.size() >= 3:
			break
	_choices[canonical_cat] = picks
	var current := RunConfig.get_selection(canonical_cat)
	var still_valid := false
	for choice in picks:
		var choice_id := String(choice.get("id", ""))
		if choice_id == current:
			still_valid = true
			break
	if not still_valid:
		RunConfig.set_selection(canonical_cat, "")
	_rebuild_cards(canonical_cat)


func _rebuild_cards(cat: String) -> void:
	var canonical_cat := _canonical(cat)
	if not _tab_nodes.has(canonical_cat):
		return
	var page_variant: Variant = _tab_nodes.get(canonical_cat)
	var page := page_variant as VBoxContainer
	if page == null:
		return
	var row := page.get_node("Cards")
	if row == null:
		return
	for child in row.get_children():
		child.queue_free()
	var picks_variant: Variant = _choices.get(canonical_cat, [])
	var picks: Array = picks_variant if picks_variant is Array else []
	for tile_variant in picks:
		if not (tile_variant is Dictionary):
			continue
		var tile: Dictionary = tile_variant
		if _card_scene == null:
			return
		var card_instance: Node = _card_scene.instantiate()
		if card_instance == null:
			continue
		var tile_id := String(tile.get("id", ""))
		var display_name := String(tile.get("name", tile_id))
		var button := card_instance as Button
		if button == null:
			card_instance.queue_free()
			continue
		button.set_meta("tile_id", tile_id)
		var name_label := button.get_node_or_null("Name") as Label
		if name_label != null:
			name_label.text = display_name
		var rules_label := button.get_node_or_null("Rules") as RichTextLabel
		if rules_label != null:
			rules_label.text = _summarize_rules(tile.get("rules", {}))
		var badge := button.get_node_or_null("ChosenBadge") as Label
		if badge != null:
			badge.visible = tile_id == RunConfig.get_selection(canonical_cat)
		button.pressed.connect(
			func():
				RunConfig.set_selection(canonical_cat, tile_id)
				_update_badges(canonical_cat, tile_id)
				_refresh_confirm()
		)
		row.add_child(button)


func _update_badges(cat: String, chosen_id: String) -> void:
	var canonical_cat := _canonical(cat)
	if not _tab_nodes.has(canonical_cat):
		return
	var page_variant: Variant = _tab_nodes.get(canonical_cat)
	var page := page_variant as VBoxContainer
	if page == null:
		return
	var row := page.get_node("Cards")
	if row == null:
		return
	for child in row.get_children():
		if not (child is Button):
			continue
		var button := child as Button
		var badge := button.get_node_or_null("ChosenBadge") as Label
		if badge == null:
			continue
		var tile_id := String(button.get_meta("tile_id")) if button.has_meta("tile_id") else ""
		badge.visible = (tile_id == chosen_id)


func _summarize_rules(rules_variant: Variant) -> String:
	if not (rules_variant is Dictionary):
		return "—"
	var rules: Dictionary = rules_variant
	if rules.is_empty():
		return "—"
	var lines: Array[String] = []
	for key in rules.keys():
		var value: Variant = rules[key]
		lines.append("%s: %s" % [str(key), JSON.stringify(value)])
	return "\n".join(lines)


func _on_reroll_current() -> void:
	var idx := tabs.current_tab
	if idx < 0 or idx >= CATEGORIES.size():
		return
	var cat := String(CATEGORIES[idx])
	_roll_cat(cat)
	_refresh_confirm()


func _refresh_confirm() -> void:
	confirm_btn.disabled = not RunConfig.all_categories_selected()


func _on_confirm() -> void:
	if not RunConfig.all_categories_selected():
		return
	DeckManager.build_starting_deck_from_ratios("res://data/deck.json", RunConfig.selected_variants)
	if DeckManager.deck.size() > 0:
		DeckManager.shuffle()
		DeckManager.draw_one()
	else:
		DeckManager.next_tile_id = ""
	RunConfig.mark_ready()
	emit_signal("draft_done")
	_close()


func _canonical(cat: String) -> String:
	var canonical_cat := CategoryMap.canonical(cat)
	if canonical_cat.is_empty():
		return cat
	return canonical_cat


func _close() -> void:
	visible = false
	if get_tree() == null:
		return
	get_tree().paused = _tree_was_paused
