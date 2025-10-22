extends Node2D

const LAYER_GROUND := 0
const LAYER_OBJECTS := 1
const LAYER_LIFE := 2
const LAYER_FX := 3

const SPROUT_REGISTER_SCENE := preload("res://scenes/battle/BattlePicker.tscn")
const TILE_CHOICE_WINDOW_SCENE := preload("res://scenes/ui/TileChoiceWindow.tscn")

@export var width := 16 : set = set_width
@export var height := 12 : set = set_height
@export var tile_px := 128 : set = set_tile_px

@onready var hexmap: TileMap = $HexMap
@onready var cursor: Node = $Cursor
@onready var hud: Label = $HUD/DeckLabel
@onready var resources_panel: Control = $HUD.get_node_or_null("ResourcesPanel")
@onready var resource_labels: Dictionary[String, Label] = {
	"nature": $HUD.get_node_or_null("ResourcesPanel/Content/Rows/NatureValue") as Label,
	"earth": $HUD.get_node_or_null("ResourcesPanel/Content/Rows/EarthValue") as Label,
	"water": $HUD.get_node_or_null("ResourcesPanel/Content/Rows/WaterValue") as Label,
	"life": $HUD.get_node_or_null("ResourcesPanel/Content/Rows/LifeValue") as Label,
}
@onready var soul_seeds_label: Label = $HUD.get_node_or_null("ResourcesPanel/Content/Rows/SoulSeedsValue") as Label

var _is_ready := false
var tiles_name_to_id: Dictionary = {}
var tiles_id_to_name: Dictionary = {}
var origin_cell: Vector2i = Vector2i.ZERO
var rules: PlacementRules = PlacementRules.new()
var turn := 0
var _cell_metadata: Dictionary = {}
var _sprout_picker: BattlePicker = null
var _tile_choice_window: TileChoiceWindow = null
var _special_queue: Array[String] = []
var _placing_special: String = ""

func _get_resource_manager() -> Node:
	return get_node_or_null("/root/ResourceManager")

func _get_turn_engine() -> Node:
	return get_node_or_null("/root/TurnEngine")

func _calculate_hex_cell_size(px: int) -> Vector2i:
	var horizontal_spacing := int(round(float(px) * 0.75))
	var vertical_spacing := int(round(float(px) * (sqrt(3.0) / 2.0)))
	return Vector2i(max(horizontal_spacing, 1), max(vertical_spacing, 1))

func _ready() -> void:
	add_child(rules)
	rules.set_world(self)
	_ensure_hex_config()
	_ensure_layers()
	_build_tileset()
	var growth_manager: Node = get_node_or_null("/root/GrowthManager")
	if growth_manager != null:
		growth_manager.bind_world(self)
		var sprout_registry: Node = get_node_or_null("/root/SproutRegistry")
		if sprout_registry != null and not growth_manager.is_connected("grove_spawned", Callable(sprout_registry, "on_grove_spawned")):
			growth_manager.connect("grove_spawned", Callable(sprout_registry, "on_grove_spawned"))
        _bind_resource_manager()
        _bind_sprout_registry()
        _bind_tile_gen()
        var decay_manager: Node = get_node_or_null("/root/DecayManager")
        if decay_manager != null and decay_manager.has_method("bind_world"):
                        decay_manager.call("bind_world", self)
	_ensure_toggle_threats_action()
	_ensure_toggle_sprout_register_action()
	var threat_list: Control = get_node_or_null("ThreatHUD/ThreatList")
	if threat_list != null:
		threat_list.visible = false
	_is_ready = true
	draw_debug_grid()
	_setup_hud()
	_update_hud()

func _ensure_toggle_threats_action() -> void:
	var action := "ui_toggle_threats"
	if not InputMap.has_action(action):
			InputMap.add_action(action)
	var has_event := false
	for existing_event in InputMap.action_get_events(action):
			if existing_event is InputEventKey and existing_event.physical_keycode == Key.KEY_T:
					has_event = true
					break
	if not has_event:
			var event := InputEventKey.new()
			event.physical_keycode = Key.KEY_T
			event.keycode = Key.KEY_T
			InputMap.action_add_event(action, event)

