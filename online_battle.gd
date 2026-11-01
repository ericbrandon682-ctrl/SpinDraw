extends Node2D

enum State { AIM, WAIT, COUNTDOWN, FIGHT, OVER }

const BATTLE_SCALE := 0.14
const ARENA_CENTER := Vector2(640, 360)
const AIM_MAX_DIST := 220.0
const AIM_MIN_POWER := 0.15
const MATCH_TIME := 90.0
const COUNT_STEP := 0.8
const SNAP_RATE := 0.05      # 20 snapshots per second
const ULT_NAMES := ["Overdrive Impact", "Mach Drive", "Black Hole"]
const SKILL_LABELS := ["ATTACK", "SPEED", "DEFENSE"]

var host := false
var my_i := 0
var state := State.AIM
var datas: Array = []          # [host's pick, guest's pick]
var tops: Array = []           # [host's Top, guest's Top]
var my_aim := {}
var opp_aim := {}
var aiming := false
var match_time := MATCH_TIME
var match_id := 0
var snap_timer := 0.0
var danger_warned := false

# Guest display data
var targets: Array = [null, null]
var spin_vel: Array = [0.0, 0.0]
var bullet_nodes: Array = []

var arena: Arena
var tops_node: Node2D
var fx_node: Node2D
var aim_line: Line2D
var status: Label
var result_label: Label
var timer_label: Label
var player_bar: ProgressBar
var enemy_bar: ProgressBar
var player_label: Label
var enemy_label: Label
var rematch_btn: Button
var ult_btn: Button
var skill_btns: Array[Button] = []

func _ready() -> void:
	RenderingServer.set_default_clear_color(Color("07070f"))
	host = Net.is_host
	my_i = 0 if host else 1
	datas = [Net.my, Net.opp] if host else [Net.opp, Net.my]

	arena = Arena.new()
	arena.position = ARENA_CENTER
	add_child(arena)
	tops_node = Node2D.new()
	add_child(tops_node)
	fx_node = Node2D.new()
	add_child(fx_node)
	aim_line = Line2D.new()
	aim_line.width = 8.0
	aim_line.z_index = 20
	aim_line.visible = false
	aim_line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	aim_line.end_cap_mode = Line2D.LINE_CAP_ROUND
	add_child(aim_line)

	_build_ui()
	Net.message.connect(_on_message)
	Net.peer_left.connect(_on_peer_left)
	_setup_match()

# ---------- Setup ----------

func _area_of(strokes: Array) -> float:
	# Recomputed from the strokes, so a client can't claim a fake size
	var pts := PackedVector2Array()
	for s in strokes:
		pts.append_array(s)
	var hull := ShapeUtils.clean_hull(pts)
	if hull.size() < 3:
		return TopStats.MIN_AREA
	return clampf(ShapeUtils.area(hull), TopStats.MIN_AREA, TopStats.MAX_AREA)

