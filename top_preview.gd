class_name TopPreview
extends Control

const WEAPON_COLOR := Color("ffb347")

var data: Dictionary = {}
var angle := 0.0

func _process(delta: float) -> void:
	angle += delta * 1.5
	queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("0b0b1e"))
	draw_rect(Rect2(Vector2.ZERO, size), UiStyle.LAVENDER, false, 4.0)
	if data.is_empty():
		return
	var body: Array = data["strokes"]
	var weapon: Array = data.get("weapon", {}).get("strokes", [])

	var r := 1.0
	for group in [body, weapon]:
		for s in group:
			for p in s:
				r = maxf(r, p.length())
	var k := (minf(size.x, size.y) * 0.5 - 22.0) / r

	draw_set_transform(size * 0.5, angle, Vector2(k, k))
	for s in body:
		draw_polyline(s, data["color"], 5.0 / k)
	for s in weapon:
		draw_polyline(s, WEAPON_COLOR, 5.0 / k)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
