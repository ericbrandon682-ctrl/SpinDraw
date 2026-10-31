class_name TopPreview
extends Control

const WEAPON_COLOR := Color("ffb347")

var data: Dictionary = {}
var angle := 0.0

func _process(delta: float) -> void:
	angle += delta * 1.5
	queue_redraw()

func _extent(group: Array) -> float:
	var r := 1.0
	for s in group:
		for p in s:
			r = maxf(r, p.length())
	return r

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("0b0b1e"))
	draw_rect(Rect2(Vector2.ZERO, size), UiStyle.LAVENDER, false, 4.0)
	if data.is_empty():
		return

	var body: Array = data["strokes"]
	var wdata: Dictionary = data.get("weapon", {})
	var weapon: Array = wdata.get("strokes", [])
	var has_weapon: bool = not weapon.is_empty()

	# Body (spinning)
	var body_w: float = size.x * (0.62 if has_weapon else 1.0)
	var kb: float = (minf(body_w, size.y) * 0.5 - 14.0) / _extent(body)
	draw_set_transform(Vector2(body_w * 0.5, size.y * 0.5), angle, Vector2(kb, kb))
	for s in body:
		draw_polyline(s, data["color"], 5.0 / kb)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	# Weapon display (own slot, slowly tilting)
	if has_weapon:
		draw_line(Vector2(body_w, 10), Vector2(body_w, size.y - 10), UiStyle.LAVENDER, 2.0)
		var slot_w: float = size.x - body_w
		var kw: float = (minf(slot_w, size.y) * 0.5 - 14.0) / _extent(weapon)
		draw_set_transform(Vector2(body_w + slot_w * 0.5, size.y * 0.5),
				sin(angle) * 0.3, Vector2(kw, kw))
		for s in weapon:
			draw_polyline(s, WEAPON_COLOR, 5.0 / kw)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
