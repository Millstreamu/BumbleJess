extends RefCounted

## Helper class for handling axial coordinate math and conversions between
## axial coordinates and world positions for a flat-topped hex grid layout.
class_name Coord

const SQRT3 := sqrt(3.0)

## Direction vectors for the six neighboring axial coordinates. The order is
## clockwise starting at the eastern neighbor.
const DIRECTIONS: Array[Vector2i] = [
        Vector2i(1, 0),
        Vector2i(0, 1),
        Vector2i(-1, 1),
	Vector2i(-1, 0),
	Vector2i(0, -1),
	Vector2i(1, -1),
]

static func axial_to_world(axial: Vector2i, cell_size: float) -> Vector2:
	## Converts an axial coordinate to a 2D world-space position. Assumes a
	## flat-topped hex layout and positions the hex at the returned Vector2.
	var q := float(axial.x)
	var r := float(axial.y)
	var x := cell_size * (1.5 * q)
	var y := cell_size * (SQRT3 * (r + q / 2.0))
	return Vector2(x, y)

static func world_to_axial(position: Vector2, cell_size: float) -> Vector2i:
	## Converts a world position to the nearest axial coordinate using cube
	## rounding. Suitable for hit detection or positioning the cursor.
	var q := ((2.0 / 3.0) * position.x) / cell_size
	var r := ((-1.0 / 3.0) * position.x + (SQRT3 / 3.0) * position.y) / cell_size
	return cube_round(Vector3(q, -q - r, r))

static func cube_round(cube: Vector3) -> Vector2i:
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

static func neighbor(axial: Vector2i, direction_index: int) -> Vector2i:
	direction_index = posmod(direction_index, DIRECTIONS.size())
	return axial + DIRECTIONS[direction_index]

static func axial_distance(a: Vector2i, b: Vector2i) -> int:
	var dq := a.x - b.x
	var dr := a.y - b.y
	var ds := -a.x - a.y - (-b.x - b.y)
	return int((abs(dq) + abs(dr) + abs(ds)) / 2)
