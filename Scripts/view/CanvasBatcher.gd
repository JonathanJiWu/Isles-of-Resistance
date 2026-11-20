class_name CanvasBatcher
extends RefCounted
## Records 2D drawing into a single vertex-coloured triangle mesh.
##
## The Compatibility renderer issues one draw call per polygon, circle and thick line, so a static
## layer built from thousands of small shapes (the terrain, the installations, the fog) cost
## thousands of draw calls a frame. Static layers draw into a CanvasBatcher instead, which mirrors
## the subset of CanvasItem's drawing API they use, and then submit everything with one
## draw_mesh(). Antialiased lines get a one-unit alpha feather, which is what Godot does too.
## Text and textures cannot go into the mesh; they are replayed on top, in order.

var _pts := PackedVector2Array()
var _cols := PackedColorArray()
var _xf := Transform2D.IDENTITY
var _scale := 1.0
var _passthrough: Array = []   # [transform, method, args]

const FEATHER := 1.0


func draw_set_transform(pos: Vector2, rot: float = 0.0, scale: Vector2 = Vector2.ONE) -> void:
	_xf = Transform2D(rot, scale, 0.0, pos)
	_scale = absf(scale.x)


func draw_set_transform_matrix(m: Transform2D) -> void:
	_xf = m
	_scale = m.get_scale().x


func vertex_count() -> int:
	return _pts.size()


# --------------------------------------------------------------------------------------------
# Primitives
# --------------------------------------------------------------------------------------------

func _tri(a: Vector2, b: Vector2, c: Vector2, ca: Color, cb: Color, cc: Color) -> void:
	_pts.append(_xf * a)
	_pts.append(_xf * b)
	_pts.append(_xf * c)
	_cols.append(ca)
	_cols.append(cb)
	_cols.append(cc)


func _quad(a: Vector2, b: Vector2, c: Vector2, d: Vector2, ca: Color, cb: Color, cc: Color, cd: Color) -> void:
	_tri(a, b, c, ca, cb, cc)
	_tri(a, c, d, ca, cc, cd)


func draw_colored_polygon(points: PackedVector2Array, color: Color, _uvs = null, _texture = null) -> void:
	var n := points.size()
	if n < 3 or color.a <= 0.0:
		return
	if n == 3:
		_tri(points[0], points[1], points[2], color, color, color)
		return
	var idx := Geometry2D.triangulate_polygon(points)
	for i in range(0, idx.size(), 3):
		_tri(points[idx[i]], points[idx[i + 1]], points[idx[i + 2]], color, color, color)


func draw_polygon(points: PackedVector2Array, colors: PackedColorArray, _uvs = null, _texture = null) -> void:
	if colors.size() <= 1:
		draw_colored_polygon(points, colors[0] if colors.size() == 1 else Color.WHITE)
		return
	if points.size() < 3:
		return
	var idx := Geometry2D.triangulate_polygon(points)
	for i in range(0, idx.size(), 3):
		_tri(points[idx[i]], points[idx[i + 1]], points[idx[i + 2]], colors[idx[i]], colors[idx[i + 1]], colors[idx[i + 2]])


func draw_rect(rect: Rect2, color: Color, filled: bool = true, width: float = -1.0, antialiased: bool = false) -> void:
	if not filled:
		var p := rect.position
		var s := rect.size
		draw_polyline(PackedVector2Array([p, p + Vector2(s.x, 0), p + s, p + Vector2(0, s.y), p]), color, width, antialiased)
		return
	var a := rect.position
	var b := a + Vector2(rect.size.x, 0)
	var c := a + rect.size
	var d := a + Vector2(0, rect.size.y)
	_quad(a, b, c, d, color, color, color, color)


func draw_circle(center: Vector2, radius: float, color: Color, filled: bool = true, width: float = -1.0, antialiased: bool = false) -> void:
	if not filled:
		draw_arc(center, radius, 0.0, TAU, _segments(radius) + 1, color, width, antialiased)
		return
	if radius <= 0.0 or color.a <= 0.0:
		return
	var n := _segments(radius)
	var prev := center + Vector2(radius, 0)
	for i in range(1, n + 1):
		var a := TAU * i / n
		var cur := center + Vector2(cos(a), sin(a)) * radius
		_tri(center, prev, cur, color, color, color)
		prev = cur


