extends Node
## Coordinates deck management, turn resolution, and resource tracking for a run.

const CellType := preload("res://scripts/core/CellType.gd")
const HexGrid := preload("res://scripts/grid/HexGrid.gd")
const PaletteState := preload("res://scripts/input/PaletteState.gd")
const BuildPalette := preload("res://scripts/ui/BuildPalette.gd")
const RunInfoPanel := preload("res://scripts/ui/RunInfoPanel.gd")

@export var hex_grid_path: NodePath
@export var palette_state_path: NodePath
@export var build_palette_path: NodePath
@export var info_panel_path: NodePath

var _hex_grid: HexGrid
var _palette_state: PaletteState
var _build_palette: BuildPalette
var _info_panel: RunInfoPanel

var _tile_definitions: Dictionary = {}
var _deck_counts: Dictionary = {}
var _deck_queue: Array[int] = []
var _turn: int = 0
var _resources := {
	"nature": {"current": 0, "capacity": 0},
	"earth": {"current": 0, "capacity": 0},
	"water": {"current": 0, "capacity": 0},
	"life": {"current": 0, "capacity": 0}
}
var _resource_generation := {
	"nature": 0,
	"earth": 0,
	"water": 0,
	"life": 0
}

func _ready() -> void:
	if hex_grid_path.is_empty():
		hex_grid_path = NodePath("../HexGrid")
	if palette_state_path.is_empty():
		palette_state_path = NodePath("../PaletteState")
	if build_palette_path.is_empty():
		build_palette_path = NodePath("../BuildPalette")
	if info_panel_path.is_empty():
		info_panel_path = NodePath("../RunInfoPanel")

	_hex_grid = get_node_or_null(hex_grid_path)
	_palette_state = get_node_or_null(palette_state_path)
	_build_palette = get_node_or_null(build_palette_path)
	_info_panel = get_node_or_null(info_panel_path)

	if not _hex_grid:
		push_warning("RunState requires a HexGrid node")
		return

	_tile_definitions = _load_tile_definitions()
	_build_initial_deck()
	_reset_resources()
        _apply_tile_descriptions()
        _refresh_palette_options()
        _update_info_panel()
        _update_buildable_highlights()

func try_place_tile(axial: Vector2i, cell_type: int = CellType.Type.EMPTY) -> bool:
		if is_deck_empty():
				return false
		var next_type := peek_next_tile_type()
		if next_type == CellType.Type.EMPTY:
				return false
		var type_to_place := next_type
		if cell_type != CellType.Type.EMPTY and cell_type != next_type:
				push_warning("Attempted to place %s but the next tile is %s." % [CellType.to_display_name(cell_type), CellType.to_display_name(next_type)])
				return false
		var remaining: int = int(_deck_counts.get(type_to_place, 0))
		if remaining <= 0:
				push_warning("No %s tiles remain in the deck." % CellType.to_display_name(type_to_place))
				return false
		var variant_id := _get_variant_id(type_to_place)
		var placed := _hex_grid.try_place_tile(axial, type_to_place, variant_id)
		if not placed:
				return false
		_deck_counts[type_to_place] = remaining - 1
		if not _deck_queue.is_empty():
				_deck_queue.remove_at(0)
		_turn += 1
		_hex_grid.process_turn()
		_recalculate_resources()
                _refresh_palette_options()
                _update_info_panel()
                _update_buildable_highlights()
                return true

func is_deck_empty() -> bool:
		return _deck_queue.is_empty()

func peek_next_tile_type() -> int:
		if _deck_queue.is_empty():
				return CellType.Type.EMPTY
		return _deck_queue[0]

func toggle_info_panel() -> void:
	if not _info_panel:
		return
	_info_panel.visible = not _info_panel.visible

func _load_tile_definitions() -> Dictionary:
	var path := "res://data/tiles.json"
	if not FileAccess.file_exists(path):
		push_warning("tiles.json missing; using fallback definitions")
		return _default_tile_definitions()
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_warning("Unable to open tiles.json; using fallback definitions")
		return _default_tile_definitions()
	var text := file.get_as_text()
	var json := JSON.new()
	var error := json.parse(text)
	if error != OK:
		push_warning("Failed to parse tiles.json; using fallback definitions")
		return _default_tile_definitions()
	if typeof(json.data) != TYPE_DICTIONARY:
		push_warning("tiles.json has unexpected structure; using fallback definitions")
		return _default_tile_definitions()
	return json.data

