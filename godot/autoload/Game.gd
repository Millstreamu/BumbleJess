## Coordinates turns and relays placement events to the effects engine.
extends Node
class_name Game

var _turn_index: int = 1
var _tile_manager: TileManager = null

func _ready() -> void:
	_turn_index = max(1, _turn_index)
	_tile_manager = _locate_tile_manager()
	_connect_tile_manager()

func get_turn_index() -> int:
	return _turn_index

func set_turn_index(value: int) -> void:
	_turn_index = max(1, value)

func start_turn() -> void:
	_invoke_effects("start_of_turn")

func end_turn() -> void:
	_invoke_effects("end_of_turn")
	_turn_index += 1

func notify_commune_resolved() -> void:
	_invoke_effects("start_of_turn")

func notify_tile_placed() -> void:
	_invoke_effects("on_place")

func notify_tile_transformed() -> void:
	_invoke_effects("on_transform")

func notify_adjacency_changed() -> void:
	_invoke_effects("on_adjacency_change")

func _connect_tile_manager() -> void:
	if _tile_manager == null:
		return
	if not _tile_manager.is_connected("tile_placed", Callable(self, "_on_tile_placed")):
		_tile_manager.connect("tile_placed", Callable(self, "_on_tile_placed"))
	if not _tile_manager.is_connected("tile_transformed", Callable(self, "_on_tile_transformed")):
		_tile_manager.connect("tile_transformed", Callable(self, "_on_tile_transformed"))
	if not _tile_manager.is_connected("adjacency_changed", Callable(self, "_on_adjacency_changed")):
		_tile_manager.connect("adjacency_changed", Callable(self, "_on_adjacency_changed"))

func _on_tile_placed(_tile: TileManager.TileRef) -> void:
	_invoke_effects("on_place")

func _on_tile_transformed(_tile: TileManager.TileRef, _previous_id: String) -> void:
	_invoke_effects("on_transform")

func _on_adjacency_changed(_changed_positions) -> void:
	_invoke_effects("on_adjacency_change")

func _invoke_effects(when: String) -> void:
	if typeof(EffectsEngine) != TYPE_NIL:
		EffectsEngine.apply_when(when)

func _locate_tile_manager() -> TileManager:
	if typeof(TileManager) != TYPE_NIL and TileManager is TileManager:
		return TileManager
	var node := get_tree().root.get_node_or_null("TileManager")
	if node is TileManager:
		return node
	return null
