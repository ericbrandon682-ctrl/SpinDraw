extends Control

var status: Label
var ip_edit: LineEdit
var top_pick: OptionButton
var weapon_pick: OptionButton
var ult_pick: OptionButton
var ready_btn: Button
var found_box: VBoxContainer
var found := {}
var my_ready := false
var opp_ready := false
var got_opp := false
var speed_check: CheckButton

func _ready() -> void:
	RenderingServer.set_default_clear_color(Color("07070f"))
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	Net.my = {}
	Net.opp = {}

	var bg := ColorRect.new()
	bg.color = Color("0d0d1f")
	add_child(bg)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var center := CenterContainer.new()
	add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var panel := PanelContainer.new()
	panel.custom_minimum_size.x = 760
	panel.add_theme_stylebox_override("panel", UiStyle.panel(UiStyle.BLUE, UiStyle.NAVY, 16))
	center.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	panel.add_child(v)

	var title := Label.new()
	title.text = "LAN 1v1"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 40)
	title.add_theme_color_override("font_color", UiStyle.YELLOW)
	UiStyle.outline(title, 8)
	v.add_child(title)

	top_pick = _option(v, "Top")
	for i in GameData.tops.size():
		var nm: String = GameData.tops[i].get("name", "")
		top_pick.add_item(nm if nm != "" else "Top %d" % (i + 1))
	weapon_pick = _option(v, "Weapon")
	for ty in range(1, 7):
		weapon_pick.add_item(WeaponDefs.NAMES[ty])
	ult_pick = _option(v, "Ultimate")
	for n in ["Overdrive Impact", "Mach Drive", "Black Hole"]:
		ult_pick.add_item(n)
	speed_check = CheckButton.new()
	speed_check.text = "SPEED DRAW (host decides): draw your top on the spot"
	speed_check.add_theme_font_size_override("font_size", 20)
	speed_check.toggled.connect(func(_on: bool): _check_start())
	v.add_child(speed_check)

	var host_btn := UiStyle.make_button("HOST A GAME", UiStyle.GREEN, 56, 24, false)
	host_btn.pressed.connect(func(): Net.create_room())
	v.add_child(host_btn)

	found_box = VBoxContainer.new()
	found_box.custom_minimum_size.y = 50
	v.add_child(found_box)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	v.add_child(row)
	ip_edit = LineEdit.new()
	ip_edit.placeholder_text = "or type host IP"
	ip_edit.custom_minimum_size = Vector2(440, 52)
	ip_edit.add_theme_font_size_override("font_size", 22)
	row.add_child(ip_edit)
	var join_btn := UiStyle.make_button("JOIN", UiStyle.BLUE, 52, 22, false)
	join_btn.pressed.connect(_join_typed)
	row.add_child(join_btn)

	ready_btn = UiStyle.make_button("READY!", UiStyle.PINK, 60, 26, false)
	ready_btn.disabled = true
	ready_btn.pressed.connect(_on_ready)
	v.add_child(ready_btn)

	status = Label.new()
	status.text = "Host a game, or join one."
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status.custom_minimum_size.y = 70
	status.add_theme_font_size_override("font_size", 20)
	UiStyle.outline(status, 4)
	v.add_child(status)

	var back := UiStyle.make_button("BACK", UiStyle.LAVENDER, 50, 22, false)
	back.pressed.connect(func():
		Net.leave()
		get_tree().change_scene_to_file("res://menu.tscn"))
	v.add_child(back)

	Net.room_created.connect(func(ip: String):
		status.text = "Hosting! Your IP: %s\nWaiting for a friend..." % ip)
	Net.room_joined.connect(_on_connected)
	Net.peer_joined.connect(_on_connected)
	Net.peer_left.connect(func():
		status.text = "Opponent left."
		ready_btn.disabled = true)
	Net.failed.connect(func(m: String): status.text = "Error: " + m)
	Net.message.connect(_on_message)
	Net.host_found.connect(_on_host_found)
	Net.start_discovery()

func _exit_tree() -> void:
	Net.stop_discovery()

func _option(parent: Control, label: String) -> OptionButton:
	var row := HBoxContainer.new()
	parent.add_child(row)
	var l := Label.new()
	l.text = label
	l.custom_minimum_size.x = 130
	l.add_theme_font_size_override("font_size", 22)
	row.add_child(l)
	var ob := OptionButton.new()
	ob.custom_minimum_size.y = 46
	ob.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ob.add_theme_font_size_override("font_size", 22)
	row.add_child(ob)
	return ob

func _join_typed() -> void:
	var ip := ip_edit.text.strip_edges()
	if ip.is_empty():
		status.text = "Type the host's IP address."
		return
	_join(ip)

func _join(ip: String) -> void:
	status.text = "Connecting to %s..." % ip
	Net.join_room(ip)

func _on_host_found(ip: String) -> void:
	if found.has(ip) or Net.is_host:
		return
	var b := UiStyle.make_button("JOIN  " + ip, UiStyle.BLUE, 46, 20, false)
	b.pressed.connect(_join.bind(ip))
	found_box.add_child(b)
	found[ip] = b

func _on_connected() -> void:
	status.text = "Connected! Choose your weapon and ultimate, then press READY."
	ready_btn.disabled = my_ready

func _on_ready() -> void:
	var wt := weapon_pick.selected + 1
	var ut := ult_pick.selected
	var draw := Net.is_host and speed_check.button_pressed
	Net.my = {"weapon": wt, "ult": ut}
	var msg := {"t": "pick", "weapon": wt, "ult": ut}
	if not draw and not GameData.tops.is_empty():
		var exported := GameData.export_top(top_pick.selected)
		Net.my["top"] = GameData.import_top(exported)
		msg["top"] = exported
	Net.send(msg)
	Net.send({"t": "ready"})
	my_ready = true
	ready_btn.disabled = true
	status.text = "Ready! Waiting for the opponent..."
	_check_start()

func _on_message(d: Dictionary) -> void:
	match d.get("t", ""):
		"pick":
			Net.opp = {
				"weapon": clampi(int(d["weapon"]), 1, 6),
				"ult": clampi(int(d["ult"]), 0, 2)}
			if d.has("top"):
				Net.opp["top"] = GameData.import_top(d["top"])
			got_opp = true
		"ready":
			opp_ready = true
			if not my_ready:
				status.text = "Opponent is ready. Press READY!"
			_check_start()
		"start":
			var scene := "res://speed_draw.tscn" if d.get("draw", false) else "res://online_battle.tscn"
			get_tree().change_scene_to_file(scene)

func _check_start() -> void:
	if not (Net.is_host and my_ready and opp_ready and got_opp):
		return
	var draw := speed_check.button_pressed
	if not draw and (not Net.my.has("top") or not Net.opp.has("top")):
		status.text = "Both players need a saved top. Tick SPEED DRAW to draw instead."
		return
	Net.stop_broadcast()
	Net.send({"t": "start", "draw": draw})
	get_tree().change_scene_to_file("res://speed_draw.tscn" if draw else "res://online_battle.tscn")
