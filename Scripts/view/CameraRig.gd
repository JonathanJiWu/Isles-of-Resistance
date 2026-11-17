class_name CameraRig
extends Camera2D
## Pan (keys, drag, screen edge) and zoom (wheel, keys) camera with bounds and screen shake.

const MIN_ZOOM := 0.55
const MAX_ZOOM := 1.9

var bounds := Rect2(0, 0, 1000, 1000)
var target_zoom := 1.0
var keyboard_enabled := true
var edge_pan := false
var last_drag_distance := 0.0
var _dragging := false
var _drag_button := 0
var _shake := 0.0
var _glide_target := Vector2.ZERO
var _gliding := false


func _ready() -> void:
	zoom = Vector2(target_zoom, target_zoom)


## Returns true if the event was consumed by the camera.
func handle_input(event: InputEvent) -> bool:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and (mb.button_index == MOUSE_BUTTON_WHEEL_UP or mb.button_index == MOUSE_BUTTON_WHEEL_DOWN):
			var factor := 1.12 if mb.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0 / 1.12
			_zoom_at(factor, get_global_mouse_position())
			return true
		if mb.button_index == MOUSE_BUTTON_MIDDLE or mb.button_index == MOUSE_BUTTON_RIGHT:
			if mb.pressed:
				_dragging = true
				_drag_button = mb.button_index
				last_drag_distance = 0.0
			elif mb.button_index == _drag_button:
				_dragging = false
			return mb.button_index == MOUSE_BUTTON_MIDDLE
	elif event is InputEventMouseMotion and _dragging:
		var mm := event as InputEventMouseMotion
		last_drag_distance += mm.relative.length()
		if last_drag_distance > 5.0:
			position -= mm.relative / zoom.x
			_gliding = false
			_clamp()
		return true
	elif event is InputEventMagnifyGesture:
		_zoom_at((event as InputEventMagnifyGesture).factor, get_global_mouse_position())
		return true
	elif event is InputEventPanGesture:
		position += (event as InputEventPanGesture).delta * 12.0 / zoom.x
		_clamp()
		return true
	return false


func _zoom_at(factor: float, world_point: Vector2) -> void:
	var old := target_zoom
	target_zoom = clampf(target_zoom * factor, MIN_ZOOM, MAX_ZOOM)
	if is_equal_approx(old, target_zoom):
		return
	# Keep the point under the cursor stable.
	var ratio := old / target_zoom
	position = world_point + (position - world_point) * ratio
	_gliding = false
	_clamp()


func center_on(p: Vector2, instant: bool = false) -> void:
	if instant:
		position = p
		_gliding = false
		_clamp()
	else:
		_glide_target = p
		_gliding = true


func shake(amount: float) -> void:
	_shake = minf(_shake + amount, 14.0)


func _process(delta: float) -> void:
	var move := Vector2.ZERO
	if keyboard_enabled and not _focus_blocked():
		if Input.is_action_pressed("ui_left") or Input.is_key_pressed(KEY_A):
			move.x -= 1
		if Input.is_action_pressed("ui_right") or Input.is_key_pressed(KEY_D):
			move.x += 1
		if Input.is_action_pressed("ui_up") or Input.is_key_pressed(KEY_W):
			move.y -= 1
		if Input.is_action_pressed("ui_down") or Input.is_key_pressed(KEY_S):
			move.y += 1
		if Input.is_key_pressed(KEY_Q):
			_zoom_at(1.0 - delta * 1.5, global_position)
		if Input.is_key_pressed(KEY_E):
			_zoom_at(1.0 + delta * 1.5, global_position)
	if edge_pan and DisplayServer.window_is_focused():
		var vp := get_viewport()
		var m := vp.get_mouse_position()
		var size := vp.get_visible_rect().size
		if Rect2(Vector2.ZERO, size).has_point(m):
			if m.x < 8:
				move.x -= 1
			elif m.x > size.x - 8:
				move.x += 1
			if m.y < 8:
				move.y -= 1
			elif m.y > size.y - 8:
				move.y += 1
	if move != Vector2.ZERO:
		position += move.normalized() * 720.0 * delta / zoom.x
		_gliding = false
		_clamp()
	if _gliding:
		position = position.lerp(_glide_target, minf(1.0, delta * 6.0))
		if position.distance_to(_glide_target) < 1.0:
			_gliding = false
		_clamp()
	var z := lerpf(zoom.x, target_zoom, minf(1.0, delta * 12.0))
	zoom = Vector2(z, z)
	if _shake > 0.0:
		offset = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * _shake
		_shake = move_toward(_shake, 0.0, delta * 30.0)
	else:
		offset = Vector2.ZERO


func _focus_blocked() -> bool:
	var f := get_viewport().gui_get_focus_owner()
	return f is LineEdit or f is TextEdit


func _clamp() -> void:
	position.x = clampf(position.x, bounds.position.x, bounds.end.x)
	position.y = clampf(position.y, bounds.position.y, bounds.end.y)
