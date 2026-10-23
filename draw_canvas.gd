class_name DrawCanvas
extends Node2D

signal stroke_changed(is_valid: bool)

const MIN_POINT_DISTANCE := 8.0
const MAX_TOTAL_POINTS := 800
const STROKE_WIDTH := 6.0
const STROKE_COLOR := Color.WHITE

## Side length of the fixed square drawing box.
const MAX_SIZE := 640.0

@export var draw_area := Rect2(0, 0, 1000, 720)  # left area; the panel takes the right 280

var strokes: Array[PackedVector2Array] = []
var lines: Array[Line2D] = []
var current := PackedVector2Array()
var current_line: Line2D = null
var is_drawing := false
var enabled := true

## The fixed box the player must draw inside (always visible).
var box: Rect2

func _ready() -> void:
	# Center the box inside the draw area
	var c := draw_area.get_center()
	box = Rect2(c - Vector2(MAX_SIZE, MAX_SIZE) * 0.5, Vector2(MAX_SIZE, MAX_SIZE))
	queue_redraw()

func _draw() -> void:
	# Faint outer area (where touches are accepted)
	draw_rect(draw_area, Color(1, 1, 1, 0.12), false, 2.0)
	# Fixed size box: tinted fill + clear border
	draw_rect(box, Color(0.4, 1, 0.6, 0.08), true)
	draw_rect(box, Color(0.4, 1, 0.6, 0.7), false, 3.0)
	# Small corner ticks so the limit is easy to see
	var t := 24.0
	var col := Color(0.4, 1, 0.6, 0.9)
	for corner in [box.position, Vector2(box.end.x, box.position.y),
			box.end, Vector2(box.position.x, box.end.y)]:
		var sx := 1.0 if corner.x == box.position.x else -1.0
		var sy := 1.0 if corner.y == box.position.y else -1.0
		draw_line(corner, corner + Vector2(t * sx, 0), col, 5.0)
		draw_line(corner, corner + Vector2(0, t * sy), col, 5.0)

func _unhandled_input(event: InputEvent) -> void:
	if not enabled:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			var pos := get_local_mouse_position()
			# Start only if the press begins inside the box
			if box.has_point(pos):
				_start(pos)
		else:
			_finish()
	elif event is InputEventMouseMotion and is_drawing:
		_continue(get_local_mouse_position())

## Keeps points inside the box (the line slides along the edge).
func _constrain(pos: Vector2) -> Vector2:
	return pos.clamp(box.position, box.end)

func _start(pos: Vector2) -> void:
	is_drawing = true
	current = PackedVector2Array()
	current_line = Line2D.new()
	current_line.width = STROKE_WIDTH
	current_line.default_color = STROKE_COLOR
	current_line.joint_mode = Line2D.LINE_JOINT_ROUND
	current_line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	current_line.end_cap_mode = Line2D.LINE_CAP_ROUND
	current_line.antialiased = true
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
	stroke_changed.emit(build_shape().size() > 0)

func total_points() -> int:
	var n := current.size() if is_drawing else 0
	for s in strokes:
		n += s.size()
	return n

func has_strokes() -> bool:
	return strokes.size() > 0

func all_points() -> PackedVector2Array:
	var out := PackedVector2Array()
	for s in strokes:
		out.append_array(s)
	return out

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
	for s in strokes:
		strokes_local.append(ShapeUtils.offset_points(s, -center))
	return {
		"center": center,
		"area": area,
		"hull_local": ShapeUtils.offset_points(hull, -center),
		"strokes_local": strokes_local,
	}

func undo_last_stroke() -> void:
	if strokes.is_empty():
		return
	strokes.pop_back()
	lines.pop_back().queue_free()
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
	stroke_changed.emit(false)
