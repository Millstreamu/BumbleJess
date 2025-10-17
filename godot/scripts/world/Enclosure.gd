extends Node
class_name Enclosure

const RunState := preload("res://autoload/RunState.gd")

static func axial_neighbors(ax: Vector2i) -> Array:
		var dirs := [Vector2i(+1, 0), Vector2i(+1, -1), Vector2i(0, -1), Vector2i(-1, 0), Vector2i(-1, +1), Vector2i(0, +1)]
		var out: Array = []
		for d in dirs:
				out.append(ax + d)
		return out

static func key(ax: Vector2i) -> String:
		return "%d,%d" % [ax.x, ax.y]

static func detect_and_mark_overgrowth(board: Node) -> void:
		var coords: Array = []
		for k in board.placed_tiles.keys():
				coords.append(_unkey(k))
		if coords.is_empty():
				return

		var min_q := 999999
		var max_q := -999999
		var min_r := 999999
		var max_r := -999999
		for ax in coords:
				min_q = min(min_q, ax.x)
				max_q = max(max_q, ax.x)
				min_r = min(min_r, ax.y)
				max_r = max(max_r, ax.y)
		min_q -= 1
		max_q += 1
		min_r -= 1
		max_r += 1

		var placed := {}
		for k in board.placed_tiles.keys():
				placed[k] = true
		var og := {}
		for k in RunState.overgrowth.keys():
				og[k] = true

		var visited := {}
		var queue: Array = []
		var enqueued := {}

		for q in range(min_q, max_q + 1):
				for r in [min_r, max_r]:
						var ax := Vector2i(q, r)
						if _is_empty(ax, placed, og):
								var k := key(ax)
								if not enqueued.has(k):
										queue.append(ax)
										enqueued[k] = true
		for r in range(min_r, max_r + 1):
				for q in [min_q, max_q]:
						var ax := Vector2i(q, r)
						if _is_empty(ax, placed, og):
								var k := key(ax)
								if not enqueued.has(k):
										queue.append(ax)
										enqueued[k] = true

		while queue.size() > 0:
				var cur: Vector2i = queue.pop_back()
				var ck := key(cur)
				if visited.has(ck):
						continue
				visited[ck] = true
				for n in axial_neighbors(cur):
						if n.x < min_q or n.x > max_q or n.y < min_r or n.y > max_r:
								continue
						var nk := key(n)
						if visited.has(nk):
								continue
						if _is_empty(n, placed, og):
								if not enqueued.has(nk):
										queue.append(n)
										enqueued[nk] = true

		for q in range(min_q, max_q + 1):
				for r in range(min_r, max_r + 1):
						var ax := Vector2i(q, r)
						var k := key(ax)
						if _is_empty(ax, placed, og) and not visited.has(k):
								if not RunState.overgrowth.has(k):
										RunState.overgrowth[k] = 0

static func _unkey(k: String) -> Vector2i:
		var parts := k.split(",")
		return Vector2i(int(parts[0]), int(parts[1]))

static func _is_empty(ax: Vector2i, placed: Dictionary, og: Dictionary) -> bool:
		var k := key(ax)
		return (not placed.has(k)) and (not og.has(k))