func _ensure_toggle_sprout_register_action() -> void:
	var action := "ui_toggle_sprout_register"
	if not InputMap.has_action(action):
			InputMap.add_action(action)
	var has_event := false
	for existing_event in InputMap.action_get_events(action):
			if existing_event is InputEventKey and existing_event.physical_keycode == Key.KEY_TAB:
					has_event = true
					break
	if not has_event:
			var event := InputEventKey.new()
			event.physical_keycode = Key.KEY_TAB
			event.keycode = Key.KEY_TAB
			InputMap.action_add_event(action, event)

func _ensure_sprout_picker() -> void:
        if is_instance_valid(_sprout_picker):
                        return
        if SPROUT_REGISTER_SCENE == null:
                        return
	var picker_instance := SPROUT_REGISTER_SCENE.instantiate()
	if picker_instance == null:
			return
	var picker := picker_instance as BattlePicker
	if picker == null:
			picker_instance.queue_free()
			return
	var parent: Node = get_tree().current_scene
	if parent == null:
			parent = get_tree().root
        parent.add_child(picker)
        _sprout_picker = picker

func _ensure_tile_choice_window() -> void:
        if is_instance_valid(_tile_choice_window):
                return
        if TILE_CHOICE_WINDOW_SCENE == null:
                return
        var instance := TILE_CHOICE_WINDOW_SCENE.instantiate()
        if instance == null:
                return
        add_child(instance)
        _tile_choice_window = instance as TileChoiceWindow

func _toggle_sprout_register() -> void:
	_ensure_sprout_picker()
	if not is_instance_valid(_sprout_picker):
			return
	if _sprout_picker.visible:
			_sprout_picker.close()
	else:
			_sprout_picker.open()

func set_width(value: int) -> void:
	width = max(1, value)
	if _is_ready:
		draw_debug_grid()

func set_height(value: int) -> void:
	height = max(1, value)
	if _is_ready:
		draw_debug_grid()

func set_tile_px(value: int) -> void:
	tile_px = max(1, value)
	if _is_ready:
		_ensure_hex_config()
		_build_tileset()
		draw_debug_grid()

func _ensure_hex_config() -> void:
	if hexmap == null:
		return
	var ts: TileSet = hexmap.tile_set
	if ts != null:
		ts.tile_shape = TileSet.TILE_SHAPE_HEXAGON
		ts.tile_layout = TileSet.TILE_LAYOUT_STACKED
		ts.tile_offset_axis = TileSet.TILE_OFFSET_AXIS_VERTICAL
		var cell_size := _calculate_hex_cell_size(tile_px)
		ts.tile_size = Vector2i(tile_px, cell_size.y)
	hexmap.y_sort_enabled = false

func _ensure_layers() -> void:
	while hexmap.get_layers_count() <= LAYER_FX:
		hexmap.add_layer(hexmap.get_layers_count())
	hexmap.set_layer_name(LAYER_GROUND, "ground")
	hexmap.set_layer_name(LAYER_OBJECTS, "objects")
	hexmap.set_layer_name(LAYER_LIFE, "life")
	hexmap.set_layer_name(LAYER_FX, "fx")
	hexmap.set_layer_z_index(LAYER_GROUND, 0)
	hexmap.set_layer_z_index(LAYER_OBJECTS, 1)
	hexmap.set_layer_z_index(LAYER_LIFE, 2)
	hexmap.set_layer_z_index(LAYER_FX, 10)

