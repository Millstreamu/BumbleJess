extends RefCounted

const TurnController := preload("res://src/systems/TurnController.gd")
const RunState := preload("res://src/core/RunState.gd")

func _make_controller() -> TurnController:
		RunState.turn = 0
		var controller := TurnController.new()
		var tree: SceneTree = Engine.get_main_loop()
		tree.root.add_child(controller)
		return controller

func _record_signal(log: Array, phase: String) -> void:
		log.append(phase)

func _await_turn(controller: TurnController) -> void:
		var result = controller.end_turn()
		if result is GDScriptFunctionState:
				await result

func test_phase_bus_and_review_gate() -> bool:
		var controller := _make_controller()
		var signal_order: Array[String] = []
		var bus_order: Array[String] = []
		var reentry_guard := true

		var phases := [
				"phase_new_tile",
				"phase_growth",
				"phase_mutation",
				"phase_resources",
				"phase_decay",
				"phase_battle",
				"phase_review",
		]
		for phase in phases:
				controller.connect(phase, Callable(self, "_record_signal").bind(signal_order, phase))

		controller.subscribe("phase_new_tile", func(): bus_order.append("phase_new_tile#a"))
		controller.subscribe("phase_new_tile", func(): bus_order.append("phase_new_tile#b"))
		controller.subscribe("phase_growth", func():
				bus_order.append("phase_growth")
				var attempt = controller.end_turn()
				if attempt != null:
						reentry_guard = false
		)
		controller.subscribe("phase_mutation", func(): bus_order.append("phase_mutation"))
		controller.subscribe("phase_resources", func(): bus_order.append("phase_resources"))
		controller.subscribe("phase_decay", func(): bus_order.append("phase_decay"))
		controller.subscribe("phase_battle", func(): bus_order.append("phase_battle"))
		controller.subscribe("phase_review", func(): bus_order.append("phase_review"))

		await _await_turn(controller)

		var expected_signal := [
				"phase_new_tile",
				"phase_growth",
				"phase_mutation",
				"phase_resources",
				"phase_decay",
				"phase_battle",
				"phase_review",
		]
		if signal_order.size() < expected_signal.size():
				controller.queue_free()
				push_error("Not all phases emitted during the first turn")
				return false
		if signal_order.slice(0, expected_signal.size()) != expected_signal:
				controller.queue_free()
				push_error("Signal phase order incorrect: %s" % signal_order.slice(0, expected_signal.size()))
				return false

		var expected_bus := [
				"phase_new_tile#a",
				"phase_new_tile#b",
				"phase_growth",
				"phase_mutation",
				"phase_resources",
				"phase_decay",
				"phase_battle",
				"phase_review",
		]
		if bus_order.size() < expected_bus.size():
				controller.queue_free()
				push_error("Bus did not fire all expected callbacks on first turn")
				return false
		if bus_order.slice(0, expected_bus.size()) != expected_bus:
				controller.queue_free()
				push_error("Bus callback order incorrect: %s" % bus_order.slice(0, expected_bus.size()))
				return false

		if not reentry_guard:
				controller.queue_free()
				push_error("Re-entrant end_turn call was not blocked")
				return false

		if not controller.is_in_review:
				controller.queue_free()
				push_error("Review gate should be active after phase_review")
				return false
		if controller.is_advancing:
				controller.queue_free()
				push_error("Controller should not be advancing while in review")
				return false

		if RunState.turn != 1:
				controller.queue_free()
				push_error("RunState.turn should be 1 after first turn, got %d" % RunState.turn)
				return false

		var blocked = controller.end_turn()
		if blocked != null:
				controller.queue_free()
				push_error("end_turn should be ignored while review is active")
				return false
		if RunState.turn != 1:
				controller.queue_free()
				push_error("Turn count should not advance while review gate is open")
				return false

		controller.ack_review_and_resume()
		if controller.is_in_review:
				controller.queue_free()
				push_error("Review flag should clear after acknowledgement")
				return false

		await _await_turn(controller)
		var total_expected := expected_signal.size() * 2
		if signal_order.size() != total_expected:
				controller.queue_free()
				push_error("Expected %d total signal emissions after two turns, got %d" % [total_expected, signal_order.size()])
				return false
		if signal_order.slice(expected_signal.size(), expected_signal.size() * 2) != expected_signal:
				controller.queue_free()
				push_error("Second turn signal order incorrect: %s" % signal_order.slice(expected_signal.size(), expected_signal.size() * 2))
				return false
		if bus_order.size() != expected_bus.size() * 2:
				controller.queue_free()
				push_error("Expected %d bus callbacks after two turns, got %d" % [expected_bus.size() * 2, bus_order.size()])
				return false
		if bus_order.slice(expected_bus.size(), expected_bus.size() * 2) != expected_bus:
				controller.queue_free()
				push_error("Second turn bus order incorrect: %s" % bus_order.slice(expected_bus.size(), expected_bus.size() * 2))
				return false
		if RunState.turn != 2:
				controller.queue_free()
				push_error("Turn counter should be 2 after two turns, got %d" % RunState.turn)
				return false
		if signal_order.count("phase_review") != 2:
				controller.queue_free()
				push_error("Phase review should fire once per turn")
				return false

		controller.ack_review_and_resume()
		controller.queue_free()
		return true
