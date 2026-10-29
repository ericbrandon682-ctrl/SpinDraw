extends Node2D

enum State { SELECT, ARCHETYPE, AIM, FIGHT, OVER }

const BATTLE_SCALE := 0.14
const ARENA_CENTER := Vector2(640, 360)
const AIM_MAX_DIST := 220.0
const AIM_MIN_POWER := 0.15
const MATCH_TIME := 90.0
const ARCH_NAMES := ["Attack", "Speed", "Defense"]
const ULT_NAMES := ["Overdrive Impact", "Mach Drive", "Black Hole"]

var state := State.SELECT
var player: Top
var enemy: Top
var aiming := false
var chosen_index := -1
var last_arch := 0
var match_time := MATCH_TIME
var enemy_ult_delay := 1.0
var weapon_holder: CenterContainer
var chosen_weapon := 0

var tops_node: Node2D
var aim_line: Line2D
var select_holder: CenterContainer
var arch_holder: CenterContainer
var list_box: VBoxContainer
var info: Label
var rematch_btn: Button
var ult_btn: Button
var player_bar: ProgressBar
var enemy_bar: ProgressBar
var player_label: Label
var enemy_label: Label
var timer_label: Label
var arena: Arena
var preview: TopPreview
var preview_name: Label
var preview_stats: Label
var choose_btn: Button
var selected_index := 0