func _build_tileset() -> void:
	if hexmap == null:
		return
	var names_to_colors: Dictionary = {
		"empty": Color(0, 0, 0, 0),
		"totem": Color(0.2, 0.85, 0.4, 1),
		"decay": Color(0.6, 0.2, 0.8, 1),
		"harvest": Color(0.15, 0.5, 0.2, 1),
		"build": Color(0.5, 0.35, 0.2, 1),
		"refine": Color(0.2, 0.4, 0.9, 1),
		"storage": Color(0.55, 0.55, 0.55, 1),
		"guard": Color(0.85, 0.75, 0.2, 1),
		"upgrade": Color(0.1, 0.7, 0.7, 1),
		"chanting": Color(0.8, 0.2, 0.6, 1),
		"overgrowth": Color(0.35, 0.7, 0.35, 0.75),
		"grove": Color(0.10, 0.55, 0.25, 1.0),
		"fx_nature": Color(0.20, 0.85, 0.40, 0.40),
		"fx_earth": Color(0.60, 0.45, 0.25, 0.40),
		"fx_water": Color(0.20, 0.45, 0.95, 0.40),
		"fx_seed": Color(0.95, 0.80, 0.20, 0.45),
		"fx_threat": Color(0.90, 0.20, 0.20, 0.35),
	}
	tiles_name_to_id = TileSetBuilder.build_named_hex_tiles(hexmap, names_to_colors, tile_px)
	var id_meta: Variant = hexmap.get_meta("tiles_id_to_name") if hexmap.has_meta("tiles_id_to_name") else {}
	tiles_id_to_name = id_meta if id_meta is Dictionary else {}
	_ensure_hex_config()

func set_fx(cell: Vector2i, fx_name: String) -> void:
	if hexmap == null:
		return
	if tiles_name_to_id.is_empty():
		_build_tileset()
	if not tiles_name_to_id.has(fx_name):
		return
	var tile_info_variant: Variant = tiles_name_to_id[fx_name]
	if not (tile_info_variant is Dictionary):
		return
	var tile_info: Dictionary = tile_info_variant
	var src_id: int = int(tile_info.get("source_id", -1))
	var atlas_value: Variant = tile_info.get("atlas_coords", Vector2i.ZERO)
	var atlas_coords: Vector2i = atlas_value if atlas_value is Vector2i else Vector2i.ZERO
	if src_id < 0:
		return
	hexmap.set_cell(LAYER_FX, cell, src_id, atlas_coords)

func clear_fx(cell: Vector2i) -> void:
	if hexmap == null:
		return
	hexmap.erase_cell(LAYER_FX, cell)

func clear_all_fx() -> void:
	if hexmap == null:
		return
	hexmap.clear_layer(LAYER_FX)

func flash_fx(cells_by_fx: Dictionary, duration_sec: float = 0.35) -> void:
	for fx_name in cells_by_fx.keys():
		var cells_variant: Variant = cells_by_fx[fx_name]
		if cells_variant is Array:
			for c in cells_variant:
				if c is Vector2i:
					set_fx(c, fx_name)
	await get_tree().create_timer(duration_sec).timeout
	for fx_name in cells_by_fx.keys():
		var cells_variant: Variant = cells_by_fx[fx_name]
		if cells_variant is Array:
			for c in cells_variant:
				if c is Vector2i:
					clear_fx(c)

func clear_tiles() -> void:
	if hexmap == null:
		return
	for layer in range(hexmap.get_layers_count()):
		var used_cells: Array = hexmap.get_used_cells(layer)
		for cell in used_cells:
			hexmap.erase_cell(layer, cell)
			_clear_cell_meta(layer, cell)
	_cell_metadata.clear()
	rules.occupied.clear()
	turn = 0
	origin_cell = Vector2i.ZERO

func set_origin_cell(c: Vector2i) -> void:
	origin_cell = clamp_cell(c)
	rules.set_origin(origin_cell)
	if is_instance_valid(cursor):
		cursor.move_to(origin_cell)
	_update_hud()

func clamp_cell(c: Vector2i) -> Vector2i:
	return HexUtil.clamp_cell(c, width, height)

func neighbors_even_q(c: Vector2i) -> Array[Vector2i]:
	return HexUtil.neighbors_even_q(c, width, height)

