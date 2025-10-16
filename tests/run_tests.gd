extends SceneTree

const TEST_SCRIPTS := [
	preload("res://tests/grid_test.gd"),
	preload("res://tests/placement_rules_test.gd"),
	preload("res://tests/test_config_load.gd"),
	preload("res://tests/test_tiletypes.gd"),
	preload("res://tests/test_draft_logic.gd"),
	preload("res://tests/test_deck_build.gd"),
	preload("res://tests/test_resources_model.gd"),
	preload("res://tests/test_caps_clusters_storage.gd"),
	preload("res://tests/test_refine_and_harvest.gd"),
	preload("res://tests/test_enclosure.gd"),
	preload("res://tests/test_growth_to_grove.gd"),
	preload("res://tests/test_mutation_grove_thicket.gd"),
	preload("res://tests/test_turn_bus.gd"),
	preload("res://tests/test_decay_seed.gd"),
	preload("res://tests/test_decay_spread.gd"),
	preload("res://tests/test_decay_adjacency_corruption.gd"),
	preload("res://tests/test_pathhex.gd"),
]

func _init() -> void:
	call_deferred("_run_all_tests")

func _run_all_tests() -> void:
	var failed := false
	for script in TEST_SCRIPTS:
		var test_case: Object = script.new()
		for method in test_case.get_method_list():
			var name: String = method.name
			if not name.begins_with("test_"):
				continue
			var result: Variant = test_case.call(name)
			if typeof(result) == TYPE_OBJECT and result.get_class() == "GDScriptFunctionState":
				result = await result
			if result is bool and not result:
				failed = true
	if failed:
		quit(1)
	else:
		quit(0)
