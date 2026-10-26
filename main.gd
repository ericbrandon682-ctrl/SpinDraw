extends Node2D

const COLORS := [Color("ff5d73"), Color("4dd0e1"), Color("ffd166"), Color("95e06c")]

@onready var canvas: DrawCanvas = $DrawCanvas
@onready var panel: PanelContainer = $UI/Root/Panel
@onready var vbox: VBoxContainer = $UI/Root/Panel/VBox
@onready var status: Label = $UI/Root/Panel/VBox/StatusLabel
@onready var save_btn: Button = $UI/Root/Panel/VBox/Buttons/SpawnButton
@onready var clear_btn: Button = $UI/Root/Panel/VBox/Buttons/ClearButton

var undo_btn: Button
var menu_btn: Button

func _ready() -> void:
	_build_ui()
	save_btn.disabled = true
	status.text = "Draw one or more strokes, then press Save"
	canvas.stroke_changed.connect(_on_stroke_changed)
	save_btn.pressed.connect(_on_save)
	clear_btn.pressed.connect(canvas.clear_drawing)
	undo_btn.pressed.connect(canvas.undo_last_stroke)
	menu_btn.pressed.connect(func(): get_tree().change_scene_to_file("res://menu.tscn"))

func _build_ui() -> void:
	panel.custom_minimum_size.x = 300
	panel.add_theme_stylebox_override("panel", UiStyle.box(Color("1f2229"), 0, 22))
	vbox.add_theme_constant_override("separation", 16)

	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status.add_theme_font_size_override("font_size", 24)
	status.add_theme_color_override("font_color", Color("e6e9ef"))
	status.size_flags_vertical = Control.SIZE_EXPAND_FILL
	status.vertical_alignment = VERTICAL_ALIGNMENT_TOP

	var old_row := save_btn.get_parent()
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	vbox.add_child(column)

	undo_btn = Button.new()
	undo_btn.text = "Undo"
	menu_btn = Button.new()
	menu_btn.text = "Menu"
	column.add_child(undo_btn)
	save_btn.reparent(column)
	clear_btn.reparent(column)
	column.add_child(menu_btn)
	column.move_child(save_btn, 0)  # order: Save, Undo, Clear, Menu
	old_row.queue_free()

	save_btn.text = "SAVE TOP"
	UiStyle.style_button(save_btn, Color("2fbf71"), 96)
	UiStyle.style_button(undo_btn, Color("4a6fa5"), 68)
	UiStyle.style_button(clear_btn, Color("c94f5a"), 68)
	UiStyle.style_button(menu_btn, Color("5a5f6b"), 68)

func _on_stroke_changed(is_valid: bool) -> void:
	save_btn.disabled = not is_valid
	if is_valid:
		var s := TopStats.from_area(canvas.build_shape()["area"])
		status.text = "HP: %d\nMass: %.1f\nSpeed: %d\nSpin: %d RPM" % [
			s.max_hp, s.mass, int(s.max_speed), s.rpm()]
	elif not canvas.is_drawing and canvas.has_strokes():
		status.text = "Keep drawing, or shape is too small/flat"
	elif not canvas.has_strokes():
		status.text = "Draw one or more strokes, then press Save"

func _on_save() -> void:
	var shape := canvas.build_shape()
	if shape.is_empty():
		return
	var color: Color = COLORS[GameData.tops.size() % COLORS.size()]
	var ok := GameData.add_top(shape["area"], color, shape["strokes_local"])
	if ok:
		canvas.clear_drawing()
		status.text = "Saved! You have %d / %d tops.\nDraw another or go to Menu." % [
			GameData.tops.size(), GameData.MAX_TOPS]
	else:
		status.text = "Top storage is full (%d). Delete one in the Battle screen." % GameData.MAX_TOPS
