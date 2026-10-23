class_name DrawCanvas
extends Node2D

signal stroke_changed(is_valid: bool)

const MIN_POINT_DISTANCE := 8.0
const MAX_POINTS := 400

## Playable drawing region (keep it above the bottom UI panel).
@export var draw_area := Rect2(20, 20, 680, 1060)

@onready var stroke: Line2D = $Stroke

var points := PackedVector2Array()
var is_drawing := false
var enabled := true

func _draw() -> void:
	draw_rect(draw_area, Color(1, 1, 1, 0.25), false, 2.0)

func _unhandled_input(event: InputEvent) -> void:
	if not enabled:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			var pos := get_local_mouse_position()
			if draw_area.has_point(pos):
				_start(pos)
		else:
			_finish()
	elif event is InputEventMouseMotion and is_drawing:
		_continue(get_local_mouse_position())

func _start(pos: Vector2) -> void:
	is_drawing = true
	points.clear()
	stroke.clear_points()
	_add(pos)
	stroke_changed.emit(false)

func _continue(pos: Vector2) -> void:
	pos = pos.clamp(draw_area.position, draw_area.end)
	if points.size() < MAX_POINTS and points[-1].distance_to(pos) >= MIN_POINT_DISTANCE:
		_add(pos)

func _add(pos: Vector2) -> void:
	points.append(pos)
	stroke.add_point(pos)

func _finish() -> void:
	if not is_drawing:
		return
	is_drawing = false
	stroke_changed.emit(build_shape().size() > 0)

## Returns {} if invalid, otherwise hull/center/area/stroke data.
func build_shape() -> Dictionary:
	if points.size() < 3:
		return {}
	var hull := ShapeUtils.clean_hull(points)
	if hull.size() < 3:
		return {}
	var area := ShapeUtils.area(hull)
	if area < TopStats.MIN_AREA:
		return {}
	var center := ShapeUtils.centroid(hull)
	return {
		"center": center,
		"area": area,
		"hull_local": ShapeUtils.offset_points(hull, -center),
		"stroke_local": ShapeUtils.offset_points(points, -center),
	}

func clear_drawing() -> void:
	is_drawing = false
	points.clear()
	stroke.clear_points()
	stroke_changed.emit(false)
