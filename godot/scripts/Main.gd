extends Control

const PRE_RUN_SETUP_SCENE: PackedScene = preload("res://scenes/ui/PreRunSetup.tscn")
const PRE_RUN_DRAFT_SCENE: PackedScene = preload("res://scenes/ui/PreRunDraft.tscn")

var _setup_ui: PreRunSetup = null
var _draft_ui: PreRunDraft = null

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var map_id: String = str(ProjectSettings.get_setting("application/config/starting_map_id", "map.demo_001"))
	if RunConfig.has_method("set_map"):
		RunConfig.set_map(map_id)
	else:
		RunConfig.map_id = map_id
	_prepare_new_game(map_id)
	MapSeeder.load_map(map_id, $World)
	_ensure_pre_run_draft()
	_ensure_pre_run_setup()
	_begin_new_run_flow()

func _prepare_new_game(map_id: String) -> void:
	if SproutRegistry != null and SproutRegistry.has_method("refresh_for_new_game"):
		SproutRegistry.refresh_for_new_game(map_id)

func _begin_new_run_flow() -> void:
	RunConfig.clear_for_new_run()
	if _setup_ui != null:
		_setup_ui.open()
	elif _draft_ui != null:
		_draft_ui.open()

func _ensure_pre_run_setup() -> void:
	if is_instance_valid(_setup_ui):
		return
	if PRE_RUN_SETUP_SCENE == null:
		return
	var instance: Node = PRE_RUN_SETUP_SCENE.instantiate()
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

func _ensure_pre_run_draft() -> void:
	if is_instance_valid(_draft_ui):
		return
	if PRE_RUN_DRAFT_SCENE == null:
		return
	var instance: Node = PRE_RUN_DRAFT_SCENE.instantiate()
	if instance == null:
		return
	add_child(instance)
	var draft := instance as PreRunDraft
	if draft == null:
		instance.queue_free()
		return
	_draft_ui = draft
	draft.draft_done.connect(_on_draft_done)
	draft.tree_exited.connect(func():
		if _draft_ui == draft:
			_draft_ui = null
	)

func _on_setup_finished(_totem_id: String, _sprout_ids: Array) -> void:
	if RunConfig.core_tiles.size() > 0:
		DeckManager.build_deck_from_core("res://data/deck.json", RunConfig.core_tiles)
	if _draft_ui != null:
		_draft_ui.open()

func _on_draft_done() -> void:
	var world := $World
	if world != null and world.has_method("update_hud"):
		world.call("update_hud")