func _scaled(pts: PackedVector2Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	out.resize(pts.size())
	for i in pts.size():
		out[i] = pts[i] * BATTLE_SCALE
	return out

func _make_top(i: int) -> Top:
	var d: Dictionary = datas[i]
	var data: Dictionary = d["top"]
	var stats := TopStats.from_area(_area_of(data["strokes"]))
	var small: Array = []
	for s in data["strokes"]:
		small.append(_scaled(s))
	var weapon := {}
	var w: Dictionary = data.get("weapon", {})
	if not w.is_empty():
		var ws: Array = []
		for s in w["strokes"]:
			ws.append(_scaled(s))
			weapon = {"type": int(d["weapon"]), "strokes": ws, "color": w.get("color", data["color"].lightened(0.5))}
	var top := Top.new()
	top.setup(small, stats, data["color"], weapon)
	top.hold()
	top.position = ARENA_CENTER + Vector2(-220.0 if i == 0 else 220.0, 0.0)
	tops_node.add_child(top)
	return top

func _setup_match() -> void:
	match_id += 1
	for t in tops_node.get_children():
		t.queue_free()
	for n in bullet_nodes:
		n.queue_free()
	bullet_nodes.clear()
	arena.reset()
	arena.apply_remote(0.0, [])

	tops = [_make_top(0), _make_top(1)]
	for i in 2:
		tops[i].set_archetype(int(datas[i]["ult"]), tops[1 - i], ARENA_CENTER)
	if host:
		for i in 2:
			tops[i].died.connect(_on_died.bind(i))

	targets = [null, null]
	my_aim = {}
	opp_aim = {}
	aiming = false
	danger_warned = false
	match_time = MATCH_TIME
	state = State.AIM
	result_label.visible = false
	rematch_btn.visible = false
	_set_fight_ui(false)
	for n in [player_bar, enemy_bar, player_label, enemy_label, timer_label]:
		n.visible = true
	status.text = "You: %s (%s)  |  Drag to aim, release to lock in" % [
		ULT_NAMES[int(datas[my_i]["ult"])], WeaponDefs.NAMES[int(datas[my_i]["weapon"])]]
	_update_ui()

# ---------- UI ----------

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var root := Control.new()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(root)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var menu_btn := UiStyle.make_button("Menu", UiStyle.LAVENDER, 64, 24, false)
	menu_btn.custom_minimum_size.x = 150
	menu_btn.position = Vector2(16, 16)
	menu_btn.pressed.connect(func():
		Net.leave()
		get_tree().change_scene_to_file("res://menu.tscn"))
	root.add_child(menu_btn)

	timer_label = Label.new()
	timer_label.position = Vector2(540, 14)
	timer_label.size = Vector2(200, 60)
	timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	timer_label.add_theme_font_size_override("font_size", 48)
	timer_label.add_theme_color_override("font_color", UiStyle.YELLOW)
	UiStyle.outline(timer_label, 8)
	root.add_child(timer_label)

	player_bar = _make_bar(root, Vector2(16, 96), UiStyle.GREEN)
	player_label = _make_label(root, Vector2(16, 126))
	enemy_bar = _make_bar(root, Vector2(884, 96), UiStyle.RED)
	enemy_label = _make_label(root, Vector2(884, 126))

	status = Label.new()
	status.position = Vector2(140, 650)
	status.size = Vector2(1000, 50)
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status.add_theme_font_size_override("font_size", 24)
	status.add_theme_color_override("font_color", UiStyle.YELLOW)
	UiStyle.outline(status, 6)
	root.add_child(status)

	result_label = Label.new()
	result_label.position = Vector2(0, 200)
	result_label.size = Vector2(1280, 160)
	result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	result_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	result_label.add_theme_font_size_override("font_size", 88)
	result_label.add_theme_color_override("font_outline_color", Color.BLACK)
	result_label.add_theme_constant_override("outline_size", 20)
	result_label.visible = false
	root.add_child(result_label)

	var sk_cols := [UiStyle.RED, UiStyle.YELLOW, UiStyle.BLUE]
	for i in 3:
		var sb := UiStyle.make_button(SKILL_LABELS[i], sk_cols[i], 84, 24, false)
		sb.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		sb.custom_minimum_size.x = 220
		sb.position = Vector2(16, 230 + i * 96)
		sb.visible = false
		sb.pressed.connect(_on_skill.bind(i))
		root.add_child(sb)
		skill_btns.append(sb)

	ult_btn = UiStyle.make_button("ULT", UiStyle.PINK, 84, 22, false)
	ult_btn.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	ult_btn.custom_minimum_size.x = 220
	ult_btn.position = Vector2(16, 230 + 3 * 96)
	ult_btn.visible = false
	ult_btn.pressed.connect(_on_ult)
	root.add_child(ult_btn)

	rematch_btn = UiStyle.make_button("REMATCH", UiStyle.GREEN, 70, 28, false)
	rematch_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	rematch_btn.custom_minimum_size.x = 260
	rematch_btn.position = Vector2(510, 400)
	rematch_btn.visible = false
	rematch_btn.pressed.connect(func():
		Net.send({"t": "rematch"})
		_setup_match())
	root.add_child(rematch_btn)

func _make_bar(root: Control, pos: Vector2, color: Color) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.position = pos
	bar.custom_minimum_size = Vector2(380, 26)
	bar.size = Vector2(380, 26)
	bar.show_percentage = false
	bar.add_theme_stylebox_override("background", UiStyle.bar_bg())
	bar.add_theme_stylebox_override("fill", UiStyle.bar_fill(color))
	root.add_child(bar)
	return bar

func _make_label(root: Control, pos: Vector2) -> Label:
	var l := Label.new()
	l.position = pos
	l.add_theme_font_size_override("font_size", 22)
	UiStyle.outline(l, 4)
	root.add_child(l)
	return l

func _set_fight_ui(v: bool) -> void:
	for b in skill_btns:
		b.visible = v
	ult_btn.visible = v

func _update_ui() -> void:
	if tops.size() < 2:
		return
	var me: Top = tops[my_i]
	var op: Top = tops[1 - my_i]
	player_bar.max_value = me.stats.max_hp
	player_bar.value = me.hp
	player_label.text = "YOU   %d / %d" % [me.hp, me.stats.max_hp]
	enemy_bar.max_value = op.stats.max_hp
	enemy_bar.value = op.hp
	enemy_label.text = "OPPONENT   %d / %d" % [op.hp, op.stats.max_hp]
	timer_label.text = str(ceili(maxf(match_time, 0.0)))

	for i in 3:
		var b := skill_btns[i]
		if me.mode == i:
			b.disabled = false
			b.text = "> %s <" % SKILL_LABELS[i]
		elif me.mode_cd > 0.0:
			b.disabled = true
			b.text = "%s  wait %d" % [SKILL_LABELS[i], ceili(me.mode_cd)]
		else:
			b.disabled = false
			b.text = SKILL_LABELS[i]

	if me.ult_time > 0.0:
		ult_btn.disabled = true
		ult_btn.text = "ULT  %.1fs" % me.ult_time
	elif me.ult_used:
		ult_btn.disabled = true
		ult_btn.text = "ULT used"
	elif _ult_ready(me):
		ult_btn.disabled = false
		ult_btn.text = "ULTIMATE!"
	else:
		ult_btn.disabled = true
		ult_btn.text = "ULT  %d%%" % int(me.ult_charge * 100.0)

func _ult_ready(t: Top) -> bool:
	return t.ult_charge >= 1.0 and t.ult_time <= 0.0 and not t.ult_used and not t.dead

# ---------- Frame loop ----------

func _process(delta: float) -> void:
	if tops.size() < 2:
		return
	if state == State.AIM or state == State.WAIT or state == State.COUNTDOWN:
		for t in tops:
			t.rotation += Top.PREVIEW_SPIN * delta
	elif state == State.FIGHT:
		if host:
			_host_fight(delta)
		else:
			_guest_smooth(delta)
		_update_ui()

func _host_fight(delta: float) -> void:
	match_time -= delta
	var elapsed := MATCH_TIME - match_time
	arena.update_fight(delta, tops, elapsed)
	_check_danger(elapsed)
	snap_timer -= delta
	if snap_timer <= 0.0:
		snap_timer = SNAP_RATE
		Net.send(_snapshot(), true)
	if match_time <= 0.0:
		_time_up()

func _check_danger(elapsed: float) -> void:
	if not danger_warned and elapsed >= Arena.DANGER_START:
		danger_warned = true
		Fx.banner(self, "DANGER ZONE!", UiStyle.RED)
		Fx.flash(self, UiStyle.RED)

func _guest_smooth(delta: float) -> void:
	for i in 2:
		var t: Top = tops[i]
		t.rotation += spin_vel[i] * delta
		if targets[i] != null:
			t.global_position = t.global_position.lerp(targets[i], minf(1.0, delta * 25.0))
		if t.mode == Top.Skill.DEFENSE and t._skill_fx.has(Top.Skill.DEFENSE) \
			and is_instance_valid(t._skill_fx[Top.Skill.DEFENSE]):
			t._skill_fx[Top.Skill.DEFENSE].scale = Vector2.ONE * (1.0 + 0.08 * sin(Time.get_ticks_msec() / 80.0))
	for n in bullet_nodes:
		n.position += n.get_meta("vel") * delta
		n.rotation += 6.0 * delta

# ---------- Aiming ----------

func _unhandled_input(event: InputEvent) -> void:
	if state != State.AIM or tops.size() < 2:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			aiming = true
			_update_aim()
		elif aiming:
			aiming = false
			_release_aim()
	elif event is InputEventMouseMotion and aiming:
		_update_aim()

func _aim_vector() -> Vector2:
	return (get_global_mouse_position() - tops[my_i].global_position).limit_length(AIM_MAX_DIST)

func _update_aim() -> void:
	var v := _aim_vector()
	var power := v.length() / AIM_MAX_DIST
	var p: Vector2 = tops[my_i].global_position
	aim_line.points = PackedVector2Array([p, p + v])
	aim_line.default_color = UiStyle.GREEN.lerp(UiStyle.RED, power)
	aim_line.visible = true

func _release_aim() -> void:
	var v := _aim_vector()
	var power := v.length() / AIM_MAX_DIST
	aim_line.visible = false
	if power < AIM_MIN_POWER:
		return
	var dir := v.normalized()
	my_aim = {"dir": dir, "power": power}
	state = State.WAIT
	status.text = "Aim locked! Waiting for the opponent..."
	if host:
		_check_ready()
	else:
		Net.send({"t": "aim", "dx": dir.x, "dy": dir.y, "p": power})

# ---------- Countdown and launch (host drives it) ----------

func _check_ready() -> void:
	if not host or my_aim.is_empty() or opp_aim.is_empty():
		return
	if state != State.AIM and state != State.WAIT:
		return
	_countdown()

func _countdown() -> void:
	state = State.COUNTDOWN
	status.text = ""
	var id := match_id
	Audio.play_sfx(Audio.COUNTDOWN_SFX)
	for n in [3, 2, 1]:
		_pop(str(n), UiStyle.YELLOW, 120)
		Net.send({"t": "pop", "text": str(n)})
		await get_tree().create_timer(COUNT_STEP).timeout
		if id != match_id:
			return
	_pop("FIGHT!", UiStyle.RED, 110)
	Net.send({"t": "pop", "text": "FIGHT!", "go": true})
	Fx.flash(self, UiStyle.RED)
	tops[0].launch(my_aim["dir"], my_aim["power"])
	tops[1].launch(opp_aim["dir"], opp_aim["power"])
	match_time = MATCH_TIME
	snap_timer = 0.0
	state = State.FIGHT
	_set_fight_ui(true)

func _pop(text: String, color: Color, font_size: int) -> void:
	var layer := CanvasLayer.new()
	layer.layer = 3
	var l := Label.new()
	l.text = text
	l.size = Vector2(1280, 200)
	l.position = Vector2(0, 220)
	l.pivot_offset = Vector2(640, 100)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 16)
	l.scale = Vector2(2.2, 2.2)
	l.modulate.a = 0.0
	layer.add_child(l)
	add_child(layer)
	var tw := l.create_tween()
	tw.set_parallel(true)
	tw.tween_property(l, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "modulate:a", 1.0, 0.1)
	tw.chain().tween_interval(0.35)
	tw.chain().tween_property(l, "modulate:a", 0.0, 0.2)
	tw.chain().tween_callback(layer.queue_free)

