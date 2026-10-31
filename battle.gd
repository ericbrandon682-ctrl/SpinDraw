extends Node2D

enum State { SELECT, ARCHETYPE, AIM, COUNTDOWN, FIGHT, OVER }

const BATTLE_SCALE := 0.14
const ARENA_CENTER := Vector2(640, 360)
const AIM_MAX_DIST := 220.0
const AIM_MIN_POWER := 0.15
const MATCH_TIME := 90.0
const COUNT_STEP := 0.8
const NOTE_TIME := 5.0
const ULT_NAMES := ["Overdrive Impact", "Mach Drive", "Black Hole"]
const SKILL_LABELS := ["ATTACK", "SPEED", "DEFENSE"]
const WEAPON_TIPS := [
	"Your drawn blade is copied 3 times around the top. Hits fast on contact.",
	"One big blade. Slow, heavy hits with strong knockback.",
	"Hits slow the enemy's speed and spin for 2.5 seconds.",
	"Fires 3 bullets in a spiral. Each bullet is weaker. Bullets bounce once off a wall.",
	"Bullet bounces up to 6 times. If it loops back and hits you, it hits harder and turns on the enemy.",
	"Bullets set the enemy on fire, draining its HP for 4 seconds.",
]
const ULT_TIPS := [
	"Dash at the enemy. Each body hit takes a chunk of its max HP. Projectile tops fire 3 volleys. One use per match.",
	"5 seconds of super speed, 90% less damage taken and faster weapon attacks. One use per match.",
	"A field pulls the enemy in, drains its HP over time and destroys its bullets. One use per match.",
]

var state := State.SELECT
var player: Top
var enemy: Top
var aiming := false
var chosen_index := -1
var chosen_weapon := 0
var last_arch := 0
var match_time := MATCH_TIME
var match_id := 0
var enemy_ult_delay := 1.0
var enemy_skill_delay := 2.0
var shake := 0.0
var danger_warned := false

var arena: Arena
var camera: Camera2D
var tops_node: Node2D
var aim_line: Line2D
var select_holder: CenterContainer
var arch_holder: OptionPicker
var weapon_holder: OptionPicker
var grid: GridContainer
var info_box: PanelContainer
var info: Label
var danger_note: PanelContainer
var rematch_btn: Button
var again_btn: Button
var ult_btn: Button
var skill_btns: Array[Button] = []
var player_bar: ProgressBar
var enemy_bar: ProgressBar
var player_label: Label
var enemy_label: Label
var timer_label: Label
var result_layer: CanvasLayer

func _ready() -> void:
	RenderingServer.set_default_clear_color(Color("07070f"))

	arena = Arena.new()
	arena.position = ARENA_CENTER
	add_child(arena)

	camera = Camera2D.new()
	camera.position = Vector2(640, 360)
	add_child(camera)

	tops_node = Node2D.new()
	add_child(tops_node)

	aim_line = Line2D.new()
	aim_line.width = 8.0
	aim_line.z_index = 20
	aim_line.visible = false
	aim_line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	aim_line.end_cap_mode = Line2D.LINE_CAP_ROUND
	add_child(aim_line)

	_build_ui()
	_show_select()

func _process(delta: float) -> void:
	info_box.visible = info.text != ""
	shake = maxf(shake - delta * 30.0, 0.0)
	camera.offset = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)).round() * shake

	if state == State.AIM or state == State.COUNTDOWN:
		for t in [player, enemy]:
			if t:
				t.rotation += Top.PREVIEW_SPIN * delta
	elif state == State.FIGHT:
		match_time -= delta
		timer_label.text = str(ceili(maxf(match_time, 0.0)))
		_update_ult_ui()
		_update_skill_ui()
		_enemy_ult(delta)
		_enemy_skills(delta)
		arena.update_fight(delta, [player, enemy], MATCH_TIME - match_time)
		if not danger_warned and MATCH_TIME - match_time >= Arena.DANGER_START:
			_warn_danger()
		if match_time <= 0.0:
			_time_up()

# ---------- UI ----------

