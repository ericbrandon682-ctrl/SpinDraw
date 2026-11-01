extends Node2D

enum Phase { BODY, WEAPON, PICK, WAIT }

const BODY_TIME := 45.0
const WEAPON_TIME := 20.0
const COLORS := [Color("ff5d73"), Color("4dd0e1")]
const WEAPON_TIPS := [
	"Your drawn blade is copied 3 times around the top. Hits fast on contact.",
	"One big blade. Slow, heavy hits with strong knockback.",
	"Hits slow the enemy's speed and spin for 2.5 seconds.",
	"Fires 3 bullets in a spiral. Each bullet is weaker. Bullets bounce once off a wall.",
	"Bullet bounces up to 6 times. If it loops back and hits you, it hits harder and turns on the enemy.",
	"Bullets set the enemy on fire, draining its HP for 4 seconds.",
]
const ULT_NAMES := ["Overdrive Impact", "Mach Drive", "Black Hole"]
const ULT_TIPS := [
	"Dash at the enemy. Each body hit takes a chunk of its max HP. Projectile tops fire several volleys. One use per match.",
	"6 seconds of super speed, 90% less damage taken and heavy rams. One use per match.",
	"A field pulls the enemy in, drains its HP over time and destroys its bullets. One use per match.",
]

var canvas: DrawCanvas
var panel: PanelContainer
var palette: SwatchPicker
var picker_layer: CanvasLayer
var phase := Phase.BODY
var time_left := BODY_TIME
var body_data := {}
var pending_top := {}
var has_weapon := false
var weapon_choice := 1
var my_done := false
var opp_done := false
var body_color := Color.WHITE
var weapon_color := Color("ffb347")

var timer_label: Label
var phase_label: Label
var status: Label
var next_btn: Button
var undo_btn: Button
var clear_btn: Button

func _ready() -> void:
	Audio.play_menu_music()
	RenderingServer.set_default_clear_color(Color("07070f"))
	canvas = DrawCanvas.new()
	canvas.attach_required = false
	add_child(canvas)
	canvas.stroke_changed.connect(_on_stroke)
	_build_ui()
	body_color = COLORS[0 if Net.is_host else 1]
	canvas.pen_color = body_color
	palette.select(body_color)
	Net.message.connect(_on_message)
	Net.peer_left.connect(_on_peer_left)
	_set_phase(Phase.BODY)

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	panel = PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiStyle.panel(UiStyle.PINK, UiStyle.NAVY, 16))
	layer.add_child(panel)
	panel.position = Vector2(980, 0)
	panel.size = Vector2(300, 720)
	panel.custom_minimum_size = Vector2(300, 720)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	panel.add_child(v)

	phase_label = Label.new()
	phase_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	phase_label.add_theme_font_size_override("font_size", 24)
	phase_label.add_theme_color_override("font_color", UiStyle.YELLOW)
	UiStyle.outline(phase_label, 5)
	v.add_child(phase_label)

	timer_label = Label.new()
	timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	timer_label.add_theme_font_size_override("font_size", 64)
	UiStyle.outline(timer_label, 10)
	v.add_child(timer_label)

	status = Label.new()
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status.size_flags_vertical = Control.SIZE_EXPAND_FILL
	status.add_theme_font_size_override("font_size", 18)
	UiStyle.outline(status, 4)
	v.add_child(status)

	palette = SwatchPicker.new()
	palette.picked.connect(_on_color)
	v.add_child(palette)

	next_btn = UiStyle.make_button("NEXT: WEAPON", UiStyle.GREEN, 66, 24, false)
	next_btn.pressed.connect(_advance)
	v.add_child(next_btn)
	undo_btn = UiStyle.make_button("Undo", UiStyle.BLUE, 52, 22, false)
	undo_btn.pressed.connect(canvas.undo_last_stroke)
	v.add_child(undo_btn)
	clear_btn = UiStyle.make_button("Clear", UiStyle.RED, 52, 22, false)
	clear_btn.pressed.connect(_clear)
	v.add_child(clear_btn)

func _set_phase(p: Phase) -> void:
	phase = p
	match p:
		Phase.BODY:
			time_left = BODY_TIME
			phase_label.text = "DRAW YOUR TOP!"
			next_btn.text = "NEXT: WEAPON"
			next_btn.disabled = true
			status.text = "Draw the body of your top. Hurry!"
		Phase.WEAPON:
			time_left = WEAPON_TIME
			phase_label.text = "DRAW YOUR WEAPON!"
			next_btn.text = "DONE"
			next_btn.disabled = false
			status.text = "Draw your weapon (optional). It shrinks to fit automatically."
		Phase.PICK:
			phase_label.text = "CHOOSE!"
			timer_label.text = ""
		Phase.WAIT:
			phase_label.text = "DONE!"
			timer_label.text = ""
			next_btn.visible = false
			undo_btn.visible = false
			clear_btn.visible = false
			palette.visible = false
			status.text = "Waiting for the opponent to finish drawing..."

func _process(delta: float) -> void:
	if phase == Phase.WAIT or phase == Phase.PICK:
		return
	time_left -= delta
	timer_label.text = str(ceili(maxf(time_left, 0.0)))
	timer_label.add_theme_color_override("font_color",
			UiStyle.RED if time_left < 10.0 else UiStyle.WHITE)
	if time_left <= 0.0:
		_advance()

func _on_stroke(is_valid: bool) -> void:
	if phase == Phase.BODY:
		next_btn.disabled = not is_valid

