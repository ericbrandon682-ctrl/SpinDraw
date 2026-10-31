class_name ShapeUtils
extends RefCounted

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

## Ramer-Douglas-Peucker: removes points that barely change the line.
static func simplify(pts: PackedVector2Array, tolerance: float) -> PackedVector2Array:
	if pts.size() < 3:
		return pts
	var keep := PackedByteArray()
	keep.resize(pts.size())
	keep[0] = 1
	keep[pts.size() - 1] = 1
	var stack: Array = [[0, pts.size() - 1]]
	while not stack.is_empty():
		var seg = stack.pop_back()
		var s: int = seg[0]
		var e: int = seg[1]
		var max_d := 0.0
		var idx := -1
		for i in range(s + 1, e):
			var d := Geometry2D.get_closest_point_to_segment(pts[i], pts[s], pts[e]).distance_to(pts[i])
			if d > max_d:
				max_d = d
				idx = i
		if idx != -1 and max_d > tolerance:
			keep[idx] = 1
			stack.append([s, idx])
			stack.append([idx, e])
	var out := PackedVector2Array()
	for i in pts.size():
		if keep[i] == 1:
			out.append(pts[i])
	return out