func _make_bar(root: Control, pos: Vector2, color: Color) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.position = pos
	bar.custom_minimum_size = Vector2(380, 26)
	bar.size = Vector2(380, 26)
	bar.show_percentage = false
	bar.add_theme_stylebox_override("background", UiStyle.bar_bg())
	bar.add_theme_stylebox_override("fill", UiStyle.bar_fill(color))
	bar.visible = false
	root.add_child(bar)
	return bar

func _make_label(root: Control, pos: Vector2) -> Label:
	var l := Label.new()
	l.position = pos
	l.add_theme_font_size_override("font_size", 22)
	UiStyle.outline(l, 4)
	l.visible = false
	root.add_child(l)
	return l

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var root := Control.new()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(root)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	# Menu button (top left)
	var menu_btn := UiStyle.make_button("Menu", UiStyle.LAVENDER, 64, 24)
	menu_btn.custom_minimum_size.x = 150
	menu_btn.position = Vector2(16, 16)
	menu_btn.pressed.connect(func(): get_tree().change_scene_to_file("res://menu.tscn"))
	root.add_child(menu_btn)

	# Match timer (top center)
	timer_label = Label.new()
	timer_label.position = Vector2(540, 14)
	timer_label.size = Vector2(200, 60)
	timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	timer_label.add_theme_font_size_override("font_size", 48)
	timer_label.add_theme_color_override("font_color", UiStyle.YELLOW)
	UiStyle.outline(timer_label, 8)
	timer_label.visible = false
	root.add_child(timer_label)

	# HP bars
	player_bar = _make_bar(root, Vector2(16, 96), UiStyle.GREEN)
	player_label = _make_label(root, Vector2(16, 126))
	enemy_bar = _make_bar(root, Vector2(884, 96), UiStyle.RED)
	enemy_label = _make_label(root, Vector2(884, 126))

	# Info text inside a dialogue box
	info_box = PanelContainer.new()
	info_box.add_theme_stylebox_override("panel", UiStyle.panel(UiStyle.WHITE, UiStyle.BLACK, 12))
	info_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info_box.position = Vector2(140, 626)
	info_box.custom_minimum_size.x = 1000
	info_box.size = Vector2(1000, 0)
	info_box.visible = false
	root.add_child(info_box)
	info = Label.new()
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.add_theme_font_size_override("font_size", 24)
	info.add_theme_color_override("font_color", UiStyle.YELLOW)
	info_box.add_child(info)

	# Danger ring explanation (right side, shown briefly)
	danger_note = PanelContainer.new()
	danger_note.add_theme_stylebox_override("panel", UiStyle.panel(UiStyle.RED, UiStyle.BLACK, 10))
	danger_note.mouse_filter = Control.MOUSE_FILTER_IGNORE
	danger_note.position = Vector2(1040, 240)
	danger_note.visible = false
	root.add_child(danger_note)
	var dl := Label.new()
	dl.text = "DANGER RING!\nThe red ring is shrinking. Stay inside it or lose HP every half second."
	dl.custom_minimum_size.x = 200
	dl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dl.add_theme_font_size_override("font_size", 18)
	dl.add_theme_color_override("font_color", UiStyle.WHITE)
	danger_note.add_child(dl)

	# Ultimate button	# Ultimate button (left column, under the three skills)
	ult_btn = UiStyle.make_button("ULTIMATE", UiStyle.PINK, 84, 22, false)
	ult_btn.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	ult_btn.custom_minimum_size.x = 220
	ult_btn.position = Vector2(16, 230 + 3 * 96)
	ult_btn.visible = false
	ult_btn.pressed.connect(_on_ult_pressed)
	root.add_child(ult_btn)

	# Skill buttons (left edge)
	var sk_cols := [UiStyle.RED, UiStyle.YELLOW, UiStyle.BLUE]
	for i in 3:
		var sb := UiStyle.make_button(SKILL_LABELS[i], sk_cols[i], 84, 24, false)
		sb.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		sb.custom_minimum_size.x = 220
		sb.position = Vector2(16, 230 + i * 96)
		sb.visible = false
		sb.pressed.connect(_on_skill_pressed.bind(i))
		root.add_child(sb)
		skill_btns.append(sb)

	# Result buttons (sit under the centered result text)
	rematch_btn = UiStyle.make_button("REMATCH", UiStyle.GREEN, 70, 28)
	rematch_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	rematch_btn.custom_minimum_size.x = 240
	rematch_btn.position = Vector2(390, 400)
	rematch_btn.visible = false
	rematch_btn.pressed.connect(func(): _start_match(last_arch))
	root.add_child(rematch_btn)

	again_btn = UiStyle.make_button("PICK ANOTHER", UiStyle.BLUE, 70, 28)
	again_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	again_btn.custom_minimum_size.x = 280
	again_btn.position = Vector2(650, 400)
	again_btn.visible = false
	again_btn.pressed.connect(_show_select)
	root.add_child(again_btn)

	# --- Top selection: grid of boxes ---
	select_holder = CenterContainer.new()
	select_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(select_holder)
	select_holder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	select_holder.offset_top = 80
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiStyle.panel(UiStyle.BLUE))
	select_holder.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	panel.add_child(v)
	var title := Label.new()
	title.text = "Choose your top"
	title.add_theme_font_size_override("font_size", 34)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UiStyle.outline(title, 5)
	v.add_child(title)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(1010, 510)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(scroll)
	grid = GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(grid)

	# --- Weapon type picker ---
	weapon_holder = OptionPicker.new()
	weapon_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(weapon_holder)
	weapon_holder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var witems: Array = []
	for ty in range(1, 7):
		var melee := WeaponDefs.is_melee(ty)
		witems.append({
			"name": WeaponDefs.NAMES[ty],
			"tag": "MELEE" if melee else "PROJECTILE",
			"desc": WEAPON_TIPS[ty - 1],
			"color": UiStyle.ORANGE if melee else UiStyle.BLUE})
	weapon_holder.setup("CHOOSE WEAPON", UiStyle.ORANGE, witems)
	weapon_holder.chosen.connect(func(i: int): _pick_weapon(i + 1))
	weapon_holder.back.connect(_show_select)

	# --- Ultimate picker ---
	arch_holder = OptionPicker.new()
	arch_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(arch_holder)
	arch_holder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var uitems: Array = []
	var ucols := [UiStyle.RED, UiStyle.YELLOW, UiStyle.BLUE]
	var utags := ["ATTACK ULTIMATE", "SPEED ULTIMATE", "DEFENSE ULTIMATE"]
	for i in 3:
		uitems.append({
			"name": ULT_NAMES[i],
			"tag": utags[i],
			"desc": ULT_TIPS[i],
			"color": ucols[i]})
	arch_holder.setup("CHOOSE ULTIMATE", UiStyle.PINK, uitems)
	arch_holder.chosen.connect(func(i: int): _start_match(i))
	arch_holder.back.connect(_show_select)