func _segments(radius: float) -> int:
	return clampi(int(radius * _scale * 1.4) + 6, 8, 40)


func draw_line(from: Vector2, to: Vector2, color: Color, width: float = -1.0, antialiased: bool = false) -> void:
	if color.a <= 0.0:
		return
	var d := to - from
	var l := d.length()
	if l <= 0.0001:
		return
	var w := maxf(width, 1.0 / maxf(_scale, 0.01)) * 0.5
	var n := Vector2(-d.y, d.x) / l
	var a0 := from + n * w
	var b0 := to + n * w
	var a1 := from - n * w
	var b1 := to - n * w
	_quad(a0, b0, b1, a1, color, color, color, color)
	if antialiased:
		var clear := Color(color, 0.0)
		var f := n * FEATHER
		_quad(a0 + f, b0 + f, b0, a0, clear, clear, color, color)
		_quad(a1, b1, b1 - f, a1 - f, color, color, clear, clear)


func draw_polyline(points: PackedVector2Array, color: Color, width: float = -1.0, antialiased: bool = false) -> void:
	for i in range(points.size() - 1):
		draw_line(points[i], points[i + 1], color, width, antialiased)
	# Fill the outer wedge at each bend so thick lines don't crack at the corners.
	if width > 2.0:
		for i in range(1, points.size() - 1):
			draw_circle(points[i], width * 0.5, color)


func draw_multiline(points: PackedVector2Array, color: Color, width: float = -1.0, antialiased: bool = false) -> void:
	for i in range(0, points.size() - 1, 2):
		draw_line(points[i], points[i + 1], color, width, antialiased)


func draw_arc(center: Vector2, radius: float, start_angle: float, end_angle: float, point_count: int, color: Color, width: float = -1.0, antialiased: bool = false) -> void:
	if point_count < 2:
		return
	var pts := PackedVector2Array()
	pts.resize(point_count)
	for i in point_count:
		var a := lerpf(start_angle, end_angle, float(i) / (point_count - 1))
		pts[i] = center + Vector2(cos(a), sin(a)) * radius
	draw_polyline(pts, color, width, antialiased)


# --------------------------------------------------------------------------------------------
# Pass-through (text, textures): drawn after the mesh, in order
# --------------------------------------------------------------------------------------------

func draw_string(font: Font, pos: Vector2, text: String, alignment: int = HORIZONTAL_ALIGNMENT_LEFT, width: float = -1.0, font_size: int = 16, modulate: Color = Color.WHITE, justification_flags: int = 3, direction: int = 0, orientation: int = 0) -> void:
	_passthrough.append([_xf, "draw_string", [font, pos, text, alignment, width, font_size, modulate, justification_flags, direction, orientation]])


func draw_string_outline(font: Font, pos: Vector2, text: String, alignment: int = HORIZONTAL_ALIGNMENT_LEFT, width: float = -1.0, font_size: int = 16, size: int = 1, modulate: Color = Color.WHITE, justification_flags: int = 3, direction: int = 0, orientation: int = 0) -> void:
	_passthrough.append([_xf, "draw_string_outline", [font, pos, text, alignment, width, font_size, size, modulate, justification_flags, direction, orientation]])


func draw_texture(texture: Texture2D, pos: Vector2, modulate: Color = Color.WHITE) -> void:
	_passthrough.append([_xf, "draw_texture", [texture, pos, modulate]])


# --------------------------------------------------------------------------------------------
# Output
# --------------------------------------------------------------------------------------------

## Builds the mesh (or null if nothing was drawn).
func build() -> ArrayMesh:
	if _pts.is_empty():
		return null
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = _pts
	arrays[Mesh.ARRAY_COLOR] = _cols
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


## Draws everything recorded onto `ci` (call from its _draw). Returns the mesh, which the caller
## must keep alive for as long as the canvas item shows it.
func submit(ci: CanvasItem) -> ArrayMesh:
	var mesh := build()
	if mesh != null:
		ci.draw_set_transform_matrix(Transform2D.IDENTITY)
		ci.draw_mesh(mesh, null)
	for p in _passthrough:
		ci.draw_set_transform_matrix(p[0])
		ci.callv(p[1], p[2])
	ci.draw_set_transform_matrix(Transform2D.IDENTITY)
	return mesh