func cell_to_world(c: Vector2i) -> Vector2:
	if hexmap == null:
		return Vector2.ZERO
	return hexmap.map_to_local(c)

func world_pos_of_cell(c: Vector2i) -> Vector2:
	return cell_to_world(c)

func world_to_cell(p: Vector2) -> Vector2i:
	if hexmap == null:
		return Vector2i.ZERO
	return hexmap.local_to_map(p)

func set_cell_named(layer: int, c: Vector2i, tile_name: String) -> void:
	if hexmap == null:
		return
	if tiles_name_to_id.is_empty():
		_build_tileset()
	if not tiles_name_to_id.has(tile_name):
		return
	var tile_info: Dictionary = tiles_name_to_id[tile_name]
	var src_id: int = int(tile_info.get("source_id", -1))
	var atlas_value: Variant = tile_info.get("atlas_coords", Vector2i.ZERO)
	var atlas_coords: Vector2i = atlas_value if atlas_value is Vector2i else Vector2i.ZERO
	if src_id < 0:
		return
	hexmap.set_cell(layer, c, src_id, atlas_coords)
	if layer == LAYER_LIFE:
		clear_cell_tile_id(layer, c)

func set_cell_meta(layer: int, c: Vector2i, key: String, value) -> void:
	if hexmap == null:
		return
	var layer_meta: Dictionary = _cell_metadata.get(layer, {})
	if not _cell_metadata.has(layer) or not (layer_meta is Dictionary):
		layer_meta = {}
		_cell_metadata[layer] = layer_meta
	var cell_meta: Dictionary = {}
	if layer_meta.has(c):
		var meta_variant: Variant = layer_meta[c]
		if meta_variant is Dictionary:
			cell_meta = meta_variant
	if value == null:
		if not cell_meta.is_empty():
			cell_meta.erase(key)
		if cell_meta.is_empty():
			layer_meta.erase(c)
			if layer_meta.is_empty():
				_cell_metadata.erase(layer)
			return
	else:
		if cell_meta.is_empty():
			cell_meta = {}
		cell_meta[key] = value
	if not cell_meta.is_empty():
		layer_meta[c] = cell_meta

func get_cell_meta(layer: int, c: Vector2i, key: String):
	if hexmap == null:
		return null
	var layer_meta_variant: Variant = _cell_metadata.get(layer, null)
	if not (layer_meta_variant is Dictionary):
		return null
	var layer_meta: Dictionary = layer_meta_variant
	if not layer_meta.has(c):
		return null
	var cell_meta_variant: Variant = layer_meta[c]
	if not (cell_meta_variant is Dictionary):
		return null
	var cell_meta: Dictionary = cell_meta_variant
	return cell_meta.get(key, null)

func set_cell_tile_id(layer: int, c: Vector2i, id: String) -> void:
	set_cell_meta(layer, c, "id", id)

func get_cell_tile_id(layer: int, c: Vector2i) -> String:
	if hexmap == null:
		return ""
	var value = get_cell_meta(layer, c, "id")
	return value if typeof(value) == TYPE_STRING else ""

func id_to_category(id: String) -> String:
	if id.is_empty():
		return ""
	return String(DeckManager.id_to_category.get(id, ""))

func id_to_name(id: String) -> String:
	if id.is_empty():
		return ""
	return String(DeckManager.id_to_name.get(id, id))

func get_cell_name(layer: int, c: Vector2i) -> String:
	if hexmap == null:
		return ""
	if hexmap.get_cell_tile_data(layer, c) == null:
		return ""
	var source_id: int = hexmap.get_cell_source_id(layer, c)
	if source_id < 0:
		return ""
	var atlas_coords: Vector2i = hexmap.get_cell_atlas_coords(layer, c)
	var key := TileSetBuilder.encode_tile_key(source_id, atlas_coords)
	return String(tiles_id_to_name.get(key, ""))