func _refresh_grid() -> void:
	for c in grid.get_children():
		grid.remove_child(c)
		c.queue_free()
	if GameData.tops.is_empty():
		grid.columns = 1
		var l := Label.new()
		l.text = "No saved tops yet.\nGo to Menu > DRAW to create one."
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.custom_minimum_size.x = 700
		grid.add_child(l)
		return
	grid.columns = 4
	for i in GameData.tops.size():
		grid.add_child(_make_card(i))

func _make_card(i: int) -> PanelContainer:
	var data: Dictionary = GameData.tops[i]
	var st := TopStats.from_area(data["area"])
	var wdata: Dictionary = data.get("weapon", {})
	var has_weapon: bool = not wdata.is_empty()

	var card := PanelContainer.new()
	card.custom_minimum_size.x = 236
	card.add_theme_stylebox_override("panel", UiStyle.panel(data["color"], UiStyle.INK, 10))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	card.add_child(v)

	var pv := TopPreview.new()
	pv.custom_minimum_size = Vector2(0, 110)
	pv.data = data
	v.add_child(pv)

	var n := Label.new()
	var nm: String = data.get("name", "")
	n.text = nm if nm != "" else "Top %d" % (i + 1)
	n.clip_text = true
	n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	n.add_theme_font_size_override("font_size", 22)
	n.add_theme_color_override("font_color", UiStyle.YELLOW)
	UiStyle.outline(n, 4)
	var name_box := PanelContainer.new()
	var nsb := UiStyle.panel(UiStyle.YELLOW, UiStyle.BLACK, 6)
	nsb.set_border_width_all(3)
	name_box.add_theme_stylebox_override("panel", nsb)
	name_box.add_child(n)
	v.add_child(name_box)

	var s := Label.new()
	s.text = "HP %d | %d RPM%s" % [st.max_hp, st.rpm(), " | W" if has_weapon else ""]
	s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	s.add_theme_font_size_override("font_size", 18)
	v.add_child(s)

	var pick := UiStyle.make_button("CHOOSE", UiStyle.GREEN, 44, 20)
	pick.pressed.connect(_choose_weapon.bind(i))
	v.add_child(pick)
	return card