func _default_tile_definitions() -> Dictionary:
	return {
		"Harvest": {
			"id": "harvest_default",
			"summary": "Generates Nature Essence per adjacent Grove; expands Nature capacity."
		},
		"Build": {
			"id": "build_default",
			"summary": "Produces Earth Essence for the network."
		},
		"Refine": {
			"id": "refine_default",
			"summary": "Condenses Nature and Earth Essence into Water Essence when linked."
		},
		"Storage": {
			"id": "storage_default",
			"summary": "Expands capacity of nearby producers."
		},
		"Guard": {
			"id": "guard_default",
			"summary": "Hosts Sprouts that defend the forest."
		},
		"Upgrade": {
			"id": "upgrade_default",
			"summary": "Creates combat items over time."
		},
		"Chanting": {
			"id": "chanting_default",
			"summary": "Builds rituals that unleash powerful spells."
		}
	}

func _build_initial_deck() -> void:
		_deck_counts.clear()
		_deck_queue.clear()
		var distribution := _load_deck_distribution()
		for key in distribution.keys():
				var cell_type := CellType.from_key(key)
				if not CellType.is_placeable(cell_type):
						continue
				var count := int(distribution[key])
				if count <= 0:
						continue
				_deck_counts[cell_type] = count
				for i in range(count):
						_deck_queue.append(cell_type)
		if not _deck_queue.is_empty():
				_deck_queue.shuffle()

func _load_deck_distribution() -> Dictionary:
	var path := "res://data/deck.json"
	if not FileAccess.file_exists(path):
		push_warning("deck.json missing; using fallback distribution")
		return _default_deck_distribution()
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_warning("Unable to open deck.json; using fallback distribution")
		return _default_deck_distribution()
	var text := file.get_as_text()
	var json := JSON.new()
	var error := json.parse(text)
	if error != OK:
		push_warning("Failed to parse deck.json; using fallback distribution")
		return _default_deck_distribution()
	if typeof(json.data) != TYPE_DICTIONARY:
		push_warning("deck.json has unexpected structure; using fallback distribution")
		return _default_deck_distribution()
	var data: Dictionary = json.data
	var distribution_variant: Variant = data.get("default_distribution", {})
	if typeof(distribution_variant) != TYPE_DICTIONARY or (distribution_variant as Dictionary).is_empty():
		distribution_variant = data.get("distribution", {})
	if typeof(distribution_variant) != TYPE_DICTIONARY:
		push_warning("deck.json distribution must be a dictionary; using fallback distribution")
		return _default_deck_distribution()
	var distribution: Dictionary = distribution_variant
	if distribution.is_empty():
		push_warning("deck.json missing deck distribution; using fallback distribution")
		return _default_deck_distribution()
	return distribution

func _default_deck_distribution() -> Dictionary:
	return {
		"Harvest": 8,
		"Build": 6,
		"Refine": 4,
		"Guard": 4,
		"Storage": 3,
		"Upgrade": 3,
		"Chanting": 1
	}

func _reset_resources() -> void:
	for key in _resources.keys():
		_resources[key]["current"] = 0
		_resources[key]["capacity"] = 0
	_resource_generation = {
		"nature": 0,
		"earth": 0,
		"water": 0,
		"life": 0
	}

func _apply_tile_descriptions() -> void:
	if not _build_palette:
		return
	var descriptions: Dictionary = {}
	for key in _tile_definitions.keys():
		var cell_type := CellType.from_key(key)
		if not CellType.is_placeable(cell_type):
			continue
		var entry: Dictionary = _tile_definitions[key]
		var summary := String(entry.get("summary", ""))
		var details: Variant = entry.get("details", [])
		if typeof(details) == TYPE_ARRAY and not details.is_empty():
			summary += "\n" + "\n".join(details)
		descriptions[cell_type] = summary.strip_edges()
	_build_palette.set_tile_descriptions(descriptions)

func _refresh_palette_options() -> void:
	if not _palette_state:
		return
	var available: Array[int] = []
	var counts: Dictionary = {}
	for cell_type in CellType.buildable_types():
		var count := int(_deck_counts.get(cell_type, 0))
		counts[cell_type] = count
		if count > 0:
			available.append(cell_type)
	_palette_state.set_options(available, counts)

