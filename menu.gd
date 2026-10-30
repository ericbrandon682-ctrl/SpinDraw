extends Control

const TITLE := "SPIN DRAW"
const TILE := 40.0
const GRASS_A := Color("4f9d3a")
const GRASS_B := Color("48913a")
const TUFT := Color("2f6f2a")
const LETTERS := [Color("ffd23f"), Color("ffffff"), Color("ffd23f"), Color("ff8a2b")]
const FLAVOR := [
	"* A blank page stands in your way.",
	"* You feel DETERMINATION to draw.",
	"* The tops are spinning with anticipation.",
	"* Smells like fresh ink.",
	"* Your pencil trembles. It wants a fight.",
]

var t := 0.0
var typed := 0.0
var tops: Array = []
var flavor: Label

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var cols := [UiStyle.RED, UiStyle.BLUE, UiStyle.YELLOW, UiStyle.PINK, UiStyle.PURPLE]
	for i in 5:
		tops.append({
			"p": Vector2(randf_range(80, 1200), randf_range(250, 640)),
			"v": Vector2.RIGHT.rotated(randf() * TAU) * randf_range(40, 90),
			"a": randf() * TAU, "r": randf_range(24, 40), "c": cols[i]})

	var center := CenterContainer.new()
	add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.offset_top = 230
	center.offset_bottom = -120

	var box := VBoxContainer.new()
	box.custom_minimum_size.x = 460
	box.add_theme_constant_override("separation", 18)
	center.add_child(box)

	var count := Label.new()
	count.text = "SAVED TOPS: %d / %d" % [GameData.tops.size(), GameData.MAX_TOPS]
	if GameData.tops.is_empty():
		count.text += "\nDRAW A TOP TO UNLOCK BATTLE"
	count.add_theme_font_size_override("font_size", 24)
	count.add_theme_color_override("font_color", UiStyle.YELLOW)
	UiStyle.outline(count, 8)
	count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(count)

	var draw_btn := UiStyle.make_button("DRAW", UiStyle.GREEN, 84, 36)
	draw_btn.pressed.connect(func(): get_tree().change_scene_to_file("res://Storage.tscn"))
	box.add_child(draw_btn)

	var battle_btn := UiStyle.make_button("BATTLE", UiStyle.RED, 84, 36)
	battle_btn.disabled = GameData.tops.is_empty()
	battle_btn.pressed.connect(func(): get_tree().change_scene_to_file("res://battle.tscn"))
	box.add_child(battle_btn)

	# Undertale-style dialogue box with typewriter text
	var dlg := PanelContainer.new()
	dlg.add_theme_stylebox_override("panel", UiStyle.panel(UiStyle.WHITE, UiStyle.BLACK, 16))
	add_child(dlg)
	dlg.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	dlg.offset_left = 160
	dlg.offset_right = -160
	dlg.offset_top = -104
	dlg.offset_bottom = -20
	flavor = Label.new()
	flavor.text = FLAVOR[randi() % FLAVOR.size()]
	flavor.visible_characters = 0
	flavor.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	flavor.add_theme_font_size_override("font_size", 26)
	dlg.add_child(flavor)

func _process(delta: float) -> void:
	t += delta
	typed += delta * 28.0
	flavor.visible_characters = int(typed)
	for tp in tops:
		tp["p"] += tp["v"] * delta
		tp["a"] += delta * 5.0
		if tp["p"].x < 40.0 or tp["p"].x > 1240.0:
			tp["v"].x *= -1.0
		if tp["p"].y < 250.0 or tp["p"].y > 650.0:
			tp["v"].y *= -1.0
	queue_redraw()

func _sparkle(p: Vector2, s: float) -> void:
	draw_rect(Rect2(p - Vector2(s * 0.5, s * 3.0), Vector2(s, s * 6.0)), Color.WHITE)
	draw_rect(Rect2(p - Vector2(s * 3.0, s * 0.5), Vector2(s * 6.0, s)), Color.WHITE)

func _draw() -> void:
	# Grass field
	draw_rect(Rect2(0, 0, 1280, 720), GRASS_A)
	for gx in 32:
		for gy in 18:
			var o := Vector2(gx, gy) * TILE
			if (gx + gy) % 2 == 1:
				draw_rect(Rect2(o, Vector2(TILE, TILE)), GRASS_B)
			var h := (gx * 73856093) ^ (gy * 19349663)
			if h % 6 == 0:
				var p := o + Vector2(10 + (h >> 3) % 17, 12 + (h >> 5) % 15)
				draw_rect(Rect2(p, Vector2(4, 8)), TUFT)
				draw_rect(Rect2(p + Vector2(8, 3), Vector2(4, 6)), TUFT)

	# Zelda hearts (top left) and rupee counter (top right)
	var heart := UiStyle.heart_texture(UiStyle.RED)
	for i in 3:
		draw_texture_rect(heart, Rect2(Vector2(24 + i * 40, 24), Vector2(28, 24)), false)
	var font := get_theme_default_font()
	var gem := PackedVector2Array([Vector2(1190, 22), Vector2(1202, 34), Vector2(1202, 44),
			Vector2(1190, 56), Vector2(1178, 44), Vector2(1178, 34)])
	draw_colored_polygon(gem, Color("3ddc84"))
	var gem_line := gem.duplicate()
	gem_line.append(gem[0])
	draw_polyline(gem_line, Color.BLACK, 3.0)
	draw_string_outline(font, Vector2(1214, 50), "x%d" % GameData.tops.size(),
			HORIZONTAL_ALIGNMENT_LEFT, -1, 28, 8, Color.BLACK)
	draw_string(font, Vector2(1214, 50), "x%d" % GameData.tops.size(),
			HORIZONTAL_ALIGNMENT_LEFT, -1, 28, Color.WHITE)

	# Floating spinning stars
	for tp in tops:
		var pts := PackedVector2Array()
		for k in 12:
			var r: float = tp["r"] if k % 2 == 0 else tp["r"] * 0.45
			pts.append(tp["p"] + Vector2.RIGHT.rotated(tp["a"] + TAU * k / 12.0) * r)
		draw_colored_polygon(pts, tp["c"])
		pts.append(pts[0])
		draw_polyline(pts, Color.BLACK, 4.0)
		draw_circle(tp["p"], 5.0, Color.WHITE)

	# Gold bobbing title
	var title_size := 88
	var total := 0.0
	for ch in TITLE:
		total += font.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, title_size).x
	var x := (1280.0 - total) * 0.5
	for i in TITLE.length():
		var ch := TITLE[i]
		var w := font.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, title_size).x
		var pos := Vector2(x, 160.0 + sin(t * 3.0 + i * 0.6) * 8.0).round()
		draw_string_outline(font, pos, ch, HORIZONTAL_ALIGNMENT_LEFT, -1, title_size, 16, Color.BLACK)
		draw_string(font, pos, ch, HORIZONTAL_ALIGNMENT_LEFT, -1, title_size, LETTERS[i % LETTERS.size()])
		x += w

	# Twinkles around the title
	if fmod(t, 1.0) < 0.5:
		_sparkle(Vector2(360, 95), 4.0)
		_sparkle(Vector2(930, 130), 3.0)
	else:
		_sparkle(Vector2(900, 90), 4.0)
		_sparkle(Vector2(380, 140), 3.0)