# ---------- Buttons ----------

func _on_skill(i: int) -> void:
	if state != State.FIGHT:
		return
	if host:
		tops[0].activate_skill(i)
	else:
		Net.send({"t": "skill", "i": i})

func _on_ult() -> void:
	if state != State.FIGHT:
		return
	if host:
		_host_ult(0)
	else:
		Net.send({"t": "ult"})

func _host_ult(who: int) -> void:
	var t: Top = tops[who]
	if not _ult_ready(t):
		return
	t.ai_active = true
	t.activate_ultimate()
	_ult_event(who)
	Net.send({"t": "fx", "who": who})

func _ult_event(who: int) -> void:
	Audio.play_sfx(Audio.ULTIMATE_SFX)
	var mine := who == my_i
	var col := UiStyle.YELLOW if mine else UiStyle.RED
	Fx.flash(self, col)
	Fx.banner(self, ("" if mine else "OPPONENT: ") + ULT_NAMES[int(datas[who]["ult"])].to_upper() + "!", col)
	Fx.burst(tops_node, tops[who].global_position, col, 16, 90.0)

# ---------- Ending (host decides) ----------

func _on_died(i_died: int) -> void:
	_finish(1 - i_died, false)

func _finish(winner: int, timeup: bool) -> void:
	if state != State.FIGHT:
		return
	state = State.OVER
	for t in tops:
		t.stop()
	for b in get_tree().get_nodes_in_group("bullets"):
		b.queue_free()
	Net.send({"t": "result", "w": winner, "time": timeup, "hp": [tops[0].hp, tops[1].hp]})
	_show_result(winner, timeup)

