class_name Hex
extends RefCounted
## Pointy-top hexagon helpers using axial coordinates (q, r) stored in Vector2i.

const SIZE := 34.0
const SQRT3 := 1.7320508075688772
const INVALID := Vector2i(-9999, -9999)

const DIRS: Array[Vector2i] = [
	Vector2i(1, 0), Vector2i(1, -1), Vector2i(0, -1),
	Vector2i(-1, 0), Vector2i(-1, 1), Vector2i(0, 1),
]


static func neighbors(h: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for d in DIRS:
		out.append(h + d)
	return out


static func distance(a: Vector2i, b: Vector2i) -> int:
	var dq := a.x - b.x
	var dr := a.y - b.y
	return (absi(dq) + absi(dr) + absi(dq + dr)) >> 1


static func to_pixel(h: Vector2i) -> Vector2:
	return Vector2(SIZE * SQRT3 * (h.x + h.y * 0.5), SIZE * 1.5 * h.y)


static func from_pixel(p: Vector2) -> Vector2i:
	var q := (SQRT3 / 3.0 * p.x - 1.0 / 3.0 * p.y) / SIZE
	var r := (2.0 / 3.0 * p.y) / SIZE
	return round_axial(q, r)


static func round_axial(qf: float, rf: float) -> Vector2i:
	var sf := -qf - rf
	var q := roundf(qf)
	var r := roundf(rf)
	var s := roundf(sf)
	var dq := absf(q - qf)
	var dr := absf(r - rf)
	var ds := absf(s - sf)
	if dq > dr and dq > ds:
		q = -r - s
	elif dr > ds:
		r = -q - s
	return Vector2i(int(q), int(r))


static func corners(center: Vector2, size: float = SIZE) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 6:
		var a := deg_to_rad(60.0 * i - 30.0)
		pts.append(center + Vector2(cos(a), sin(a)) * size)
	return pts


## Returns the two corner points of the edge shared with neighbour in direction `dir_index`.
static func edge(center: Vector2, dir_index: int, size: float = SIZE) -> PackedVector2Array:
	# DIRS order: E, NE, NW, W, SW, SE.  Corner i sits at angle 60*i - 30 with y pointing down,
	# so corner 0 is upper-right, 1 lower-right, 2 bottom, 3 lower-left, 4 upper-left, 5 top.
	var corner_pairs := [[0, 1], [5, 0], [4, 5], [3, 4], [2, 3], [1, 2]]
	var c := corners(center, size)
	var pair: Array = corner_pairs[dir_index]
	return PackedVector2Array([c[pair[0]], c[pair[1]]])


@warning_ignore("integer_division")
static func offset_to_axial(col: int, row: int) -> Vector2i:
	return Vector2i(col - (row - (row & 1)) / 2, row)


@warning_ignore("integer_division")
static func axial_to_offset(h: Vector2i) -> Vector2i:
	return Vector2i(h.x + (h.y - (h.y & 1)) / 2, h.y)


static func in_range(center: Vector2i, radius: int) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for dq in range(-radius, radius + 1):
		for dr in range(maxi(-radius, -dq - radius), mini(radius, -dq + radius) + 1):
			out.append(center + Vector2i(dq, dr))
	return out


static func ring(center: Vector2i, radius: int) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	if radius <= 0:
		out.append(center)
		return out
	var h := center + DIRS[4] * radius
	for i in 6:
		for _j in radius:
			out.append(h)
			h += DIRS[i]
	return out


static func line(a: Vector2i, b: Vector2i) -> Array[Vector2i]:
	var n := distance(a, b)
	var out: Array[Vector2i] = []
	if n == 0:
		out.append(a)
		return out
	for i in n + 1:
		var t := float(i) / n
		var qf := lerpf(a.x + 1e-6, b.x + 1e-6, t)
		var rf := lerpf(a.y + 1e-6, b.y + 1e-6, t)
		out.append(round_axial(qf, rf))
	return out


static func direction_index(from: Vector2i, to: Vector2i) -> int:
	var d := to - from
	for i in 6:
		if DIRS[i] == d:
			return i
	return -1