# ---------- Match flow ----------

func _set_bars_visible(v: bool) -> void:
	for n in [player_bar, enemy_bar, player_label, enemy_label, timer_label]:
		n.visible = v

func _set_skills_visible(v: bool) -> void:
	for b in skill_btns:
		b.visible = v

func _show_select() -> void:
	match_id += 1
	danger_warned = false
	danger_note.visible = false
	_hide_result()
	_clear_tops()
	arena.reset()
	state = State.SELECT
	aim_line.visible = false
	aiming = false
	select_holder.visible = true
	arch_holder.visible = false
	weapon_holder.visible = false
	rematch_btn.visible = false
	again_btn.visible = false
	ult_btn.visible = false
	_set_skills_visible(false)
	_set_bars_visible(false)
	info.text = ""
	_refresh_grid()

func _choose_weapon(index: int) -> void:
	chosen_index = index
	var w: Dictionary = GameData.tops[index].get("weapon", {})
	select_holder.visible = false
	if w.is_empty():
		chosen_weapon = WeaponDefs.Type.NONE   # no weapon shape drawn: skip this step
		_choose_archetype()
	else:
		state = State.ARCHETYPE
		weapon_holder.reset()
		weapon_holder.visible = true

func _pick_weapon(type: int) -> void:
	chosen_weapon = type
	weapon_holder.visible = false
	_choose_archetype()

func _choose_archetype() -> void:
	state = State.ARCHETYPE
	select_holder.visible = false
	arch_holder.reset()
	arch_holder.visible = true

func _clear_tops() -> void:
	for t in tops_node.get_children():   # also removes bullets
		t.queue_free()
	player = null
	enemy = null

