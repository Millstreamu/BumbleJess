class_name TileChoiceWindow
extends CanvasLayer

var _choices: Array = []
var _resource_manager: Node = null

@onready var choices_box: HBoxContainer = $"Frame/Content/Choices"
@onready var tier_label: Label = $"Frame/Content/Bottom/TierLabel"
@onready var evolve_btn: Button = $"Frame/Content/Bottom/EvolveBtn"
@onready var close_btn: Button = $"Frame/Content/Bottom/CloseBtn"


func _ready() -> void:
	visible = false
	if TileGen != null:
		if not TileGen.is_connected("tile_choice_ready", Callable(self, "_on_choice_ready")):
			TileGen.connect("tile_choice_ready", Callable(self, "_on_choice_ready"))
		if not TileGen.is_connected("totem_tier_changed", Callable(self, "_on_tier_changed")):
			TileGen.connect("totem_tier_changed", Callable(self, "_on_tier_changed"))
	evolve_btn.pressed.connect(_on_evolve_pressed)
	close_btn.pressed.connect(_on_skip_pressed)
	_resource_manager = get_node_or_null("/root/ResourceManager")
	if (
		_resource_manager != null
		and not _resource_manager.is_connected(
			"resources_changed", Callable(self, "_on_resources_changed")
		)
	):
		_resource_manager.connect("resources_changed", Callable(self, "_on_resources_changed"))
	_refresh_tier_display()


func _on_choice_ready(choices: Array) -> void:
	_choices.clear()
	for choice_variant in choices:
		if choice_variant is Dictionary:
			_choices.append((choice_variant as Dictionary).duplicate(true))
	if _choices.is_empty():
		visible = false
		_clear_choices_ui()
		return
	_rebuild_choices()
	_refresh_tier_display()
	visible = true


func _on_tier_changed(_tier: int) -> void:
	_refresh_tier_display()


func _on_resources_changed() -> void:
	_refresh_tier_display()


func _on_evolve_pressed() -> void:
	if TileGen == null:
		return
	if TileGen.evolve():
		_refresh_tier_display()


func _on_skip_pressed() -> void:
	if TileGen != null:
		TileGen.skip()
	visible = false


func _rebuild_choices() -> void:
	_clear_choices_ui()
	for index in range(_choices.size()):
		var pack_variant: Variant = _choices[index]
		if not (pack_variant is Dictionary):
			continue
		var pack: Dictionary = pack_variant
		var column := VBoxContainer.new()
		column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		column.size_flags_vertical = Control.SIZE_EXPAND_FILL
		column.custom_minimum_size = Vector2(180, 0)

		var title := Label.new()
		title.text = String(pack.get("id", "(pack)"))
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		column.add_child(title)

		var details := RichTextLabel.new()
		details.bbcode_enabled = true
		details.autowrap_mode = TextServer.AUTOWRAP_WORD
		details.scroll_active = false
		details.fit_content = true
		details.size_flags_vertical = Control.SIZE_EXPAND_FILL
		var lines: Array[String] = []
		var tiles_variant: Variant = pack.get("tiles", [])
		if tiles_variant is Array and not (tiles_variant as Array).is_empty():
			var tile_ids: Array = tiles_variant
			var tile_strings: Array[String] = []
			for tile_entry in tile_ids:
				tile_strings.append(String(tile_entry))
			lines.append("[b]Tiles[/b]: " + ", ".join(tile_strings))
		var specials_variant: Variant = pack.get("special", [])
		if specials_variant is Array and not (specials_variant as Array).is_empty():
			var special_ids: Array = specials_variant
			var special_strings: Array[String] = []
			for special_entry in special_ids:
				special_strings.append(String(special_entry))
			lines.append("[b]Special[/b]: " + ", ".join(special_strings))
		details.text = "\n".join(lines)
		column.add_child(details)

		var select_btn := Button.new()
		select_btn.text = "Select"
		select_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var button_index := index
		select_btn.pressed.connect(
			func() -> void:
				if TileGen != null:
					TileGen.choose_index(button_index)
				visible = false
		)
		column.add_child(select_btn)
		choices_box.add_child(column)


func _clear_choices_ui() -> void:
	for child in choices_box.get_children():
		child.queue_free()


func _refresh_tier_display() -> void:
	if TileGen == null:
		tier_label.text = "Tier 1"
		evolve_btn.disabled = true
		evolve_btn.text = "Evolve"
		return
	var tier := TileGen.get_tier()
	tier_label.text = "Tier %d" % tier
	if TileGen.can_evolve():
		var cost := TileGen.next_evolve_cost()
		if cost > 0:
			evolve_btn.text = "Evolve (%d Life)" % cost
		else:
			evolve_btn.text = "Evolve"
		evolve_btn.disabled = not TileGen.can_afford_next_evolve()
	else:
		evolve_btn.text = "Maxed"
		evolve_btn.disabled = true
