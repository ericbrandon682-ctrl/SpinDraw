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
var name_edit: LineEdit

var stage := Stage.BODY
var body_data := {}
var edit_index := -1

func _ready() -> void:
	RenderingServer.set_default_clear_color(Color("07070f"))
	canvas.attach_required = false   # weapon type is chosen before battle
	_build_ui()
	canvas.stroke_changed.connect(_on_stroke_changed)
	main_btn.pressed.connect(_on_main)
	clear_btn.pressed.connect(_on_clear)
	undo_btn.pressed.connect(canvas.undo_last_stroke)
	back_btn.pressed.connect(_on_back)
	menu_btn.pressed.connect(_to_storage)
	_set_stage(Stage.BODY)

	edit_index = GameData.editing_index
	if edit_index >= 0 and edit_index < GameData.tops.size():
		_load_existing(edit_index)
	else:
		edit_index = -1

func _to_storage() -> void:
	GameData.editing_index = -1
	get_tree().change_scene_to_file("res://Storage.tscn")

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
	menu_btn.text = "Storage"

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
	name_edit.custom_minimum_size.y = 56
	name_edit.alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_edit.add_theme_font_size_override("font_size", 24)
	name_edit.add_theme_color_override("font_color", UiStyle.YELLOW)
	name_edit.add_theme_color_override("font_placeholder_color", Color("7a7a96"))
	name_edit.add_theme_color_override("caret_color", UiStyle.WHITE)
	var name_normal := UiStyle.panel(UiStyle.YELLOW, UiStyle.BLACK, 8)
	name_normal.set_border_width_all(4)
	var name_focus := UiStyle.panel(UiStyle.WHITE, UiStyle.BLACK, 8)
	name_focus.set_border_width_all(4)
	name_edit.add_theme_stylebox_override("normal", name_normal)
	name_edit.add_theme_stylebox_override("focus", name_focus)
	column.add_child(name_edit)
	column.move_child(name_edit, 1)
	UiStyle.style_button(main_btn, UiStyle.GREEN, 80, 26)
	UiStyle.style_button(undo_btn, UiStyle.BLUE, 56, 24)
	UiStyle.style_button(clear_btn, UiStyle.RED, 56, 24)
	UiStyle.style_button(back_btn, UiStyle.LAVENDER, 56, 22)
	UiStyle.style_button(menu_btn, UiStyle.PURPLE, 56, 24)

func _load_existing(i: int) -> void:
	var data: Dictionary = GameData.tops[i]
	var wstrokes: Array = data.get("weapon", {}).get("strokes", [])
	canvas.load_shape(data["strokes"], wstrokes)
	name_edit.text = str(data.get("name", ""))
	if not wstrokes.is_empty():
		body_data = canvas.build_shape()
		_set_stage(Stage.WEAPON)
	else:
		_on_stroke_changed(canvas.build_shape().size() > 0)

func _set_stage(s: Stage) -> void:
	stage = s
	var weapon_stage := s == Stage.WEAPON
	back_btn.visible = weapon_stage
	if weapon_stage:
		main_btn.text = "SAVE TOP"
		main_btn.disabled = false
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

# ---------- Status ----------

func _on_stroke_changed(is_valid: bool) -> void:
	if stage == Stage.WEAPON:
		_update_weapon_status()
		return
	main_btn.disabled = not is_valid
	var head := "Editing top\n\n" if edit_index >= 0 else ""
	if is_valid:
		var s := TopStats.from_area(canvas.build_shape()["area"])
		status.text = "%sStep 1: body\n\nHP: %d\nMass: %.1f\nSpeed: %d\nSpin: %d RPM" % [
			head, s.max_hp, s.mass, int(s.max_speed), s.rpm()]
	elif not canvas.is_drawing and canvas.has_strokes():
		status.text = "Keep drawing, or shape is too small/flat"
	else:
		status.text = "Step 1: draw your top's body, then press Next"

func _update_weapon_status() -> void:
	var n := canvas.strokes.size() - canvas.body_count
	status.text = "Step 2: weapon (optional)\nYour body is hidden.\nDraw the weapon on its own.\nMax size: %d px\nStrokes: %d\n\nYou choose the weapon type before battle." % [
		int(DrawCanvas.WEAPON_MAX_SIZE), maxi(n, 0)]
# ---------- Save ----------

func _save() -> void:
	var raw: Array = canvas.weapon_strokes()
	var mn := Vector2(1000000.0, 1000000.0)
	var mx := Vector2(-1000000.0, -1000000.0)
	for s in raw:
		for p in s:
			mn = mn.min(p)
			mx = mx.max(p)
	var wcenter := (mn + mx) * 0.5
	var wstrokes: Array = []
	for s in raw:
		wstrokes.append(ShapeUtils.offset_points(s, -wcenter))
	var weapon := {}
	if not wstrokes.is_empty():
		weapon = {"type": WeaponDefs.Type.NONE, "strokes": wstrokes}

	var tname := name_edit.text.strip_edges()
	if edit_index >= 0:
		if tname.is_empty():
			tname = "Top %d" % (edit_index + 1)
		GameData.update_top(edit_index, body_data["area"], body_data["strokes_local"], weapon, tname)
	else:
		if tname.is_empty():
			tname = "Top %d" % (GameData.tops.size() + 1)
		var color: Color = COLORS[GameData.tops.size() % COLORS.size()]
		var ok := GameData.add_top(body_data["area"], color, body_data["strokes_local"], weapon, tname)
		if not ok:
			status.text = "Storage is full (%d). Delete a top in Storage first." % GameData.MAX_TOPS
			return
	_to_storage()
