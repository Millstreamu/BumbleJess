extends SceneTree

const TEST_SCRIPTS := [
        preload("res://tests/grid_test.gd"),
        preload("res://tests/placement_rules_test.gd"),
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
