class_name DrawLayer
extends Node2D
## A Node2D whose drawing is delegated to a callable: draw_fn(layer: DrawLayer).

var draw_fn: Callable
var animate := false


func _process(_delta: float) -> void:
	if animate:
		queue_redraw()


func _draw() -> void:
	if draw_fn.is_valid():
		draw_fn.call(self)


func hex_fill(h: Vector2i, top: Vector2, col: Color, inset: float = 1.0) -> void:
	draw_colored_polygon(Hex.corners(top, Hex.SIZE - inset), col)


func hex_outline(top: Vector2, col: Color, width: float = 2.0, inset: float = 2.0) -> void:
	var pts := Hex.corners(top, Hex.SIZE - inset)
	pts.append(pts[0])
	draw_polyline(pts, col, width, true)


## Draws the outer boundary of a set of hexes ({hex: true}).
func region_outline(hexes: Dictionary, tiles: Dictionary, col: Color, width: float = 2.0) -> void:
	for h in hexes:
		var top := MapView.top_center(tiles, h)
		for i in 6:
			if not hexes.has(h + Hex.DIRS[i]):
				var e := Hex.edge(top, i, Hex.SIZE - 1.0)
				draw_line(e[0], e[1], col, width, true)