func _scaled(pts: PackedVector2Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	out.resize(pts.size())
	for i in pts.size():
		out[i] = pts[i] * BATTLE_SCALE
	return out

func _make_top(index: int, offset: Vector2, wtype: int) -> Top:
	var data: Dictionary = GameData.tops[index]
	var stats := TopStats.from_area(data["area"])
	var strokes_small: Array = []
	for s in data["strokes"]:
		strokes_small.append(_scaled(s))

	var weapon := {}
	var w: Dictionary = data.get("weapon", {})
	if not w.is_empty():
		var ws: Array = []
		for s in w["strokes"]:
			ws.append(_scaled(s))
		weapon = {"type": wtype, "strokes": ws}

	var top := Top.new()
	top.setup(strokes_small, stats, data["color"], weapon)
	top.hold()
	top.position = ARENA_CENTER + offset
	tops_node.add_child(top)
	top.died.connect(_on_died.bind(top))
	top.damaged.connect(func(a: int): shake = maxf(shake, clampf(a * 0.6, 2.0, 12.0)))
	return top

func _bind_bar(top: Top, bar: ProgressBar, label: Label, who: String) -> void:
	bar.max_value = top.stats.max_hp
	bar.value = top.hp
	label.text = "%s   %d / %d" % [who, top.hp, top.stats.max_hp]
	top.hp_changed.connect(_on_hp_changed.bind(bar, label, who))

func _on_hp_changed(hp: int, max_hp: int, bar: ProgressBar, label: Label, who: String) -> void:
	bar.value = hp
	label.text = "%s   %d / %d" % [who, hp, max_hp]

func _start_match(player_arch: int) -> void:
	match_id += 1
	danger_warned = false
	danger_note.visible = false
	_hide_result()
	_clear_tops()
	arena.reset()
	last_arch = player_arch
	var enemy_index := chosen_index
	if GameData.tops.size() > 1:
		while enemy_index == chosen_index:
			enemy_index = randi() % GameData.tops.size()
	player = _make_top(chosen_index, Vector2(-220, 0), chosen_weapon)
	enemy = _make_top(enemy_index, Vector2(220, 0), randi_range(1, 6))

	var enemy_arch := randi() % 3
	player.set_archetype(player_arch, enemy, ARENA_CENTER)
	enemy.set_archetype(enemy_arch, player, ARENA_CENTER)

	_set_bars_visible(true)
	match_time = MATCH_TIME
	timer_label.text = str(int(MATCH_TIME))
	_bind_bar(player, player_bar, player_label, "YOU")
	_bind_bar(enemy, enemy_bar, enemy_label, "ENEMY")

	rematch_btn.visible = false
	again_btn.visible = false
	ult_btn.visible = false
	_set_skills_visible(false)
	arch_holder.visible = false
	weapon_holder.visible = false
	state = State.AIM
	info.text = "You: %s (%s)  vs  Enemy: %s (%s)  |  Drag to aim, release to launch" % [
		ULT_NAMES[player_arch], WeaponDefs.NAMES[player.weapon_type],
		ULT_NAMES[enemy_arch], WeaponDefs.NAMES[enemy.weapon_type]]

# ---------- Skills and ultimates ----------

func _on_skill_pressed(i: int) -> void:
	if player and player.skill_ready(i):
		player.activate_skill(i)
		shake = 8.0

func _on_ult_pressed() -> void:
	if player and player.ult_ready():
		player.activate_ultimate()
		_ult_fx(player, true)

func _update_skill_ui() -> void:
	if player == null:
		return
	for i in 3:
		var b := skill_btns[i]
		if player.skill_time[i] > 0.0:
			b.disabled = false
			b.text = "%s  %.1fs" % [SKILL_LABELS[i], player.skill_time[i]]
		elif player.skill_cd[i] > 0.0:
			b.disabled = true
			b.text = "%s  wait %d" % [SKILL_LABELS[i], ceili(player.skill_cd[i])]
		else:
			b.disabled = false
			b.text = SKILL_LABELS[i]

func _update_ult_ui() -> void:
	if player == null:
		return
	if player.ult_time > 0.0:
		ult_btn.disabled = true
		ult_btn.text = "ULT  %.1fs" % player.ult_time
	elif player.ult_used:
		ult_btn.disabled = true
		ult_btn.text = "ULT used"
	elif player.ult_ready():
		ult_btn.disabled = false
		ult_btn.text = "ULTIMATE!"
	else:
		ult_btn.disabled = true
		ult_btn.text = "ULT  %d%%" % int(player.ult_charge * 100.0)

func _enemy_ult(delta: float) -> void:
	if enemy and enemy.ult_ready():
		enemy_ult_delay -= delta
		if enemy_ult_delay <= 0.0:
			enemy.activate_ultimate()
			_ult_fx(enemy, false)
			enemy_ult_delay = randf_range(0.5, 2.0)

func _enemy_skills(delta: float) -> void:
	if enemy == null or enemy.dead:
		return
	enemy_skill_delay -= delta
	if enemy_skill_delay > 0.0:
		return
	enemy_skill_delay = randf_range(2.0, 4.0)
	var options: Array[int] = []
	for i in 3:
		if enemy.skill_ready(i):
			options.append(i)
	if not options.is_empty():
		enemy.activate_skill(options.pick_random())

func _ult_fx(top: Top, mine: bool) -> void:
	var col := UiStyle.YELLOW if mine else UiStyle.RED
	Fx.flash(self, col)
	Fx.banner(self, ("" if mine else "ENEMY: ") + ULT_NAMES[top.archetype].to_upper() + "!", col)
	Fx.burst(tops_node, top.global_position, col, 16, 90.0)
	shake = 14.0

# ---------- Danger ring warning ----------

func _warn_danger() -> void:
	danger_warned = true
	Fx.banner(self, "DANGER ZONE!", UiStyle.RED)
	Fx.flash(self, UiStyle.RED)
	shake = 8.0
	danger_note.visible = true
	var id := match_id
	get_tree().create_timer(NOTE_TIME).timeout.connect(func():
		if id == match_id:
			danger_note.visible = false)

# ---------- Ending ----------

func _finish(message: String, loser: Top = null) -> void:
	if state != State.FIGHT:
		return
	arena.reset()
	state = State.OVER
	for t in [player, enemy]:
		if t:
			t.stop()
	if loser:
		loser.set_deferred("freeze", true)
		loser.modulate = Color(1, 1, 1, 0.35)
	for b in get_tree().get_nodes_in_group("bullets"):
		b.queue_free()
	ult_btn.visible = false
	_set_skills_visible(false)
	danger_note.visible = false
	info.text = ""
	var win := message.contains("WIN")
	var draw := message.contains("DRAW")
	var col := UiStyle.GREEN if win else (UiStyle.YELLOW if draw else UiStyle.RED)
	_show_result(message, col)
	if loser:
		Fx.burst(tops_node, loser.global_position, Color.WHITE, 22, 130.0)
	rematch_btn.visible = true
	again_btn.visible = true

func _show_result(message: String, color: Color) -> void:
	_hide_result()
	result_layer = CanvasLayer.new()
	result_layer.layer = 3
	add_child(result_layer)

	var l := Label.new()
	l.text = message
	l.size = Vector2(1280, 160)
	l.position = Vector2(0, 200)
	l.pivot_offset = Vector2(640, 80)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", 96)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 20)
	l.scale = Vector2(2.0, 2.0)
	l.modulate.a = 0.0
	result_layer.add_child(l)

	var tw := l.create_tween()
	tw.set_parallel(true)
	tw.tween_property(l, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "modulate:a", 1.0, 0.15)

func _hide_result() -> void:
	if result_layer and is_instance_valid(result_layer):
		result_layer.queue_free()
	result_layer = null

func _on_died(loser: Top) -> void:
	_finish("YOU WIN!" if loser == enemy else "YOU LOSE", loser)

func _time_up() -> void:
	var p := float(player.hp) / player.stats.max_hp
	var e := float(enemy.hp) / enemy.stats.max_hp
	if absf(p - e) < 0.001:
		_finish("TIME UP: DRAW")
	elif p > e:
		_finish("TIME UP: YOU WIN on HP!", enemy)
	else:
		_finish("TIME UP: YOU LOSE on HP", player)

# ---------- Aiming ----------

func _unhandled_input(event: InputEvent) -> void:
	if state != State.AIM or player == null:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			aiming = true
			_update_aim()
		elif aiming:
			aiming = false
			_launch()
	elif event is InputEventMouseMotion and aiming:
		_update_aim()

func _aim_vector() -> Vector2:
	return (get_global_mouse_position() - player.global_position).limit_length(AIM_MAX_DIST)

func _update_aim() -> void:
	var v := _aim_vector()
	var power := v.length() / AIM_MAX_DIST
	aim_line.points = PackedVector2Array([player.global_position, player.global_position + v])
	aim_line.default_color = UiStyle.GREEN.lerp(UiStyle.RED, power)
	aim_line.visible = true

# ---------- Countdown and launch ----------

func _launch() -> void:
	var v := _aim_vector()
	var power := v.length() / AIM_MAX_DIST
	aim_line.visible = false
	if power < AIM_MIN_POWER:
		return
	state = State.COUNTDOWN
	info.text = ""
	_countdown(v.normalized(), power)

func _countdown(dir: Vector2, power: float) -> void:
	var id := match_id
	for n in [3, 2, 1]:
		_pop(str(n), UiStyle.YELLOW, 120)
		await get_tree().create_timer(COUNT_STEP).timeout
		if id != match_id:
			return
	_pop("FIGHT!", UiStyle.RED, 110)
	Fx.flash(self, UiStyle.RED)
	shake = 10.0

	var to_player := player.global_position - enemy.global_position
	player.launch(dir, power)
	enemy.launch(to_player.normalized().rotated(randf_range(-0.4, 0.4)), 0.8)
	match_time = MATCH_TIME
	enemy_ult_delay = randf_range(0.5, 2.0)
	enemy_skill_delay = randf_range(2.0, 4.0)
	state = State.FIGHT
	ult_btn.visible = true
	_set_skills_visible(true)

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
