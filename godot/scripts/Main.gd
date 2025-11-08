extends Control

const PRE_RUN_SETUP_SCENE_PATH := "res://scenes/ui/PreRunSetup.tscn"

var _pre_run_setup_scene: PackedScene = null
var _setup_ui: PreRunSetup = null

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)

	var map_id: String = str(ProjectSettings.get_setting("application/config/starting_map_id", "map.demo_001"))
	if RunConfig.has_method("set_map"):
		RunConfig.set_map(map_id)
	else:
		RunConfig.map_id = map_id

	_pre_run_setup_scene = _load_scene(PRE_RUN_SETUP_SCENE_PATH)

	_prepare_new_game(map_id)
	MapSeeder.load_map(map_id, $World)
	_ensure_pre_run_setup()
	_begin_new_run_flow()

func _prepare_new_game(map_id: String) -> void:
	if SproutRegistry != null and SproutRegistry.has_method("refresh_for_new_game"):
		SproutRegistry.refresh_for_new_game(map_id)

func _begin_new_run_flow() -> void:
		if typeof(TurnEngine) != TYPE_NIL and TurnEngine.has_method("reset_for_setup"):
				TurnEngine.reset_for_setup(1)
		else:
				var turn_engine_node := get_tree().root.get_node_or_null("TurnEngine")
				if turn_engine_node != null and turn_engine_node.has_method("reset_for_setup"):
						turn_engine_node.call("reset_for_setup", 1)
		RunConfig.clear_for_new_run()
		if _setup_ui != null:
				_setup_ui.open()

func _ensure_pre_run_setup() -> void:
	if is_instance_valid(_setup_ui):
		return

	if _pre_run_setup_scene == null:
		return

	var instance: Node = _pre_run_setup_scene.instantiate()
	if instance == null:
		return

	add_child(instance)

	var setup := instance as PreRunSetup
	if setup == null:
		instance.queue_free()
		return

	_setup_ui = setup
	setup.setup_finished.connect(_on_setup_finished)
	setup.tree_exited.connect(func():
		if _setup_ui == setup:
			_setup_ui = null
	)

func _on_setup_finished(_totem_id: String, _sprout_ids: Array) -> void:
	if RunConfig.core_tiles.size() > 0:
		DeckManager.build_deck_from_core("res://data/deck.json", RunConfig.core_tiles)
	else:
		DeckManager.build_starting_deck()
		if DeckManager.deck.size() > 0:
			DeckManager.shuffle()
			DeckManager.draw_one()
		else:
			DeckManager.next_tile_id = ""

	var world := $World
	if world != null and world.has_method("update_hud"):
		world.call("update_hud")

	RunConfig.mark_ready()

func _load_scene(path: String) -> PackedScene:
	if path.is_empty():
		return null

	if not ResourceLoader.exists(path):
		push_warning("Pre-run UI scene not found at %s" % path)
		return null

	var resource := ResourceLoader.load(path)
	if resource is PackedScene:
		return resource

	push_warning("Resource at %s is not a PackedScene" % path)
	return null
