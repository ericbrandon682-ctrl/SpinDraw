extends Node2D

const COLORS := [Color("ff5d73"), Color("4dd0e1"), Color("ffd166"), Color("95e06c")]
const BATTLE_SCALE := 0.35

@onready var canvas: DrawCanvas = $DrawCanvas
@onready var tops: Node2D = $Tops
@onready var panel: PanelContainer = $UI/Root/Panel
@onready var vbox: VBoxContainer = $UI/Root/Panel/VBox
@onready var status: Label = $UI/Root/Panel/VBox/StatusLabel
@onready var spawn_btn: Button = $UI/Root/Panel/VBox/Buttons/SpawnButton
@onready var clear_btn: Button = $UI/Root/Panel/VBox/Buttons/ClearButton

var undo_btn: Button
var _spawn_count := 0

func _ready() -> void:
	_build_ui()
	spawn_btn.disabled = true
	status.text = "Draw one or more strokes, then press Spawn"
	canvas.stroke_changed.connect(_on_stroke_changed)
	spawn_btn.pressed.connect(_on_spawn)
	clear_btn.pressed.connect(_on_clear)
	undo_btn.pressed.connect(canvas.undo_last_stroke)

# ---------- UI styling ----------

func _build_ui() -> void:
	# Panel look and size
	panel.custom_minimum_size.x = 300
	panel.add_theme_stylebox_override("panel", _box(Color("1f2229"), 0, 22))

	vbox.add_theme_constant_override("separation", 20)

	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status.add_theme_font_size_override("font_size", 24)
	status.add_theme_color_override("font_color", Color("e6e9ef"))
	status.size_flags_vertical = Control.SIZE_EXPAND_FILL
	status.vertical_alignment = VERTICAL_ALIGNMENT_TOP

	# Replace the side-by-side HBox with a vertical column of buttons
	var old_row := spawn_btn.get_parent()
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 14)
	vbox.add_child(column)

	undo_btn = Button.new()
	undo_btn.text = "Undo"
	column.add_child(undo_btn)

	spawn_btn.reparent(column)
	clear_btn.reparent(column)
	column.move_child(spawn_btn, 0)  # order: Spawn, Undo, Clear
	old_row.queue_free()

	spawn_btn.text = "SPAWN"
	_style_button(spawn_btn, Color("2fbf71"), 100)   # green, main action
	_style_button(undo_btn, Color("4a6fa5"), 76)     # blue
	_style_button(clear_btn, Color("c94f5a"), 76)    # red

func _box(color: Color, radius: int = 16, margin: int = 12) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.set_corner_radius_all(radius)
	sb.set_content_margin_all(margin)
	return sb

func _style_button(btn: Button, color: Color, height: float) -> void:
	btn.custom_minimum_size = Vector2(0, height)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.add_theme_font_size_override("font_size", 28)
	btn.add_theme_stylebox_override("normal", _box(color))
	btn.add_theme_stylebox_override("hover", _box(color.lightened(0.15)))
	btn.add_theme_stylebox_override("pressed", _box(color.darkened(0.25)))
	btn.add_theme_stylebox_override("disabled", _box(Color("3a3d45")))
	btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	btn.add_theme_color_override("font_color", Color.WHITE)
	btn.add_theme_color_override("font_hover_color", Color.WHITE)
	btn.add_theme_color_override("font_pressed_color", Color.WHITE)
	btn.add_theme_color_override("font_disabled_color", Color(1, 1, 1, 0.3))

# ---------- Game logic ----------

func _on_stroke_changed(is_valid: bool) -> void:
	spawn_btn.disabled = not is_valid
	if is_valid:
		var s := TopStats.from_area(canvas.build_shape()["area"])
		status.text = "HP: %d\nMass: %.1f\nSpeed: %d\nSpin: %d RPM" % [
			s.max_hp, s.mass, int(s.max_speed), s.rpm()]
	elif not canvas.is_drawing and canvas.has_strokes():
		status.text = "Keep drawing, or shape is too small/flat"
	elif not canvas.has_strokes():
		status.text = "Draw one or more strokes, then press Spawn"

func _scale_points(pts: PackedVector2Array, f: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	out.resize(pts.size())
	for i in pts.size():
		out[i] = pts[i] * f
	return out

func _on_spawn() -> void:
	var shape := canvas.build_shape()
	if shape.is_empty():
		return
	var stats := TopStats.from_area(shape["area"])

	var hull_small := _scale_points(shape["hull_local"], BATTLE_SCALE)
	var strokes_small: Array = []
	for s in shape["strokes_local"]:
		strokes_small.append(_scale_points(s, BATTLE_SCALE))

	var top := Top.new()
	top.setup(hull_small, strokes_small, stats,
			COLORS[_spawn_count % COLORS.size()])
	top.position = canvas.to_global(shape["center"])
	tops.add_child(top)
	_spawn_count += 1
	canvas.clear_drawing()
	status.text = "Spawned!\nHP: %d\nSpin: %d RPM" % [stats.max_hp, stats.rpm()]

func _on_clear() -> void:
	canvas.clear_drawing()
	for t in tops.get_children():
		t.queue_free()
	_spawn_count = 0
	status.text = "Cleared. Draw a new shape."
