extends Node
## Coordinates turn phase flow and exposes a lightweight phase bus.
class_name TurnController

signal phase_new_tile
signal phase_growth
signal phase_mutation
signal phase_resources
signal phase_decay
signal phase_battle
signal phase_review

const RunState := preload("res://src/core/RunState.gd")

var _grid: Dictionary = {}

var _subscribers := {
		"phase_new_tile": [],
		"phase_growth": [],
		"phase_mutation": [],
		"phase_resources": [],
		"phase_decay": [],
		"phase_battle": [],
		"phase_review": [],
}

var is_advancing := false
var is_in_review := false

func _init() -> void:
				pass

func subscribe(phase: String, callable: Callable) -> void:
		if not _subscribers.has(phase):
				push_warning("Unknown phase: %s" % phase)
				return
		_subscribers[phase].append(callable)

func unsubscribe(phase: String, callable: Callable) -> void:
		if not _subscribers.has(phase):
				return
		_subscribers[phase].erase(callable)

func _emit_phase(phase: String) -> void:
		emit_signal(phase)
		var listeners: Array = _subscribers.get(phase, [])
		for listener in listeners:
				if listener is Callable and listener.is_valid():
						listener.call()

func end_turn() -> void:
		if is_advancing or is_in_review:
				return
		is_advancing = true
		RunState.turn += 1
		var tree := get_tree()
		var phases := [
				"phase_new_tile",
				"phase_growth",
				"phase_mutation",
				"phase_resources",
				"phase_decay",
				"phase_battle",
		]
		for phase in phases:
				_emit_phase(phase)
				if tree:
						await tree.process_frame
		is_in_review = true
		_emit_phase("phase_review")
		if tree:
				await tree.process_frame
		is_advancing = false

func ack_review_and_resume() -> void:
		if not is_in_review:
				return
		is_in_review = false

func set_tile(axial: Vector2i, category: String) -> void:
		if category == "" or category == null:
				_grid.erase(axial)
				return
		_grid[axial] = {"category": category}

func remove_tile(axial: Vector2i) -> void:
		_grid.erase(axial)