func clear_cell_tile_id(layer: int, c: Vector2i) -> void:
	if hexmap == null:
		return
	set_cell_meta(layer, c, "id", null)

func is_empty(layer: int, c: Vector2i) -> bool:
	if hexmap == null:
		return true
	return hexmap.get_cell_tile_data(layer, c) == null

func _clear_cell_meta(layer: int, c: Vector2i) -> void:
	if not _cell_metadata.has(layer):
		return
	var layer_meta_variant: Variant = _cell_metadata[layer]
	if not (layer_meta_variant is Dictionary):
		return
	var layer_meta: Dictionary = layer_meta_variant
	if not layer_meta.has(c):
		return
	layer_meta.erase(c)
	if layer_meta.is_empty():
		_cell_metadata.erase(layer)

func draw_debug_grid() -> void:
	var existing: Node = get_node_or_null("DebugGrid")
	if existing:
		existing.queue_free()
	var grid: Node2D = Node2D.new()
	grid.name = "DebugGrid"
	grid.z_index = -10
	add_child(grid)

	for x in range(width):
		for y in range(height):
			var marker: ColorRect = ColorRect.new()
			marker.color = Color(1, 1, 1, 0.08)
			marker.size = Vector2(6, 6)
			marker.pivot_offset = marker.size * 0.5
			marker.position = cell_to_world(Vector2i(x, y))
			marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
			marker.z_index = -10
			grid.add_child(marker)

func can_place_at(cell: Vector2i) -> bool:
        if not _placing_special.is_empty():
                return rules.can_place(self, cell)
        if DeckManager.peek().is_empty():
                return false
        return rules.can_place(self, cell)

func attempt_place_at(cell: Vector2i) -> void:
        if not can_place_at(cell):
                return
        place_current_tile(cell)

func place_current_tile(cell: Vector2i) -> void:
        if not _placing_special.is_empty():
                if not rules.can_place(self, cell):
                        return
                var special_id := _placing_special
                if special_id.is_empty():
                        return
                if _place_tile(cell, special_id, false):
                        _placing_special = ""
                        _dequeue_next_special()
                return

        if DeckManager.next_tile_id.is_empty():
                return
        if not rules.can_place(self, cell):
                return
        var tile_id: String = DeckManager.next_tile_id
        if tile_id.is_empty():
                return
        _place_tile(cell, tile_id, true)

func _place_tile(cell: Vector2i, tile_id: String, draw_from_deck: bool) -> bool:
        var category: String = id_to_category(tile_id)
        if category.is_empty():
                return false
        set_cell_named(LAYER_LIFE, cell, category)
        set_cell_tile_id(LAYER_LIFE, cell, tile_id)
        rules.mark_occupied(cell)
        _finalize_tile_placement(draw_from_deck)
        return true

func _finalize_tile_placement(draw_from_deck: bool) -> void:
        turn += 1
        if draw_from_deck:
                DeckManager.draw_one()
                update_hud(DeckManager.peek_name(), DeckManager.remaining())
        else:
                _update_hud()
        if is_instance_valid(cursor):
                cursor.update_highlight_state()
        var growth_manager: Node = get_node_or_null("/root/GrowthManager")
        if growth_manager != null and growth_manager.has_method("request_growth_update"):
                growth_manager.request_growth_update(turn)
        var resource_manager: Node = _get_resource_manager()
        if resource_manager != null:
                resource_manager.emit_signal("resources_changed")
        _advance_turn()

func _on_special_now(tile_id: String) -> void:
        _special_queue.append(String(tile_id))
        if _placing_special.is_empty():
                _dequeue_next_special()

func _dequeue_next_special() -> void:
        if _special_queue.is_empty():
                _placing_special = ""
                _update_hud()
                if is_instance_valid(cursor):
                        cursor.update_highlight_state()
                return
        var next_id_variant = _special_queue.pop_front()
        _placing_special = String(next_id_variant)
        _update_hud()
        if is_instance_valid(cursor):
                cursor.update_highlight_state()

