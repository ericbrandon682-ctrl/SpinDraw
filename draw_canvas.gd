class_name DrawCanvas
extends Node2D

signal stroke_changed(is_valid: bool)

const MIN_POINT_DISTANCE := 8.0
const MAX_TOTAL_POINTS := 800
const STROKE_WIDTH := 6.0
const STROKE_COLOR := Color.WHITE
const BODY_GHOST_COLOR := Color("7f8aa3")
const WEAPON_COLOR := Color("ffb347")

## Body: side of the fixed drawing box.
const MAX_SIZE := 640.0
## Weapon: its strokes together must fit in this square.
const WEAPON_MAX_SIZE := 220.0
## A weapon stroke must start this close to the body.
const ATTACH_DISTANCE := 45.0

@export var draw_area := Rect2(0, 0, 1000, 720)

var strokes: Array[PackedVector2Array] = []
var lines: Array[Line2D] = []
var current := PackedVector2Array()
var current_line: Line2D = null
var is_drawing := false
var enabled := true
var box: Rect2

# Weapon mode
var weapon_mode := false
var attach_required := true
var body_count := 0
var wb_has := false
var wb_min := Vector2.ZERO
var wb_max := Vector2.ZERO

func _ready() -> void:
	var c := draw_area.get_center()
	box = Rect2(c - Vector2(MAX_SIZE, MAX_SIZE) * 0.5, Vector2(MAX_SIZE, MAX_SIZE))
	queue_redraw()

func _draw() -> void:
	# Graph-paper board
	draw_rect(draw_area, Color("0d0d1f"))
	var grid := Color(1, 1, 1, 0.05)
	var x := draw_area.position.x
	while x <= draw_area.end.x:
		draw_line(Vector2(x, draw_area.position.y), Vector2(x, draw_area.end.y), grid, 2.0)
		x += 40.0
	var y := draw_area.position.y
	while y <= draw_area.end.y:
		draw_line(Vector2(draw_area.position.x, y), Vector2(draw_area.end.x, y), grid, 2.0)
		y += 40.0

	# Drawing box: white frame with yellow corner blocks
	draw_rect(box, Color("07070f"))
	draw_rect(box, Color.WHITE, false, 6.0)
	for corner in [box.position, Vector2(box.end.x, box.position.y),
			box.end, Vector2(box.position.x, box.end.y)]:
		draw_rect(Rect2(corner - Vector2(9, 9), Vector2(18, 18)), UiStyle.YELLOW)

	if weapon_mode:
		if wb_has:
			var r := Rect2(wb_min, wb_max - wb_min)
			var at_limit := r.size.x >= WEAPON_MAX_SIZE - 1.0 or r.size.y >= WEAPON_MAX_SIZE - 1.0
			draw_rect(r, UiStyle.RED if at_limit else UiStyle.ORANGE, false, 3.0)
		else:
			var center := _body_rect().get_center()
			var half := Vector2.ONE * WEAPON_MAX_SIZE * 0.5
			draw_rect(Rect2(center - half, half * 2.0), Color(1, 0.7, 0.3, 0.5), false, 3.0)

func _unhandled_input(event: InputEvent) -> void:
	if not enabled:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			var pos := get_local_mouse_position()
			if box.has_point(pos) and (not weapon_mode or not attach_required or _near_body(pos)):
				_start(pos)
		else:
			_finish()
	elif event is InputEventMouseMotion and is_drawing:
		_continue(get_local_mouse_position())

func _near_body(pos: Vector2) -> bool:
	for i in body_count:
		for p in strokes[i]:
			if p.distance_to(pos) <= ATTACH_DISTANCE:
				return true
	return false

func _body_rect() -> Rect2:
	var mn := Vector2(1000000.0, 1000000.0)
	var mx := Vector2(-1000000.0, -1000000.0)
	for i in body_count:
		for p in strokes[i]:
			mn = mn.min(p)
			mx = mx.max(p)
	if mn.x > 999999.0:
		return Rect2(box.get_center(), Vector2.ZERO)
	return Rect2(mn, mx - mn)

func _constrain(pos: Vector2) -> Vector2:
	pos = pos.clamp(box.position, box.end)
	if weapon_mode and wb_has:
		pos.x = clampf(pos.x, wb_max.x - WEAPON_MAX_SIZE, wb_min.x + WEAPON_MAX_SIZE)
		pos.y = clampf(pos.y, wb_max.y - WEAPON_MAX_SIZE, wb_min.y + WEAPON_MAX_SIZE)
	return pos

func _start(pos: Vector2) -> void:
	is_drawing = true
	current = PackedVector2Array()
	current_line = Line2D.new()
	current_line.width = STROKE_WIDTH
	current_line.default_color = WEAPON_COLOR if weapon_mode else STROKE_COLOR
	current_line.joint_mode = Line2D.LINE_JOINT_ROUND
	current_line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	current_line.end_cap_mode = Line2D.LINE_CAP_ROUND
	current_line.antialiased = false
	add_child(current_line)
	_add(_constrain(pos))
	stroke_changed.emit(false)

func _continue(pos: Vector2) -> void:
	pos = _constrain(pos)
	if total_points() < MAX_TOTAL_POINTS \
			and current[current.size() - 1].distance_to(pos) >= MIN_POINT_DISTANCE:
		_add(pos)

