class_name FogView
extends Node2D
## Fog of war: unexplored hexes are hidden, explored-but-unseen hexes are dimmed.

var cells: Array = []
var tiles := {}
var explored := {}
var visible_hexes := {}


func setup(p_tiles: Dictionary, p_cells: Array) -> void:
	tiles = p_tiles
	cells = p_cells


func update_fog(p_explored: Dictionary, p_visible: Dictionary) -> void:
	explored = p_explored.duplicate()
	visible_hexes = p_visible.duplicate()
	queue_redraw()


## Recorded into one batched mesh (see CanvasBatcher); rebuilt only when it changes.
var _c: CanvasBatcher
var _mesh: ArrayMesh


func _draw() -> void:
	_c = CanvasBatcher.new()
	_paint()
	_mesh = _c.submit(self)
	_c = null


func _paint() -> void:
	var dark := Color(0.02, 0.045, 0.08, 0.93)
	for h in cells:
		if explored.has(h):
			continue
		var c := Hex.to_pixel(h)
		_c.draw_colored_polygon(Hex.corners(c, Hex.SIZE + 1.5), dark)
		_c.draw_colored_polygon(Hex.corners(c - Vector2(0, 9), Hex.SIZE + 1.5), dark)
	for h in cells:
		if not explored.has(h):
			continue
		var c := Hex.to_pixel(h)
		if not visible_hexes.has(h):
			var dim := Color(0.02, 0.04, 0.08, 0.45)
			_c.draw_colored_polygon(Hex.corners(c - Vector2(0, MapView.elev(tiles[h])), Hex.SIZE + 0.8), dim)
	# Faint grid inside the unexplored void hints that there is more to discover.
	for h in cells:
		if explored.has(h):
			continue
		var pts := Hex.corners(Hex.to_pixel(h), Hex.SIZE * 0.92)
		pts.append(pts[0])
		_c.draw_polyline(pts, Color(0.3, 0.5, 0.6, 0.05), 1.0)