func _ready() -> void:
	RenderingServer.set_default_clear_color(Color("14161c"))

	arena = Arena.new()
	arena.position = ARENA_CENTER
	add_child(arena)

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
	if state == State.AIM:
		for t in [player, enemy]:
			if t:
				t.rotation += Top.PREVIEW_SPIN * delta
	elif state == State.FIGHT:
		match_time -= delta
		timer_label.text = str(ceili(maxf(match_time, 0.0)))
		_update_ult_ui()
		_enemy_ult(delta)
		arena.update_fight(delta, [player, enemy], MATCH_TIME - match_time)
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
	l.visible = false
	root.add_child(l)
	return l

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 2
	add_child(layer)
	var root := Control.new()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(root)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var bar := HBoxContainer.new()
	bar.position = Vector2(16, 16)
	bar.add_theme_constant_override("separation", 12)
	root.add_child(bar)
	var menu_btn := UiStyle.make_button("Menu", Color("5a5f6b"), 64, 24)
	menu_btn.custom_minimum_size.x = 150
	menu_btn.pressed.connect(func(): get_tree().change_scene_to_file("res://menu.tscn"))
	bar.add_child(menu_btn)
	var change_btn := UiStyle.make_button("Change top", Color("4a6fa5"), 64, 24)
	change_btn.custom_minimum_size.x = 210
	change_btn.pressed.connect(_show_select)
	bar.add_child(change_btn)

	# Match timer (top center)
	timer_label = Label.new()
	timer_label.position = Vector2(540, 14)
	timer_label.size = Vector2(200, 60)
	timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	timer_label.add_theme_font_size_override("font_size", 48)
	timer_label.visible = false
	root.add_child(timer_label)

	# HP bars (left = you, right = enemy)
	player_bar = _make_bar(root, Vector2(16, 96), Color("2fbf71"))
	player_label = _make_label(root, Vector2(16, 126))
	enemy_bar = _make_bar(root, Vector2(884, 96), Color("c94f5a"))
	enemy_label = _make_label(root, Vector2(884, 126))

	info = Label.new()
	info.position = Vector2(0, 668)
	info.size = Vector2(1280, 40)
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info.add_theme_font_size_override("font_size", 26)
	root.add_child(info)

	# Ultimate button (bottom center)
	ult_btn = UiStyle.make_button("ULTIMATE", Color("9b5de5"), 76, 26)
	ult_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	ult_btn.custom_minimum_size.x = 340
	ult_btn.position = Vector2(470, 580)
	ult_btn.visible = false
	ult_btn.pressed.connect(func():
		if player and player.ult_ready():
			player.activate_ultimate()
			info.text = ULT_NAMES[player.archetype].to_upper() + "!")
	root.add_child(ult_btn)

	rematch_btn = UiStyle.make_button("REMATCH", Color("2fbf71"), 70, 28)
	rematch_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	rematch_btn.custom_minimum_size.x = 220
	rematch_btn.position = Vector2(530, 590)
	rematch_btn.visible = false
	rematch_btn.pressed.connect(func(): _start_match(last_arch))
	root.add_child(rematch_btn)

	# --- Top selection panel ---
	# --- Top selection panel ---
	select_holder = CenterContainer.new()
	select_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(select_holder)
	select_holder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var panel := PanelContainer.new()
	panel.custom_minimum_size.x = 960
	panel.add_theme_stylebox_override("panel", UiStyle.panel(UiStyle.BLUE))
	select_holder.add_child(panel)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 24)
	panel.add_child(h)

	var v := VBoxContainer.new()
	v.custom_minimum_size.x = 500
	v.add_theme_constant_override("separation", 8)
	h.add_child(v)
	var title := Label.new()
	title.text = "Choose your top"
	title.add_theme_font_size_override("font_size", 34)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UiStyle.outline(title, 5)
	v.add_child(title)
	list_box = VBoxContainer.new()
	list_box.add_theme_constant_override("separation", 6)
	v.add_child(list_box)

	var pv := VBoxContainer.new()
	pv.custom_minimum_size.x = 380
	pv.add_theme_constant_override("separation", 10)
	h.add_child(pv)
	preview = TopPreview.new()
	preview.custom_minimum_size = Vector2(380, 300)
	pv.add_child(preview)
	preview_name = Label.new()
	preview_name.add_theme_font_size_override("font_size", 30)
	preview_name.add_theme_color_override("font_color", UiStyle.YELLOW)
	preview_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UiStyle.outline(preview_name, 5)
	pv.add_child(preview_name)
	preview_stats = Label.new()
	preview_stats.add_theme_font_size_override("font_size", 22)
	preview_stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UiStyle.outline(preview_stats, 4)
	pv.add_child(preview_stats)
	choose_btn = UiStyle.make_button("CHOOSE", UiStyle.GREEN.darkened(0.15), 70, 28)
	choose_btn.pressed.connect(func():
		if selected_index >= 0 and selected_index < GameData.tops.size():
			_choose_weapon(selected_index))
	pv.add_child(choose_btn)

	# --- Archetype panel ---
	arch_holder = CenterContainer.new()
	arch_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(arch_holder)
	arch_holder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var apanel := PanelContainer.new()
	apanel.custom_minimum_size.x = 700
	apanel.add_theme_stylebox_override("panel", UiStyle.box(Color("1f2229"), 20, 24))
	arch_holder.add_child(apanel)
	var av := VBoxContainer.new()
	av.add_theme_constant_override("separation", 12)
	apanel.add_child(av)
	var atitle := Label.new()
	atitle.text = "Choose movement style"
	atitle.add_theme_font_size_override("font_size", 34)
	atitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	av.add_child(atitle)

	var defs := [
		["ATTACK: heavy hits | Ult: Overdrive Impact", Color("c94f5a"), Top.Archetype.ATTACK],
		["SPEED: erratic ricochets | Ult: Mach Drive", Color("d9a82f"), Top.Archetype.SPEED],
		["DEFENSE: center anchor | Ult: Black Hole", Color("4a6fa5"), Top.Archetype.DEFENSE],
	]
	for d in defs:
		var b := UiStyle.make_button(d[0], d[1], 76, 24)
		b.pressed.connect(_start_match.bind(d[2]))
		av.add_child(b)
	var back := UiStyle.make_button("Back", Color("5a5f6b"), 60, 24)
	back.pressed.connect(_show_select)
	av.add_child(back)
	
		# --- Weapon type panel ---
	weapon_holder = CenterContainer.new()
	weapon_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(weapon_holder)
	weapon_holder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var wpanel := PanelContainer.new()
	wpanel.custom_minimum_size.x = 700
	wpanel.add_theme_stylebox_override("panel", UiStyle.panel(UiStyle.ORANGE))
	weapon_holder.add_child(wpanel)
	var wv := VBoxContainer.new()
	wv.add_theme_constant_override("separation", 8)
	wpanel.add_child(wv)
	var wtitle := Label.new()
	wtitle.text = "Choose weapon type"
	wtitle.add_theme_font_size_override("font_size", 32)
	wtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UiStyle.outline(wtitle, 5)
	wv.add_child(wtitle)
	for ty in range(1, 7):
		var melee := WeaponDefs.is_melee(ty)
		var wb := UiStyle.make_button(
				"%s   (%s)" % [WeaponDefs.NAMES[ty], "MELEE" if melee else "PROJECTILE"],
				UiStyle.ORANGE if melee else UiStyle.BLUE, 58, 22)
		wb.tooltip_text = WeaponDefs.DESCRIPTIONS[ty]
		wb.pressed.connect(_pick_weapon.bind(ty))
		wv.add_child(wb)
	var wback := UiStyle.make_button("Back", UiStyle.LAVENDER, 52, 22)
	wback.pressed.connect(_show_select)
	wv.add_child(wback)

func _top_name(i: int) -> String:
	var n: String = GameData.tops[i].get("name", "")
	return n if n != "" else "Top %d" % (i + 1)