func _add(pos: Vector2) -> void:
	current.append(pos)
	current_line.add_point(pos)
	if weapon_mode:
		_expand_wb(pos)
		queue_redraw()

func _expand_wb(p: Vector2) -> void:
	if not wb_has:
		wb_has = true
		wb_min = p
		wb_max = p
	else:
		wb_min = wb_min.min(p)
		wb_max = wb_max.max(p)

func _recompute_wb() -> void:
	wb_has = false
	for i in range(body_count, strokes.size()):
		for p in strokes[i]:
			_expand_wb(p)
	queue_redraw()

func _finish() -> void:
	if not is_drawing:
		return
	is_drawing = false
	if current.size() < 2:
		current_line.queue_free()
	else:
		strokes.append(current.duplicate())
		lines.append(current_line)
	current_line = null
	if weapon_mode:
		_recompute_wb()
	stroke_changed.emit(build_shape().size() > 0)

func total_points() -> int:
	var n := current.size() if is_drawing else 0
	for s in strokes:
		n += s.size()
	return n

func has_strokes() -> bool:
	return strokes.size() > 0

func _body_limit() -> int:
	return body_count if weapon_mode else strokes.size()

func all_points() -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in _body_limit():
		out.append_array(strokes[i])
	return out

## Body shape only (weapon strokes are never part of the hull).
func build_shape() -> Dictionary:
	var pts := all_points()
	if pts.size() < 3:
		return {}
	var hull := ShapeUtils.clean_hull(pts)
	if hull.size() < 3:
		return {}
	var area := ShapeUtils.area(hull)
	if area < TopStats.MIN_AREA:
		return {}
	var center := ShapeUtils.centroid(hull)
	var strokes_local: Array = []
	for i in _body_limit():
		strokes_local.append(ShapeUtils.offset_points(strokes[i], -center))
	return {
		"center": center,
		"area": area,
		"hull_local": ShapeUtils.offset_points(hull, -center),
		"strokes_local": strokes_local,
	}

# ---------- Weapon mode ----------

func enter_weapon_mode() -> void:
	weapon_mode = true
	body_count = strokes.size()
	wb_has = false
	for l in lines:
		l.visible = false   # hide the body while drawing the weapon
	queue_redraw()

func exit_weapon_mode() -> void:
	clear_weapon_strokes()
	weapon_mode = false
	body_count = 0
	for l in lines:
		l.visible = true
		l.default_color = STROKE_COLOR
	queue_redraw()

func weapon_strokes() -> Array:
	var out: Array = []
	for i in range(body_count, strokes.size()):
		out.append(strokes[i])
	return out

func clear_weapon_strokes() -> void:
	while strokes.size() > body_count:
		strokes.pop_back()
		lines.pop_back().queue_free()
	_recompute_wb()
	stroke_changed.emit(false)

# ---------- Undo / clear ----------

func undo_last_stroke() -> void:
	if strokes.is_empty():
		return
	if weapon_mode and strokes.size() <= body_count:
		return
	strokes.pop_back()
	lines.pop_back().queue_free()
	if weapon_mode:
		_recompute_wb()
	stroke_changed.emit(build_shape().size() > 0)

func clear_drawing() -> void:
	is_drawing = false
	current = PackedVector2Array()
	strokes.clear()
	for l in lines:
		l.queue_free()
	lines.clear()
	if current_line:
		current_line.queue_free()
		current_line = null
	weapon_mode = false
	body_count = 0
	wb_has = false
	queue_redraw()
	stroke_changed.emit(false)


# ---------- Loading a saved top for editing ----------

func _bounds_center(group: Array) -> Vector2:
	var mn := Vector2(1000000.0, 1000000.0)
	var mx := Vector2(-1000000.0, -1000000.0)
	for s in group:
		for p in s:
			mn = mn.min(p)
			mx = mx.max(p)
	if mn.x > 999999.0:
		return Vector2.ZERO
	return (mn + mx) * 0.5

func load_shape(body: Array, weapon: Array) -> void:
	clear_drawing()
	if body.is_empty():
		return
	var body_shift := box.get_center() - _bounds_center(body)
	for s in body:
		_add_loaded(s, body_shift, STROKE_COLOR)
	if not weapon.is_empty():
		enter_weapon_mode()
		var weapon_shift := box.get_center() - _bounds_center(weapon)
		for s in weapon:
			_add_loaded(s, weapon_shift, WEAPON_COLOR)
		_recompute_wb()
	stroke_changed.emit(build_shape().size() > 0)

func _add_loaded(s: PackedVector2Array, shift: Vector2, color: Color) -> void:
	var pts := PackedVector2Array()
	for p in s:
		pts.append((p + shift).clamp(box.position, box.end))
	var line := Line2D.new()
	line.width = STROKE_WIDTH
	line.default_color = color
	line.joint_mode = Line2D.LINE_JOINT_ROUND
	line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	line.end_cap_mode = Line2D.LINE_CAP_ROUND
	line.antialiased = false
	line.points = pts
	add_child(line)
	strokes.append(pts)
	lines.append(line)