func _time_up() -> void:
	var p: float = float(tops[0].hp) / float(tops[0].stats.max_hp)
	var e: float = float(tops[1].hp) / float(tops[1].stats.max_hp)
	if absf(p - e) < 0.001:
		_finish(-1, true)
	else:
		_finish(0 if p > e else 1, true)

func _show_result(winner: int, timeup: bool) -> void:
	Audio.pause_music()
	_set_fight_ui(false)
	var msg := "TIME UP: " if timeup else ""
	var col := UiStyle.YELLOW
	if winner < 0:
		msg += "DRAW"
	elif winner == my_i:
		msg += "YOU WIN!"
		col = UiStyle.GREEN
		Audio.play_sfx(Audio.WIN_SFX)
	else:
		msg += "YOU LOSE"
		col = UiStyle.RED
		Audio.play_sfx(Audio.LOSE_SFX)
	if winner >= 0:
		var loser: Top = tops[1 - winner]
		loser.modulate = Color(1, 1, 1, 0.35)
		Fx.burst(tops_node, loser.global_position, Color.WHITE, 22, 130.0)
	result_label.text = msg
	result_label.add_theme_color_override("font_color", col)
	result_label.visible = true
	status.text = ""
	rematch_btn.visible = host
	if not host:
		status.text = "Waiting for the host to start a rematch..."
	_update_ui()