func _advance_turn() -> void:
        var turn_engine: Node = _get_turn_engine()
        if turn_engine != null:
                turn_engine.call("advance_one_turn")
                return
        var game_singleton: Object = null
        if Engine.has_singleton("Game"):
                game_singleton = Engine.get_singleton("Game")
        if game_singleton != null and game_singleton.has_method("advance_one_turn"):
                game_singleton.call("advance_one_turn")

func _on_totem_tier_changed(_tier_value: int) -> void:
        _update_hud()

func world_to_map(p: Vector2) -> Vector2i:
	return world_to_cell(p)

func _setup_hud() -> void:
		if is_instance_valid(hud):
				hud.text = _build_hud_text("-", 0)
		_update_resource_panel()

func _bind_sprout_registry() -> void:
                var sprout_registry: Node = get_node_or_null("/root/SproutRegistry")
                if sprout_registry == null:
                                return
                if not sprout_registry.is_connected("error_msg", Callable(self, "_on_sprout_error")):
                                sprout_registry.connect("error_msg", Callable(self, "_on_sprout_error"))
                if not sprout_registry.is_connected("sprout_leveled", Callable(self, "_on_sprout_leveled")):
                                sprout_registry.connect("sprout_leveled", Callable(self, "_on_sprout_leveled"))

func _bind_tile_gen() -> void:
        if TileGen == null:
                return
        TileGen.bind_world(self)
        if not TileGen.is_connected("special_to_place_now", Callable(self, "_on_special_now")):
                TileGen.connect("special_to_place_now", Callable(self, "_on_special_now"))
        if not TileGen.is_connected("totem_tier_changed", Callable(self, "_on_totem_tier_changed")):
                TileGen.connect("totem_tier_changed", Callable(self, "_on_totem_tier_changed"))
        _ensure_tile_choice_window()

func _on_sprout_error(text: String) -> void:
		if has_node("HUD/DeckLabel"):
				var label: Label = $HUD/DeckLabel
				label.text += "\n[SPR] " + text

func _on_sprout_leveled(uid: String, lvl: int) -> void:
		if has_node("HUD/DeckLabel"):
				var label: Label = $HUD/DeckLabel
				label.text += "\n[SPR] " + uid + " → Lv" + str(lvl)

func _unhandled_input(event: InputEvent) -> void:
		if event.is_action_pressed("ui_toggle_sprout_register"):
			_toggle_sprout_register()
			var sr_viewport := get_viewport()
			if sr_viewport != null:
				sr_viewport.set_input_as_handled()
			return
		if event.is_action_pressed("ui_toggle_threats"):
			var threat_list: Control = get_node_or_null("ThreatHUD/ThreatList")
			if threat_list != null:
				threat_list.visible = not threat_list.visible
				var threat_viewport := get_viewport()
				if threat_viewport != null:
					threat_viewport.set_input_as_handled()

func update_hud(next_name: String, remaining: int) -> void:
	if is_instance_valid(hud):
		hud.text = _build_hud_text(next_name, remaining)
	_update_resource_panel()

func _update_hud() -> void:
        if not is_instance_valid(hud):
                return
        var tile_id: String = DeckManager.peek()
        var remaining: int = DeckManager.remaining()
	var display_name: String = "-"
	if not tile_id.is_empty():
		var tile_name: String = DeckManager.peek_name()
		var category: String = DeckManager.peek_category()
		if category.is_empty():
			display_name = tile_name
		else:
			display_name = "%s (%s)" % [tile_name, category]
        hud.text = _build_hud_text(display_name, remaining)
        _update_resource_panel()