func _on_color(c: Color) -> void:
	if phase == Phase.BODY:
		body_color = c
	else:
		weapon_color = c
	canvas.set_pen(c)

func _clear() -> void:
	if phase == Phase.WEAPON:
		canvas.clear_weapon_strokes()
	else:
		canvas.clear_drawing()

func _advance() -> void:
	if phase == Phase.BODY:
		var shape := canvas.build_shape()
		if shape.is_empty():
			# Nothing usable drawn in time: give a plain round body
			var circle := PackedVector2Array()
			for k in 24:
				circle.append(Vector2.RIGHT.rotated(TAU * k / 24.0) * 120.0)
			circle.append(circle[0])
			canvas.load_shape([circle], [], body_color)
			shape = canvas.build_shape()
		body_data = shape
		canvas.enter_weapon_mode()
		canvas.pen_color = weapon_color
		palette.select(weapon_color)
		_set_phase(Phase.WEAPON)
	elif phase == Phase.WEAPON:
		_finish()

# ---------- Finish drawing, then pick weapon and ultimate ----------

func _finish() -> void:
	var raw: Array = canvas.weapon_strokes()
	var weapon := {}
	if not raw.is_empty():
		var mn := Vector2(1000000.0, 1000000.0)
		var mx := Vector2(-1000000.0, -1000000.0)
		for s in raw:
			for p in s:
				mn = mn.min(p)
				mx = mx.max(p)
		var wcenter := (mn + mx) * 0.5
		var extent := maxf(mx.x - mn.x, mx.y - mn.y)
		var fit := minf(1.0, DrawCanvas.WEAPON_MAX_SIZE / maxf(extent, 1.0))
		var wstrokes: Array = []
		for s in raw:
			var shrunk := PackedVector2Array()
			for p in ShapeUtils.offset_points(s, -wcenter):
				shrunk.append(p * fit)
			wstrokes.append(shrunk)
		weapon = {"type": 1, "strokes": wstrokes, "color": weapon_color}

	pending_top = {
		"area": body_data["area"],
		"color": body_color,
		"strokes": body_data["strokes_local"],
		"weapon": weapon,
		"name": "Speed Draw",
	}
	has_weapon = not weapon.is_empty()
	_start_picking()

func _start_picking() -> void:
	_set_phase(Phase.PICK)
	canvas.visible = false
	canvas.enabled = false
	panel.visible = false
	picker_layer = CanvasLayer.new()
	picker_layer.layer = 5
	add_child(picker_layer)
	if has_weapon:
		_show_weapon_picker()
	else:
		_show_ult_picker()

func _clear_picker() -> void:
	for c in picker_layer.get_children():
		c.queue_free()

func _show_weapon_picker() -> void:
	_clear_picker()
	var p := OptionPicker.new()
	picker_layer.add_child(p)
	p.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var items: Array = []
	for ty in range(1, 7):
		var melee := WeaponDefs.is_melee(ty)
		items.append({
			"name": WeaponDefs.NAMES[ty],
			"tag": "MELEE" if melee else "PROJECTILE",
			"desc": WEAPON_TIPS[ty - 1],
			"color": UiStyle.ORANGE if melee else UiStyle.BLUE})
	p.setup("CHOOSE WEAPON", UiStyle.ORANGE, items)
	p.chosen.connect(func(i: int):
		weapon_choice = i + 1
		_show_ult_picker())

func _show_ult_picker() -> void:
	_clear_picker()
	var p := OptionPicker.new()
	picker_layer.add_child(p)
	p.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var cols := [UiStyle.RED, UiStyle.YELLOW, UiStyle.BLUE]
	var tags := ["ATTACK ULTIMATE", "SPEED ULTIMATE", "DEFENSE ULTIMATE"]
	var items: Array = []
	for i in 3:
		items.append({"name": ULT_NAMES[i], "tag": tags[i], "desc": ULT_TIPS[i], "color": cols[i]})
	p.setup("CHOOSE ULTIMATE", UiStyle.PINK, items)
	p.chosen.connect(_picks_done)
	p.back.connect(func():
		if has_weapon:
			_show_weapon_picker())

func _picks_done(ult: int) -> void:
	picker_layer.queue_free()
	if has_weapon:
		pending_top["weapon"]["type"] = weapon_choice
	Net.my = {"top": pending_top, "weapon": weapon_choice, "ult": ult}
	Net.send({"t": "drawn", "top": GameData.export_dict(pending_top),
			"weapon": weapon_choice, "ult": ult})
	my_done = true
	panel.visible = true
	_set_phase(Phase.WAIT)
	_check_start()

# ---------- Network ----------

func _check_start() -> void:
	if Net.is_host and my_done and opp_done:
		Net.send({"t": "start"})
		get_tree().change_scene_to_file("res://online_battle.tscn")

func _on_message(d: Dictionary) -> void:
	match d.get("t", ""):
		"drawn":
			Net.opp = {
				"top": GameData.import_top(d["top"]),
				"weapon": clampi(int(d.get("weapon", 1)), 1, 6),
				"ult": clampi(int(d.get("ult", 0)), 0, 2)}
			opp_done = true
			_check_start()
		"start":
			if not Net.is_host:
				get_tree().change_scene_to_file("res://online_battle.tscn")

func _on_peer_left() -> void:
	phase_label.text = "OPPONENT LEFT"
	status.text = "Returning to the menu..."
	await get_tree().create_timer(2.0).timeout
	Net.leave()
	get_tree().change_scene_to_file("res://menu.tscn")
