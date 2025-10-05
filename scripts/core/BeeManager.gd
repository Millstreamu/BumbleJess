extends Node
## Central manager for all bee entities. Responsible for tracking their
## state, specialisations, and assignments to cells.

signal bee_spawned(bee_id: int)
signal bee_assigned(bee_id: int, q: int, r: int)
signal bee_unassigned(bee_id: int)
signal bee_specialisation_changed(bee_id: int, spec: String)

const CellType := preload("res://scripts/core/CellType.gd")

const STATE_UNASSIGNED := "UNASSIGNED"
const STATE_ASSIGNED := "ASSIGNED"

const SPECIALISATIONS := [
	"GATHER",
	"BREWER",
	"CONSTRUCTION",
	"GUARD",
	"ARCANIST",
]

var _next_bee_id: int = 1
var _bees: Dictionary = {}
var _cell_assignments: Dictionary = {}
var _hex_grid: Node = null

func register_hex_grid(grid: Node) -> void:
	_hex_grid = grid

func spawn_bee(origin: Vector2i) -> int:
	var bee_id := _next_bee_id
	_next_bee_id += 1
	var bee_data := {
		"id": bee_id,
		"state": STATE_UNASSIGNED,
		"specialisation": SPECIALISATIONS[0],
		"assigned_cell": null,
		"origin_brood": origin,
	}
	_bees[bee_id] = bee_data
	print("[Bees] Hatch complete at (%d,%d) -> Bee #%d spawned (%s)." % [origin.x, origin.y, bee_id, STATE_UNASSIGNED])
	emit_signal("bee_spawned", bee_id)
	return bee_id

func set_specialisation(bee_id: int, spec: String) -> void:
	if not _bees.has(bee_id):
		return
	var normalised: String = spec.to_upper()
	if not SPECIALISATIONS.has(normalised):
		return
	var bee: Dictionary = _bees[bee_id]
	if bee["specialisation"] == normalised:
		return
	bee["specialisation"] = normalised
	_bees[bee_id] = bee
	emit_signal("bee_specialisation_changed", bee_id, normalised)

func assign_to_cell(bee_id: int, q: int, r: int) -> bool:
	if not _bees.has(bee_id):
		return false
	if _hex_grid == null:
		push_warning("BeeManager has no HexGrid registered; cannot assign bees.")
		return false
	var bee: Dictionary = _bees[bee_id]
	var spec: String = bee["specialisation"]
	var axial := Vector2i(q, r)

	if spec == "GATHER":
		print("[Bees] Bee #%d cannot be assigned yet: Gathering roles are virtual." % bee_id)
		return false

	var cap: int = _hex_grid.get_bee_cap(q, r)
	if cap <= 0:
		var cell_type: int = _hex_grid.get_cell_type(q, r)
		print("[Bees] Bee #%d cannot enter %s at (%d,%d): no capacity." % [
			bee_id,
			CellType.to_display_name(cell_type),
			q,
			r,
		])
		return false

	var allowed_types: Array = _hex_grid.get_cell_types_for_specialisation(spec)
	var cell_type: int = _hex_grid.get_cell_type(q, r)
	if allowed_types.is_empty() or not allowed_types.has(cell_type):
		print("[Bees] Bee #%d with specialisation %s cannot work in %s." % [
			bee_id,
			spec,
			CellType.to_display_name(cell_type),
		])
		return false

	var occupants: Array = _cell_assignments.get(axial, [])
	if bee["state"] == STATE_ASSIGNED:
		var previous: Vector2i = bee["assigned_cell"]
		if previous == axial:
			return true
		_remove_bee_from_cell(previous, bee_id)
		occupants = _cell_assignments.get(axial, [])

	if occupants.size() >= cap:
		print("[Bees] %s at (%d,%d) is already at capacity." % [
			CellType.to_display_name(cell_type),
			q,
			r,
		])
		return false

	occupants.append(bee_id)
	_cell_assignments[axial] = occupants
	bee["state"] = STATE_ASSIGNED
	bee["assigned_cell"] = axial
	_bees[bee_id] = bee
	emit_signal("bee_assigned", bee_id, q, r)
	return true

func unassign(bee_id: int) -> void:
	if not _bees.has(bee_id):
		return
	var bee: Dictionary = _bees[bee_id]
	if bee["state"] != STATE_ASSIGNED:
		return
	var previous: Vector2i = bee["assigned_cell"]
	_remove_bee_from_cell(previous, bee_id)
	bee["state"] = STATE_UNASSIGNED
	bee["assigned_cell"] = null
	_bees[bee_id] = bee
	emit_signal("bee_unassigned", bee_id)

func list_bees(filter: String = "ALL") -> Array:
	var ids: Array = _bees.keys()
	ids.sort_custom(Callable(self, "_sort_ids"))
	var result: Array = []
	for id_value in ids:
		var bee: Dictionary = _bees[id_value]
		if filter == STATE_UNASSIGNED and bee["state"] != STATE_UNASSIGNED:
			continue
		if filter == STATE_ASSIGNED and bee["state"] != STATE_ASSIGNED:
			continue
		result.append(bee.duplicate())
	return result

func get_bee(bee_id: int) -> Dictionary:
	if not _bees.has(bee_id):
		return {}
	return _bees[bee_id].duplicate()

func get_bee_count_for_cell(axial: Vector2i) -> int:
	var occupants: Array = _cell_assignments.get(axial, [])
	return occupants.size()

func get_bees_for_cell(axial: Vector2i) -> Array:
	var occupants: Array = _cell_assignments.get(axial, [])
	return occupants.duplicate()

func _remove_bee_from_cell(axial: Vector2i, bee_id: int) -> void:
	if axial == null:
		return
	if not _cell_assignments.has(axial):
		return
	var occupants: Array = _cell_assignments[axial]
	occupants.erase(bee_id)
	if occupants.is_empty():
		_cell_assignments.erase(axial)
	else:
		_cell_assignments[axial] = occupants

func _sort_ids(a, b) -> bool:
	return int(a) < int(b)

func consume_bee_data_snapshot() -> Dictionary:
	return {
		"bees": _bees.duplicate(true),
		"assignments": _cell_assignments.duplicate(true),
	}

func get_cells_for_specialisation(spec: String) -> Array:
	if _hex_grid == null:
		return []
	return _hex_grid.get_cells_accepting(spec)