func _refresh_list() -> void:
	for c in list_box.get_children():
		c.queue_free()
	if GameData.tops.is_empty():
		var l := Label.new()
		l.text = "No saved tops. Go to Menu and draw one."
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		list_box.add_child(l)
		preview.data = {}
		preview_name.text = ""
		preview_stats.text = ""
		choose_btn.disabled = true
		return
	choose_btn.disabled = false
	for i in GameData.tops.size():
		var data: Dictionary = GameData.tops[i]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		var pick := UiStyle.make_button(_top_name(i), data["color"].darkened(0.3), 52, 24)
		pick.pressed.connect(_select_top.bind(i))
		row.add_child(pick)
		var del := UiStyle.make_button("X", UiStyle.RED, 52, 24)
		del.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		del.custom_minimum_size.x = 64
		del.pressed.connect(_delete_top.bind(i))
		row.add_child(del)
		list_box.add_child(row)
	_select_top(clampi(selected_index, 0, GameData.tops.size() - 1))

func _select_top(i: int) -> void:
	selected_index = i
	var data: Dictionary = GameData.tops[i]
	var st := TopStats.from_area(data["area"])
	preview.data = data
	preview_name.text = _top_name(i)
	preview_stats.text = "HP %d   |   %d RPM\n%s" % [
		st.max_hp, st.rpm(),
		"Weapon shape drawn" if not data.get("weapon", {}).is_empty() else "No weapon shape"]

func _delete_top(i: int) -> void:
	GameData.remove_top(i)
	_refresh_list()

# ---------- Match flow ----------

func _set_bars_visible(v: bool) -> void:
	for n in [player_bar, enemy_bar, player_label, enemy_label, timer_label]:
		n.visible = v

func _show_select() -> void:
	_clear_tops()
	weapon_holder.visible = false
	state = State.SELECT
	aim_line.visible = false
	aiming = false
	select_holder.visible = true
	arch_holder.visible = false
	rematch_btn.visible = false
	ult_btn.visible = false
	_set_bars_visible(false)
	info.text = ""
	_refresh_list()

func _choose_archetype(index: int) -> void:
	chosen_index = index
	state = State.ARCHETYPE
	select_holder.visible = false
	arch_holder.visible = true
	
func _choose_weapon(index: int) -> void:
	chosen_index = index
	var w: Dictionary = GameData.tops[index].get("weapon", {})
	select_holder.visible = false
	if w.is_empty():
		chosen_weapon = WeaponDefs.Type.NONE   # nothing drawn, skip this step
		_choose_archetype(index)
	else:
		state = State.ARCHETYPE
		weapon_holder.visible = true

func _pick_weapon(type: int) -> void:
	chosen_weapon = type
	weapon_holder.visible = false
	_choose_archetype(chosen_index)

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
	arena.reset()
	_clear_tops()
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
	ult_btn.visible = false
	arch_holder.visible = false
	state = State.AIM
	info.text = "You: %s (%s)   vs   Enemy: %s (%s)   |   Drag to aim, release to launch" % [
		ARCH_NAMES[player_arch], WeaponDefs.NAMES[player.weapon_type],
		ARCH_NAMES[enemy_arch], WeaponDefs.NAMES[enemy.weapon_type]]

# ---------- Ultimates ----------

func _update_ult_ui() -> void:
	if player == null:
		return
	if player.ult_time > 0.0:
		ult_btn.disabled = true
		ult_btn.text = "%s ACTIVE" % ULT_NAMES[player.archetype]
	elif player.ult_used:
		ult_btn.disabled = true
		ult_btn.text = "Ultimate used"
	elif player.ult_ready():
		ult_btn.disabled = false
		ult_btn.text = "ULTIMATE: %s" % ULT_NAMES[player.archetype]
	else:
		ult_btn.disabled = true
		ult_btn.text = "Ultimate %d%%" % int(player.ult_charge * 100.0)

func _enemy_ult(delta: float) -> void:
	if enemy and enemy.ult_ready():
		enemy_ult_delay -= delta
		if enemy_ult_delay <= 0.0:
			enemy.activate_ultimate()
			enemy_ult_delay = randf_range(0.5, 2.0)

# ---------- Ending ----------

func _finish(message: String, loser: Top = null) -> void:
	arena.reset()
	if state != State.FIGHT:
		return
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
	info.text = message
	rematch_btn.visible = true

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
	aim_line.default_color = Color("2fbf71").lerp(Color("ff5d73"), power)
	aim_line.visible = true

func _launch() -> void:
	var v := _aim_vector()
	var power := v.length() / AIM_MAX_DIST
	aim_line.visible = false
	if power < AIM_MIN_POWER:
		return
	var to_player := player.global_position - enemy.global_position
	player.launch(v.normalized(), power)
	enemy.launch(to_player.normalized().rotated(randf_range(-0.4, 0.4)), 0.8)
	match_time = MATCH_TIME
	enemy_ult_delay = randf_range(0.5, 2.0)
	state = State.FIGHT
	ult_btn.visible = true
	info.text = "Fight!"
