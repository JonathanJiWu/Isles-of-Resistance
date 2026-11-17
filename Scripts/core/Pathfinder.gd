class_name Pathfinder
extends RefCounted
## A* search on the hex grid with pluggable passability and step cost.


## Returns the path from `start` to `goal` excluding `start` (empty if unreachable or start == goal).
## `passable(hex) -> bool` and `cost(hex) -> float` (must be >= 1). The goal is always considered passable.
static func find(start: Vector2i, goal: Vector2i, passable: Callable, cost: Callable, max_expand: int = 3000) -> Array:
	if start == goal:
		return []
	var open: Array = [start]
	var g := {start: 0.0}
	var f := {start: float(Hex.distance(start, goal))}
	var came := {}
	var closed := {}
	var expanded := 0
	while not open.is_empty():
		var bi := 0
		var bf: float = f[open[0]]
		for i in range(1, open.size()):
			var fv: float = f[open[i]]
			if fv < bf:
				bf = fv
				bi = i
		var cur: Vector2i = open[bi]
		open.remove_at(bi)
		if cur == goal:
			var path: Array = []
			var n := cur
			while n != start:
				path.push_front(n)
				n = came[n]
			return path
		closed[cur] = true
		expanded += 1
		if expanded > max_expand:
			break
		for nb in Hex.neighbors(cur):
			if closed.has(nb):
				continue
			if nb != goal and not passable.call(nb):
				continue
			var ng: float = g[cur] + float(cost.call(nb))
			if not g.has(nb) or ng < g[nb]:
				g[nb] = ng
				came[nb] = cur
				f[nb] = ng + Hex.distance(nb, goal)
				if not open.has(nb):
					open.append(nb)
	return []


## Breadth-first flood returning {hex: steps} for every hex reachable within `max_steps`.
static func flood(start: Vector2i, max_steps: int, passable: Callable) -> Dictionary:
	var dist := {start: 0}
	var frontier: Array = [start]
	while not frontier.is_empty():
		var next: Array = []
		for h in frontier:
			var d: int = dist[h]
			if d >= max_steps:
				continue
			for nb in Hex.neighbors(h):
				if dist.has(nb) or not passable.call(nb):
					continue
				dist[nb] = d + 1
				next.append(nb)
		frontier = next
	return dist
