class_name Fx
extends RefCounted

static func _square(size: float, color: Color) -> Polygon2D:
	var p := Polygon2D.new()
	var h := size * 0.5
	p.polygon = PackedVector2Array([Vector2(-h, -h), Vector2(h, -h), Vector2(h, h), Vector2(-h, h)])
	p.color = color
	p.z_index = 25
	return p

static func burst(parent: Node, pos: Vector2, color: Color, count: int = 8, dist: float = 46.0) -> void:
	if parent == null:
		return
	for i in count:
		var sq := _square(randf_range(5.0, 9.0), color if i % 2 == 0 else Color.WHITE)
		parent.add_child(sq)
		sq.global_position = pos
		var dir := Vector2.RIGHT.rotated(randf() * TAU)
		var tw := sq.create_tween()
		tw.set_parallel(true)
		tw.tween_property(sq, "position", sq.position + dir * dist * randf_range(0.5, 1.0), 0.35) \
				.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(sq, "modulate:a", 0.0, 0.35)
		tw.chain().tween_callback(sq.queue_free)

static func number(parent: Node, pos: Vector2, text: String, color: Color) -> void:
	if parent == null:
		return
	var l := Label.new()
	l.text = text
	l.z_index = 30
	l.add_theme_font_size_override("font_size", 30)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 8)
	parent.add_child(l)
	l.global_position = pos + Vector2(randf_range(-14.0, 14.0) - 16.0, -50.0)
	var y := l.position.y
	var tw := l.create_tween()
	tw.tween_property(l, "position:y", y - 30.0, 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "position:y", y - 14.0, 0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_interval(0.4)
	tw.tween_property(l, "modulate:a", 0.0, 0.2)
	tw.tween_callback(l.queue_free)

static func hit(parent: Node, pos: Vector2, amount: int) -> void:
	var big := amount >= 8
	burst(parent, pos, Color("ffd23f") if big else Color.WHITE, 10 if big else 5)
	number(parent, pos, str(amount), Color("ff4d4d") if big else Color.WHITE)

static func flash(host: Node, color: Color) -> void:
	var layer := CanvasLayer.new()
	layer.layer = 3
	var r := ColorRect.new()
	r.color = Color(color.r, color.g, color.b, 0.5)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(r)
	host.add_child(layer)
	r.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var tw := r.create_tween()
	tw.tween_property(r, "color:a", 0.0, 0.35)
	tw.tween_callback(layer.queue_free)

static func banner(host: Node, text: String, color: Color) -> void:
	var layer := CanvasLayer.new()
	layer.layer = 3
	var l := Label.new()
	l.text = text
	l.position = Vector2(0, 250)
	l.size = Vector2(1280, 110)
	l.pivot_offset = Vector2(640, 55)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_size_override("font_size", 64)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 14)
	l.scale = Vector2(2.0, 2.0)
	l.modulate.a = 0.0
	layer.add_child(l)
	host.add_child(layer)
	var tw := l.create_tween()
	tw.set_parallel(true)
	tw.tween_property(l, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "modulate:a", 1.0, 0.15)
	tw.chain().tween_interval(0.9)
	tw.chain().tween_property(l, "modulate:a", 0.0, 0.3)
	tw.chain().tween_callback(layer.queue_free)
