extends RefCounted

const Resources := preload("res://src/systems/Resources.gd")
const TurnController := preload("res://src/systems/TurnController.gd")

func _make_controller() -> TurnController:
        var controller := TurnController.new()
        var tree: SceneTree = Engine.get_main_loop()
        tree.root.add_child(controller)
        return controller

func _await_turn(controller: TurnController) -> void:
        var result = controller.end_turn()
        if result is GDScriptFunctionState:
                await result
        controller.ack_review_and_resume()

func test_resource_clamp_to_cap() -> bool:
        var resources := Resources.new()
        resources.set_cap("nature", 10)
        resources.add("nature", 15)
        if resources.get_amount("nature") != 10:
                push_error("Nature should clamp to cap of 10")
                return false
        resources.add("nature", -20)
        if resources.get_amount("nature") != 0:
                push_error("Nature should not drop below zero")
                return false
        return true

func test_harvest_cluster_capacity_bonus() -> bool:
        var controller := _make_controller()
        controller.set_tile(Vector2i(0, 0), "Harvest")
        controller.set_tile(Vector2i(1, 0), "Harvest")
        controller.set_tile(Vector2i(0, 1), "Harvest")
        await _await_turn(controller)
        var expected := 3 * 5 + 3 * 10
        var cap := controller.resources.get_cap("nature")
        if cap != expected:
                controller.queue_free()
                push_error("Expected nature cap %d, got %d" % [expected, cap])
                return false
        controller.queue_free()
        return true

func test_storage_adjacent_bonus_applies_once_per_neighbor() -> bool:
        var controller := _make_controller()
        controller.set_tile(Vector2i(0, 0), "Harvest")
        await _await_turn(controller)
        var baseline := controller.resources.get_cap("nature")
        controller.set_tile(Vector2i(1, 0), "Storage")
        await _await_turn(controller)
        var with_storage := controller.resources.get_cap("nature")
        if with_storage != baseline + 5:
                controller.queue_free()
                push_error("Storage adjacency should add +5 nature capacity (baseline=%d, got=%d)" % [baseline, with_storage])
                return false
        controller.queue_free()
        return true

func test_refine_converts_every_two_turns() -> bool:
        var controller := _make_controller()
        controller.set_tile(Vector2i(0, 0), "Harvest")
        controller.set_tile(Vector2i(1, 0), "Build")
        controller.set_tile(Vector2i(0, 1), "Refine")
        await _await_turn(controller)
        controller.resources.add("nature", 2)
        controller.resources.add("earth", 2)
        await _await_turn(controller)
        var water := controller.resources.get_amount("water")
        if water != 1:
                controller.queue_free()
                push_error("Expected water to increase by 1 after two turns, got %d" % water)
                return false
        if controller.resources.get_amount("nature") != 1:
                controller.queue_free()
                push_error("Nature should have been reduced to 1")
                return false
        if controller.resources.get_amount("earth") != 1:
                controller.queue_free()
                push_error("Earth should have been reduced to 1")
                return false
        controller.queue_free()
        return true
