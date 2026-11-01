class_name SwatchPicker
extends GridContainer

signal picked(color: Color)

const COLORS := [
	Color("ff5d73"), Color("ff8a2b"), Color("ffd23f"), Color("95e06c"), Color("2fd6a0"),
	Color("4dd0e1"), Color("4db8ff"), Color("a86bff"), Color("ff8fb8"), Color("ffffff"),
]

var current := Color.WHITE
var swatches: Array[Button] = []

func _init() -> void:
	columns = 5
	add_theme_constant_override("h_separation", 6)
	add_theme_constant_override("v_separation", 6)
	for c in COLORS:
		var b := Button.new()
		b.custom_minimum_size = Vector2(44, 38)
		b.focus_mode = Control.FOCUS_NONE
		b.pressed.connect(_on_pick.bind(c))
		add_child(b)
		swatches.append(b)
	_restyle()

func select(c: Color) -> void:
	current = c
	_restyle()

func _on_pick(c: Color) -> void:
	current = c
	_restyle()
	picked.emit(c)

func _restyle() -> void:
	for i in swatches.size():
		var sb := StyleBoxFlat.new()
		sb.bg_color = COLORS[i]
		sb.set_corner_radius_all(0)
		sb.set_border_width_all(4)
		sb.border_color = Color.WHITE if COLORS[i] == current else Color("07070f")
		sb.anti_aliasing = false
		for st in ["normal", "hover", "pressed"]:
			swatches[i].add_theme_stylebox_override(st, sb)
		swatches[i].add_theme_stylebox_override("focus", StyleBoxEmpty.new())
