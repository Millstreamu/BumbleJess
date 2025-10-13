extends RefCounted
## Utility helpers for working with axial hexagonal coordinates in a flat-topped grid.
class_name Hex

const SQRT3 := sqrt(3.0)

class Axial:
	var q: int
	var r: int

	func _init(q: int = 0, r: int = 0) -> void:
		self.q = q
		self.r = r

	func to_vector2i() -> Vector2i:
		return Vector2i(q, r)

	static func from_vector2i(value: Vector2i) -> Axial:
		return Axial.new(value.x, value.y)

	func offset(delta: Axial) -> Axial:
		return Axial.new(q + delta.q, r + delta.r)

static var DIRECTIONS: Array[Axial] = _create_directions()

static func _create_directions() -> Array[Axial]:
	var directions: Array[Axial] = []
	directions.append(Axial.new(1, 0))
	directions.append(Axial.new(0, 1))
	directions.append(Axial.new(-1, 1))
	directions.append(Axial.new(-1, 0))
	directions.append(Axial.new(0, -1))
	directions.append(Axial.new(1, -1))
	return directions

static func neighbors(axial: Axial) -> Array[Axial]:
	var result: Array[Axial] = []
	for direction in DIRECTIONS:
		result.append(axial.offset(direction))
	return result

static func axial_to_world(axial: Axial, cell_size: float) -> Vector2:
	var q: float = float(axial.q)
	var r: float = float(axial.r)
	var x: float = cell_size * (1.5 * q)
	var y: float = cell_size * (SQRT3 * (r + q / 2.0))
	return Vector2(x, y)

static func world_to_axial(position: Vector2, cell_size: float) -> Axial:
	var q: float = ((2.0 / 3.0) * position.x) / cell_size
	var r: float = ((-1.0 / 3.0) * position.x + (SQRT3 / 3.0) * position.y) / cell_size
	return Axial.from_vector2i(_cube_round(Vector3(q, -q - r, r)))

static func ring(center: Axial, radius: int) -> Array[Axial]:
	var results: Array[Axial] = []
	if radius < 0:
		return results
	if radius == 0:
		results.append(center)
		return results
	var axial: Axial = center.offset(_scale(DIRECTIONS[4], radius))
	for direction in DIRECTIONS:
		for _i in range(radius):
			results.append(axial)
			axial = axial.offset(direction)
	return results

static func distance(a: Axial, b: Axial) -> int:
	var dq: int = a.q - b.q
	var dr: int = a.r - b.r
	var ds: int = (-a.q - a.r) - (-b.q - b.r)
	return int((abs(dq) + abs(dr) + abs(ds)) / 2)

static func _cube_round(cube: Vector3) -> Vector2i:
	var rx: float = round(cube.x)
	var ry: float = round(cube.y)
	var rz: float = round(cube.z)

	var x_diff: float = abs(rx - cube.x)
	var y_diff: float = abs(ry - cube.y)
	var z_diff: float = abs(rz - cube.z)

	if x_diff > y_diff and x_diff > z_diff:
		rx = -ry - rz
	elif y_diff > z_diff:
		ry = -rx - rz
	else:
		rz = -rx - ry

	return Vector2i(int(rx), int(rz))

static func _scale(axial: Axial, factor: int) -> Axial:
	return Axial.new(axial.q * factor, axial.r * factor)
