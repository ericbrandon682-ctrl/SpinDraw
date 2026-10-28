extends Node2D

enum Stage { BODY, WEAPON }

const COLORS := [Color("ff5d73"), Color("4dd0e1"), Color("ffd166"), Color("95e06c")]
const BODY_GHOST := Color("7f8aa3")

@onready var canvas: DrawCanvas = $DrawCanvas
@onready var panel: PanelContainer = $UI/Root/Panel
@onready var vbox: VBoxContainer = $UI/Root/Panel/VBox
@onready var status: Label = $UI/Root/Panel/VBox/StatusLabel
@onready var main_btn: Button = $UI/Root/Panel/VBox/Buttons/SpawnButton
@onready var clear_btn: Button = $UI/Root/Panel/VBox/Buttons/ClearButton

var undo_btn: Button
var menu_btn: Button
var type_btn: Button
var back_btn: Button

var stage := Stage.BODY
var body_data := {}
var body_count := 0
var weapon_type: int = WeaponDefs.Type.THREE_BLADES

func _ready() -> void:
	_build_ui()
	canvas.stroke_changed.connect(_on_stroke_changed)
	main_btn.pressed.connect(_on_main)
	clear_btn.pressed.connect(_on_clear)
	undo_btn.pressed.connect(_on_undo)
	back_btn.pressed.connect(_on_back)
	type_btn.pressed.connect(_on_type)
	menu_btn.pressed.connect(func(): get_tree().change_scene_to_file("res://menu.tscn"))
	_set_stage(Stage.BODY)

func _build_ui() -> void:
	panel.custom_minimum_size.x = 300
	panel.add_theme_stylebox_override("panel", UiStyle.box(Color("1f2229"), 0, 22))
	vbox.add_theme_constant_override("separation", 14)

	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status.add_theme_font_size_override("font_size", 22)
	status.add_theme_color_override("font_color", Color("e6e9ef"))
	status.size_flags_vertical = Control.SIZE_EXPAND_FILL
	status.vertical_alignment = VERTICAL_ALIGNMENT_TOP

	var old_row := main_btn.get_parent()
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	vbox.add_child(column)

	type_btn = Button.new()
	undo_btn = Button.new()
	undo_btn.text = "Undo"
	back_btn = Button.new()
	back_btn.text = "Back to body"
	menu_btn = Button.new()
	menu_btn.text = "Menu"

	column.add_child(type_btn)
	column.add_child(undo_btn)
	clear_btn.reparent(column)
	column.add_child(back_btn)
	column.add_child(menu_btn)
	main_btn.reparent(column)
	column.move_child(main_btn, 0)   # order: main, type, undo, clear, back, menu
	old_row.queue_free()

	UiStyle.style_button(main_btn, Color("2fbf71"), 80, 26)
	UiStyle.style_button(type_btn, Color("d9a82f"), 56, 22)
	UiStyle.style_button(undo_btn, Color("4a6fa5"), 56, 24)
	UiStyle.style_button(clear_btn, Color("c94f5a"), 56, 24)
	UiStyle.style_button(back_btn, Color("5a5f6b"), 56, 22)
	UiStyle.style_button(menu_btn, Color("5a5f6b"), 56, 24)

func _set_stage(s: Stage) -> void:
	stage = s
	var weapon_stage := s == Stage.WEAPON
	type_btn.visible = weapon_stage
	back_btn.visible = weapon_stage
	if weapon_stage:
		main_btn.text = "SAVE TOP"
		main_btn.disabled = false
		_update_type_button()
		_update_weapon_status()
	else:
		main_btn.text = "NEXT: WEAPON"
		_on_stroke_changed(canvas.build_shape().size() > 0)

# ---------- Buttons ----------

func _on_main() -> void:
	if stage == Stage.BODY:
		var shape := canvas.build_shape()
		if shape.is_empty():
			return
		body_data = shape
		body_count = canvas.strokes.size()
		for l in canvas.lines:
			l.default_color = BODY_GHOST   # body turns grey, weapon is drawn in white
		_set_stage(Stage.WEAPON)
	else:
		_save()

func _on_type() -> void:
	weapon_type = weapon_type % 6 + 1   # cycles 1..6
	_update_type_button()
	_update_weapon_status()

func _update_type_button() -> void:
	type_btn.text = "Weapon: " + WeaponDefs.NAMES[weapon_type]

func _on_undo() -> void:
	if stage == Stage.WEAPON and canvas.strokes.size() <= body_count:
		return   # cannot undo body strokes from the weapon step
	canvas.undo_last_stroke()

func _on_clear() -> void:
	if stage == Stage.WEAPON:
		while canvas.strokes.size() > body_count:
			canvas.undo_last_stroke()
	else:
		canvas.clear_drawing()

func _on_back() -> void:
	while canvas.strokes.size() > body_count:
		canvas.undo_last_stroke()
	for l in canvas.lines:
		l.default_color = DrawCanvas.STROKE_COLOR
	_set_stage(Stage.BODY)

# ---------- Status ----------

func _on_stroke_changed(is_valid: bool) -> void:
	if stage == Stage.WEAPON:
		_update_weapon_status()
		return
	main_btn.disabled = not is_valid
	if is_valid:
		var s := TopStats.from_area(canvas.build_shape()["area"])
		status.text = "Step 1: body\n\nHP: %d\nMass: %.1f\nSpeed: %d\nSpin: %d RPM" % [
			s.max_hp, s.mass, int(s.max_speed), s.rpm()]
	elif not canvas.is_drawing and canvas.has_strokes():
		status.text = "Keep drawing, or shape is too small/flat"
	else:
		status.text = "Step 1: draw your top's body, then press Next"

func _update_weapon_status() -> void:
	var n := canvas.strokes.size() - body_count
	status.text = "Step 2: weapon (optional)\nStrokes: %d\n\n%s\n%s" % [
		maxi(n, 0), WeaponDefs.NAMES[weapon_type], WeaponDefs.DESCRIPTIONS[weapon_type]]

# ---------- Save ----------

func _save() -> void:
	var wstrokes: Array = []
	for i in range(body_count, canvas.strokes.size()):
		wstrokes.append(ShapeUtils.offset_points(canvas.strokes[i], -body_data["center"]))
	var weapon := {}
	if not wstrokes.is_empty():
		weapon = {"type": weapon_type, "strokes": wstrokes}

	var color: Color = COLORS[GameData.tops.size() % COLORS.size()]
	var ok := GameData.add_top(body_data["area"], color, body_data["strokes_local"], weapon)
	if ok:
		canvas.clear_drawing()
		_set_stage(Stage.BODY)
		status.text = "Saved! You have %d / %d tops.\nDraw another or go to Menu." % [
			GameData.tops.size(), GameData.MAX_TOPS]
	else:
		status.text = "Top storage is full (%d). Delete one in the Battle screen." % GameData.MAX_TOPS