func _on_peer_left() -> void:
	match_id += 1
	state = State.OVER
	_set_fight_ui(false)
	rematch_btn.visible = false
	result_label.text = "OPPONENT LEFT"
	result_label.add_theme_color_override("font_color", UiStyle.YELLOW)
	result_label.visible = true

# ---------- Network ----------

func _on_message(d: Dictionary) -> void:
	match d.get("t", ""):
		"aim":
			if host:
				opp_aim = {"dir": Vector2(float(d["dx"]), float(d["dy"])).normalized(),
						"power": clampf(float(d["p"]), 0.0, 1.0)}
				_check_ready()
		"skill":
			if host and state == State.FIGHT:
				tops[1].activate_skill(clampi(int(d["i"]), 0, 2))
		"ult":
			if host and state == State.FIGHT:
				_host_ult(1)
		"pop":
			if not host:
				if state != State.COUNTDOWN and state != State.FIGHT:
					state = State.COUNTDOWN
					status.text = ""
				var txt := str(d["text"])
				_pop(txt, UiStyle.RED if txt == "FIGHT!" else UiStyle.YELLOW,
						110 if txt == "FIGHT!" else 120)
				if d.has("go"):
					Fx.flash(self, UiStyle.RED)
					match_time = MATCH_TIME
					state = State.FIGHT
					_set_fight_ui(true)
		"s":
			if not host and state == State.FIGHT:
				_apply_snapshot(d)
		"fx":
			if not host:
				_ult_event(int(d["who"]))
		"result":
			if not host and state != State.OVER:
				state = State.OVER
				var hps: Array = d["hp"]
				tops[0].hp = int(hps[0])
				tops[1].hp = int(hps[1])
				for b in bullet_nodes:
					b.queue_free()
				bullet_nodes.clear()
				for t in tops:
					t.end_ultimate()
					t.show_mode_fx(-1)
				_show_result(int(d["w"]), bool(d["time"]))
		"rematch":
			if not host:
				_setup_match()

func _snapshot() -> Dictionary:
	var ts := []
	for t in tops:
		ts.append([
			snappedf(t.global_position.x, 0.1), snappedf(t.global_position.y, 0.1),
			snappedf(t.angular_velocity, 0.1), t.hp,
			snappedf(t.ult_charge, 0.01), snappedf(t.ult_time, 0.1), t.ult_used,
			t.mode, snappedf(t.mode_cd, 0.1), t.dead,
			snappedf(t.burn_time, 0.1), snappedf(t.slow_time, 0.1)])
	var bl := []
	for b in get_tree().get_nodes_in_group("bullets"):
		if b is Bullet and is_instance_valid(b.owner_top):
			bl.append([int(b.global_position.x), int(b.global_position.y),
					0 if b.owner_top == tops[0] else 1, snappedf(b.owner_top.bullet_radius, 0.1),
					snappedf(b.rotation, 0.1), int(b.linear_velocity.x), int(b.linear_velocity.y)])
	var orbs := []
	for o in arena.orbs:
		orbs.append([int(o["node"].position.x), int(o["node"].position.y)])
	return {"t": "s", "tp": ts, "b": bl, "o": orbs, "time": snappedf(match_time, 0.1)}