func _build_hud_text(next_name: String, remaining: int) -> String:
        var lines: Array[String] = []
        lines.append("Next: %s | Deck: %d" % [next_name, remaining])
        var totem_line := _totem_status_line()
        if not totem_line.is_empty():
                lines.append(totem_line)
        if not _placing_special.is_empty():
                var display_name := id_to_name(_placing_special)
                if display_name.is_empty():
                        display_name = _placing_special
                lines.append("Place SPECIAL: %s" % display_name)
        lines.append("Overgrowth: %d | Groves: %d" % [_count_cells_named("overgrowth"), _count_cells_named("grove")])
        var resource_manager: Node = _get_resource_manager()
        if resource_manager != null:
                var soul_variant = resource_manager.get("soul_seeds")
                lines.append("Soul Seeds: %d" % [int(soul_variant)])
        return "\n".join(lines)

func _totem_status_line() -> String:
        if TileGen == null:
                return ""
        var parts: Array[String] = []
        parts.append("Totem Tier: %d" % TileGen.get_tier())
        var next_turn := TileGen.get_next_choice_turn()
        if next_turn > 0:
                parts.append("Next Pack Turn: %d" % next_turn)
        return " | ".join(parts)

func _update_resource_panel() -> void:
	if not is_instance_valid(resources_panel):
		return
	var resource_manager: Node = _get_resource_manager()
	var has_manager := resource_manager != null
	resources_panel.visible = true
	var display_names := {
		"nature": "Nature",
		"earth": "Earth",
		"water": "Water",
		"life": "Life",
	}
	if not has_manager:
		for key in resource_labels.keys():
			var label: Label = resource_labels[key]
			if label != null:
				var display_name: String = display_names.get(key, String(key).capitalize())
				label.text = "%s: -" % display_name
		if is_instance_valid(soul_seeds_label):
			soul_seeds_label.text = "Soul Seeds: -"
		return
	var nature_label: Label = resource_labels.get("nature")
	if nature_label != null:
		nature_label.text = "%s: %d/%d" % [
			display_names.get("nature", "Nature"),
			resource_manager.get_amount("nature"),
			resource_manager.get_capacity("nature"),
		]
	var earth_label: Label = resource_labels.get("earth")
	if earth_label != null:
		earth_label.text = "%s: %d/%d" % [
			display_names.get("earth", "Earth"),
			resource_manager.get_amount("earth"),
			resource_manager.get_capacity("earth"),
		]
	var water_label: Label = resource_labels.get("water")
	if water_label != null:
		water_label.text = "%s: %d/%d" % [
			display_names.get("water", "Water"),
			resource_manager.get_amount("water"),
			resource_manager.get_capacity("water"),
		]
	var life_label: Label = resource_labels.get("life")
	if life_label != null:
		life_label.text = "%s: %d" % [
			display_names.get("life", "Life"),
			resource_manager.get_amount("life"),
		]
	if is_instance_valid(soul_seeds_label):
		soul_seeds_label.text = "Soul Seeds: %d" % [resource_manager.soul_seeds]

func _bind_resource_manager() -> void:
	var resource_manager: Node = _get_resource_manager()
	if resource_manager == null:
		return
	resource_manager.bind_world(self)
	if not resource_manager.is_connected("resources_changed", Callable(self, "_on_resources_changed")):
		resource_manager.connect("resources_changed", Callable(self, "_on_resources_changed"))
	if not resource_manager.is_connected("item_changed", Callable(self, "_on_item_changed")):
		resource_manager.connect("item_changed", Callable(self, "_on_item_changed"))
	if not resource_manager.is_connected("produced_cells", Callable(self, "_on_produced_cells")):
		resource_manager.connect("produced_cells", Callable(self, "_on_produced_cells"))
	_on_resources_changed()

func _on_resources_changed() -> void:
	_update_hud()

func _on_item_changed(_item: String) -> void:
	_update_hud()

func _on_produced_cells(cells_by_fx: Dictionary) -> void:
	if cells_by_fx.is_empty():
		return
	flash_fx(cells_by_fx, 0.35)

func _count_cells_named(tile_name: String) -> int:
	var total := 0
	for y in range(height):
		for x in range(width):
			if get_cell_name(LAYER_LIFE, Vector2i(x, y)) == tile_name:
				total += 1
	return total
