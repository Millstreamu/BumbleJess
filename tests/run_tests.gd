extends SceneTree

const TEST_SCRIPTS := [
        preload("res://tests/grid_test.gd"),
        preload("res://tests/placement_rules_test.gd"),
        preload("res://tests/test_config_load.gd"),
        preload("res://tests/test_tiletypes.gd"),
        preload("res://tests/test_draft_logic.gd"),
        preload("res://tests/test_deck_build.gd"),
        preload("res://tests/test_resources_systems.gd"),
        preload("res://tests/test_enclosure.gd"),
        preload("res://tests/test_growth_to_grove.gd"),
        preload("res://tests/test_mutation_grove_thicket.gd"),
]

func _init() -> void:
        var failed := false
        for script in TEST_SCRIPTS:
                var test_case := script.new()
                for method in test_case.get_method_list():
                        var name: String = method.name
                        if not name.begins_with("test_"):
                                continue
                        var result = test_case.call(name)
                        if result is bool and not result:
                                failed = true
        quit(failed ? 1 : 0)