func _apply_snapshot(d: Dictionary) -> void:
	for i in 2:
		var a: Array = d["tp"][i]
		var t: Top = tops[i]
		var pos := Vector2(float(a[0]), float(a[1]))
		if targets[i] == null:
			t.global_position = pos
		targets[i] = pos
		spin_vel[i] = lerpf(spin_vel[i], float(a[2]), 0.25)
		var hp := int(a[3])
		if hp < t.hp:
			Fx.hit(tops_node, t.global_position, t.hp - hp)
		elif hp > t.hp:
			Fx.number(tops_node, t.global_position, "+%d" % (hp - t.hp), UiStyle.GREEN)
		t.hp = hp
		t.ult_charge = float(a[4])
		
		var new_ult := float(a[5])
		if new_ult > 0.0 and t.ult_time <= 0.0:
			t.show_ult_fx()
		elif new_ult <= 0.0 and t.ult_time > 0.0:
			t.end_ultimate()
			
		t.ult_time = new_ult
		t.ult_used = bool(a[6])
		
		var new_mode := int(a[7])
		if new_mode != t.mode:
			t.mode = new_mode
			t.show_mode_fx(new_mode)
			if new_mode >= 0:
				var mcol: Color = Top.SKILL_COLORS[new_mode]
				Fx.burst(tops_node, t.global_position, mcol, 14, 80.0)
				Fx.number(tops_node, t.global_position, Top.SKILL_NAMES[new_mode] + " MODE", mcol)
			
		t.mode_cd = float(a[8])
		t.dead = bool(a[9])
		
		var tint := Color.WHITE
		if float(a[11]) > 0.0:
			tint = Color(0.6, 0.8, 1.0)            # slowed
		if float(a[10]) > 0.0:
			tint = tint * Color(1.0, 0.6, 0.4)     # burning
		if t.dead:
			tint.a = 0.35
		t.modulate = tint
		
	match_time = float(d["time"])

	var bl: Array = d["b"]
	while bullet_nodes.size() > bl.size():
		bullet_nodes.pop_back().queue_free()
	for k in bl.size():
		var b: Array = bl[k]
		var owner_i := int(b[2])
		if k >= bullet_nodes.size():
			var nn := _make_bullet_node(owner_i)
			fx_node.add_child(nn)
			bullet_nodes.append(nn)
		elif int(bullet_nodes[k].get_meta("owner")) != owner_i:
			bullet_nodes[k].queue_free()
			var nn2 := _make_bullet_node(owner_i)
			fx_node.add_child(nn2)
			bullet_nodes[k] = nn2
		var n: Node2D = bullet_nodes[k]
		n.position = Vector2(float(b[0]), float(b[1]))
		n.rotation = float(b[4])
		n.set_meta("vel", Vector2(float(b[5]), float(b[6])))

	arena.apply_remote(MATCH_TIME - match_time, d["o"])
	_check_danger(MATCH_TIME - match_time)
	
func _make_bullet_node(owner_i: int) -> Node2D:
	var n := Node2D.new()
	n.z_index = 5
	n.set_meta("owner", owner_i)
	n.set_meta("vel", Vector2.ZERO)
	var t: Top = tops[owner_i]
	var col: Color = Color("ff9a3c") if t.weapon_type == WeaponDefs.Type.FIRE else t.weapon_color
	for s in t.bullet_strokes:
		var line := Line2D.new()
		line.points = s
		line.width = 4.0
		line.default_color = col
		line.joint_mode = Line2D.LINE_JOINT_ROUND
		line.begin_cap_mode = Line2D.LINE_CAP_ROUND
		line.end_cap_mode = Line2D.LINE_CAP_ROUND
		line.antialiased = false
		n.add_child(line)
	return n
