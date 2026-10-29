extends Control

const TITLE := "SPIN DRAW"
const RAINBOW := [Color("ff004d"), Color("ffa300"), Color("ffec27"), Color("00e436"),
		Color("29adff"), Color("83769c"), Color("ff77a8"), Color("ffec27"), Color("00e436")]
const HORIZON := 430.0

var t := 0.0
var stars: Array = []
var tops: Array = []

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	for i in 70:
		stars.append({"p": Vector2(randf() * 1280.0, randf() * 400.0),
				"s": randf() * TAU, "big": randf() < 0.2})
	for i in 5:
		tops.append({
			"p": Vector2(randf_range(80, 1200), randf_range(250, 650)),
			"v": Vector2.RIGHT.rotated(randf() * TAU) * randf_range(40, 90),
			"a": randf() * TAU, "r": randf_range(22, 40),
			"c": RAINBOW[i * 2 % RAINBOW.size()]})

	var center := CenterContainer.new()
	add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.offset_top = 230   # leaves room for the title

	var box := VBoxContainer.new()
	box.custom_minimum_size.x = 460
	box.add_theme_constant_override("separation", 20)
	center.add_child(box)

	var count := Label.new()
	count.text = "SAVED TOPS: %d / %d" % [GameData.tops.size(), GameData.MAX_TOPS]
	count.add_theme_font_size_override("font_size", 26)
	count.add_theme_color_override("font_color", UiStyle.YELLOW)
	UiStyle.outline(count)
	count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(count)

	var draw_btn := UiStyle.make_button("> DRAW <", UiStyle.GREEN.darkened(0.15), 96, 36)
	draw_btn.pressed.connect(func(): get_tree().change_scene_to_file("res://main.tscn"))
	box.add_child(draw_btn)

	var battle_btn := UiStyle.make_button("> BATTLE <", UiStyle.RED, 96, 36)
	battle_btn.disabled = GameData.tops.is_empty()
	battle_btn.pressed.connect(func(): get_tree().change_scene_to_file("res://battle.tscn"))
	box.add_child(battle_btn)

	if GameData.tops.is_empty():
		count.text += "\nDRAW A TOP TO UNLOCK BATTLE"

func _process(delta: float) -> void:
	t += delta
	for tp in tops:
		tp["p"] += tp["v"] * delta
		tp["a"] += delta * 6.0
		if tp["p"].x < 40.0 or tp["p"].x > 1240.0:
			tp["v"].x *= -1.0
		if tp["p"].y < 240.0 or tp["p"].y > 690.0:
			tp["v"].y *= -1.0
	queue_redraw()

func _draw() -> void:
	# Sky
	draw_rect(Rect2(0, 0, 1280, 720), Color("120a2e"))
	for i in 6:
		draw_rect(Rect2(0, i * 72.0, 1280, 72), Color("1d0b3a").lerp(Color("5a1a6b"), i / 6.0))

	# Stars (twinkle)
	for s in stars:
		var on := sin(t * 3.0 + s["s"]) > -0.3
		if on:
			var size := 6.0 if s["big"] else 3.0
			draw_rect(Rect2(s["p"].round(), Vector2(size, size)), Color.WHITE)

	# Striped sun
	var sun := Vector2(640, HORIZON)
	draw_circle(sun, 150.0, UiStyle.ORANGE)
	draw_circle(sun, 110.0, UiStyle.PINK)
	for i in 5:
		draw_rect(Rect2(490, HORIZON - 150.0 + i * 26.0 + 20.0, 300, 6 + i * 3), Color("1d0b3a"))

	# Ground and perspective grid
	draw_rect(Rect2(0, HORIZON, 1280, 720 - HORIZON), Color("0d0626"))
	var grid := UiStyle.BLUE
	grid.a = 0.7
	for i in range(-12, 13):
		draw_line(Vector2(640, HORIZON), Vector2(640 + i * 170.0, 720), grid, 2.0)
	var phase := fposmod(t * 0.4, 1.0)
	for j in 7:
		var u := (j + phase) / 7.0
		draw_line(Vector2(0, HORIZON + u * u * 290.0), Vector2(1280, HORIZON + u * u * 290.0), grid, 2.0)
	draw_line(Vector2(0, HORIZON), Vector2(1280, HORIZON), UiStyle.PINK, 4.0)

	# Floating spinning tops
	for tp in tops:
		var pts := PackedVector2Array()
		for k in 12:
			var r: float = tp["r"] if k % 2 == 0 else tp["r"] * 0.45
			pts.append(tp["p"] + Vector2.RIGHT.rotated(tp["a"] + TAU * k / 12.0) * r)
		draw_colored_polygon(pts, tp["c"])
		draw_circle(tp["p"], 5.0, Color.WHITE)

	# Rainbow title, each letter bobbing
	var font := get_theme_default_font()
	var size := 92
	var total := 0.0
	for ch in TITLE:
		total += font.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var x := (1280.0 - total) * 0.5
	for i in TITLE.length():
		var ch := TITLE[i]
		var w := font.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
		var pos := Vector2(x, 150.0 + sin(t * 3.0 + i * 0.6) * 8.0).round()
		draw_string(font, pos + Vector2(6, 6), ch, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color("0b0b1e"))
		draw_string(font, pos, ch, HORIZONTAL_ALIGNMENT_LEFT, -1, size, RAINBOW[i % RAINBOW.size()])
		x += w

	# Blinking tagline
	if fmod(t, 1.2) < 0.8:
		draw_string(font, Vector2(0, 200), "- DRAW - FIGHT - WIN -", HORIZONTAL_ALIGNMENT_CENTER,
				1280, 26, UiStyle.YELLOW)
