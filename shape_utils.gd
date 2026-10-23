class_name ShapeUtils
extends RefCounted

## Convex hull without the duplicated closing point Godot appends.
static func clean_hull(points: PackedVector2Array) -> PackedVector2Array:
	var hull := Geometry2D.convex_hull(points)
	if hull.size() > 1 and hull[0].is_equal_approx(hull[hull.size() - 1]):
		hull.remove_at(hull.size() - 1)
	return hull

static func area(poly: PackedVector2Array) -> float:
	var a := 0.0
	for i in poly.size():
		a += poly[i].cross(poly[(i + 1) % poly.size()])
	return absf(a) * 0.5

## True area centroid (not the average of vertices).
static func centroid(poly: PackedVector2Array) -> Vector2:
	var a := 0.0
	var c := Vector2.ZERO
	for i in poly.size():
		var p := poly[i]
		var q := poly[(i + 1) % poly.size()]
		var cr := p.cross(q)
		a += cr
		c += (p + q) * cr
	if absf(a) < 0.0001:
		return poly[0]
	return c / (3.0 * a)

static func offset_points(pts: PackedVector2Array, by: Vector2) -> PackedVector2Array:
	var out := PackedVector2Array()
	out.resize(pts.size())
	for i in pts.size():
		out[i] = pts[i] + by
	return out
