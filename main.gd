extends Node2D

enum Stage { BODY, WEAPON }

const COLORS := [Color("ff5d73"), Color("4dd0e1"), Color("ffd166"), Color("95e06c")]

@onready var canvas: DrawCanvas = $DrawCanvas
@onready var panel: PanelContainer = $UI/Root/Panel
@onready var vbox: VBoxContainer = $UI/Root/Panel/VBox
@onready var status: Label = $UI/Root/Panel/VBox/StatusLabel
@onready var main_btn: Button = $UI/Root/Panel/VBox/Buttons/SpawnButton
@onready var clear_btn: Button = $UI/Root/Panel/VBox/Buttons/ClearButton

var undo_btn: Button
var menu_btn: Button
var back_btn: Button

var stage := Stage.BODY
var body_data := {}
var name_edit: LineEdit

func _ready() -> void:
	$UI.layer = 2
	canvas.attach_required = false   # weapon type is chosen later, so draw it anywhere
	_build_ui()
	canvas.stroke_changed.connect(_on_stroke_changed)
	main_btn.pressed.connect(_on_main)
	clear_btn.pressed.connect(_on_clear)
	undo_btn.pressed.connect(canvas.undo_last_stroke)
	back_btn.pressed.connect(_on_back)
	menu_btn.pressed.connect(func(): get_tree().change_scene_to_file("res://menu.tscn"))
	_set_stage(Stage.BODY)

func _build_ui() -> void:
	panel.custom_minimum_size.x = 300
	panel.add_theme_stylebox_override("panel", UiStyle.panel(UiStyle.BLUE, UiStyle.NAVY, 20))
	vbox.add_theme_constant_override("separation", 14)

	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status.add_theme_font_size_override("font_size", 22)
	status.add_theme_color_override("font_color", Color("e6e9ef"))
	UiStyle.outline(status, 4)
	status.size_flags_vertical = Control.SIZE_EXPAND_FILL
	status.vertical_alignment = VERTICAL_ALIGNMENT_TOP

	var old_row := main_btn.get_parent()
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	vbox.add_child(column)

	undo_btn = Button.new()
	undo_btn.text = "Undo"
	back_btn = Button.new()
	back_btn.text = "Back to body"
	menu_btn = Button.new()
	menu_btn.text = "Menu"

	column.add_child(undo_btn)
	clear_btn.reparent(column)
	column.add_child(back_btn)
	column.add_child(menu_btn)
	main_btn.reparent(column)
	column.move_child(main_btn, 0)
	old_row.queue_free()

	name_edit = LineEdit.new()
	name_edit.placeholder_text = "Name your top"
	name_edit.max_length = 14
	name_edit.custom_minimum_size.y = 52
	name_edit.add_theme_font_size_override("font_size", 24)
	column.add_child(name_edit)
	column.move_child(name_edit, 1)   # right under the main button
	
	UiStyle.style_button(main_btn, UiStyle.GREEN.darkened(0.15), 80, 26)
	UiStyle.style_button(undo_btn, UiStyle.BLUE.darkened(0.1), 56, 24)
	UiStyle.style_button(clear_btn, UiStyle.RED, 56, 24)
	UiStyle.style_button(back_btn, UiStyle.LAVENDER, 56, 22)
	UiStyle.style_button(menu_btn, UiStyle.PURPLE.lightened(0.2), 56, 24)

func _set_stage(s: Stage) -> void:
	stage = s
	var weapon_stage := s == Stage.WEAPON
	back_btn.visible = weapon_stage
	name_edit.visible = weapon_stage
	if weapon_stage:
		main_btn.text = "SAVE TOP"
		main_btn.disabled = false
		_update_weapon_status()
	else:
		main_btn.text = "NEXT: WEAPON"
		_on_stroke_changed(canvas.build_shape().size() > 0)

func _on_main() -> void:
	if stage == Stage.BODY:
		var shape := canvas.build_shape()
		if shape.is_empty():
			return
		body_data = shape
		canvas.enter_weapon_mode()
		_set_stage(Stage.WEAPON)
	else:
		_save()

func _on_clear() -> void:
	if stage == Stage.WEAPON:
		canvas.clear_weapon_strokes()
	else:
		canvas.clear_drawing()

func _on_back() -> void:
	canvas.exit_weapon_mode()
	_set_stage(Stage.BODY)

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
	var n := canvas.strokes.size() - canvas.body_count
	status.text = "Step 2: weapon shape (optional)\nDraw it anywhere.\nMax size: %d px\nStrokes: %d\n\nYou choose the weapon type before battle." % [
		int(DrawCanvas.WEAPON_MAX_SIZE), maxi(n, 0)]

func _save() -> void:
	var wstrokes: Array = []
	for s in canvas.weapon_strokes():
		wstrokes.append(ShapeUtils.offset_points(s, -body_data["center"]))
	var weapon := {}
	if not wstrokes.is_empty():
		weapon = {"type": WeaponDefs.Type.NONE, "strokes": wstrokes}

	var color: Color = COLORS[GameData.tops.size() % COLORS.size()]
	var tname := name_edit.text.strip_edges()
	if tname.is_empty():
		tname = "Top %d" % (GameData.tops.size() + 1)
	var ok := GameData.add_top(body_data["area"], color, body_data["strokes_local"], weapon, tname)
	if ok:
		name_edit.clear()
		canvas.clear_drawing()
		_set_stage(Stage.BODY)
		status.text = "Saved! You have %d / %d tops.\nDraw another or go to Menu." % [
			GameData.tops.size(), GameData.MAX_TOPS]
	else:
		status.text = "Top storage is full (%d). Delete one in the Battle screen." % GameData.MAX_TOPS