func _update_info_panel() -> void:
                if _info_panel:
                                _info_panel.update_turn(_turn)
                                _info_panel.update_deck(_get_total_deck_count(), _deck_counts)
                                _info_panel.update_resources(_resources, _resource_generation)
                                _info_panel.update_sprouts(_hex_grid.get_total_sprouts())
                                _info_panel.update_next_tile(peek_next_tile_type())

func _update_buildable_highlights() -> void:
        if not _hex_grid:
                return
        _hex_grid.update_buildable_highlights(peek_next_tile_type())

func _get_variant_id(cell_type: int) -> String:
	var key := CellType.to_key(cell_type)
	var entry: Dictionary = _tile_definitions.get(key, {})
	if entry.has("id"):
		return String(entry.get("id"))
	return ""

func _get_total_deck_count() -> int:
	var total := 0
	for value in _deck_counts.values():
		total += int(value)
	return total

func _recalculate_resources() -> void:
	var capacity := {
		"nature": 0,
		"earth": 0,
		"water": 0,
		"life": max(_resources["life"]["current"], _resources["life"]["capacity"])
	}
	var generation := {
		"nature": 0,
		"earth": 0,
		"water": 0,
		"life": 0
	}

	var harvest_cells := _hex_grid.get_cells_of_type(CellType.Type.HARVEST)
	for axial in harvest_cells:
		capacity["nature"] += 5
		var adjacent_groves := _hex_grid.count_neighbors_of_type(axial, CellType.Type.GROVE)
		generation["nature"] += adjacent_groves
	var harvest_clusters := _hex_grid.collect_clusters(CellType.Type.HARVEST)
	for cluster in harvest_clusters:
		capacity["nature"] += cluster.size() * 10
	generation["nature"] += _hex_grid.get_cells_of_type(CellType.Type.GROVE).size()

	var build_cells := _hex_grid.get_cells_of_type(CellType.Type.BUILD)
	for axial in build_cells:
		capacity["earth"] += 5
		generation["earth"] += 1

	var refine_cells := _hex_grid.get_cells_of_type(CellType.Type.REFINE)
	var refine_clusters := _hex_grid.collect_clusters(CellType.Type.REFINE)
	var refine_multiplier: Dictionary = {}
	for cluster in refine_clusters:
		var mult := 1
		if cluster.size() > 1:
			mult = 2
		for axial in cluster:
			refine_multiplier[axial] = mult
	for axial in refine_cells:
		capacity["water"] += 5
		var has_nature := _hex_grid.count_neighbors_of_type(axial, CellType.Type.HARVEST) > 0 or _hex_grid.count_neighbors_of_type(axial, CellType.Type.GROVE) > 0
		var has_earth := _hex_grid.count_neighbors_of_type(axial, CellType.Type.BUILD) > 0
		if has_nature and has_earth:
			var mult := int(refine_multiplier.get(axial, 1))
			generation["water"] += mult

	var storage_cells := _hex_grid.get_cells_of_type(CellType.Type.STORAGE)
	for axial in storage_cells:
		for neighbor in _hex_grid.get_neighbors(axial):
			var neighbor_type := _hex_grid.get_cell_type_at(neighbor)
			match neighbor_type:
				CellType.Type.HARVEST:
					capacity["nature"] += 5
				CellType.Type.BUILD:
					capacity["earth"] += 5
				CellType.Type.REFINE:
					capacity["water"] += 5
				_:
					pass

	var guard_cells := _hex_grid.get_cells_of_type(CellType.Type.GUARD)
	for axial in guard_cells:
		var data := _hex_grid.get_cell_data(axial)
		if data:
			data.sprout_capacity = 5

	for key in _resources.keys():
		var cap := int(capacity.get(key, 0))
		_resources[key]["capacity"] = cap
		if cap > 0 and key != "life":
			_resources[key]["current"] = clamp(_resources[key]["current"], 0, cap)

	_resource_generation = generation
	for key in generation.keys():
		if not _resources.has(key):
			continue
		var cap := int(_resources[key]["capacity"])
		var current_amount: int = int(_resources[key]["current"])
		var new_total: int = current_amount + int(generation[key])
		if cap > 0 and key != "life":
			new_total = min(new_total, cap)
		_resources[key]["current"] = new_total
