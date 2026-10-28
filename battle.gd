extends Node2D

enum State { SELECT, ARCHETYPE, AIM, FIGHT, OVER }

const BATTLE_SCALE := 0.22
const ARENA_CENTER := Vector2(640, 360)
const AIM_MAX_DIST := 220.0
const AIM_MIN_POWER := 0.15
const ARCH_NAMES := ["Attack", "Speed", "Defense"]

var state := State.SELECT
var player: Top
var enemy: Top
var aiming := false
var chosen_index := -1
var last_arch := 0

var tops_node: Node2D
var aim_line: Line2D
var select_holder: CenterContainer
var arch_holder: CenterContainer
var list_box: VBoxContainer
var info: Label
var rematch_btn: Button
var player_bar: ProgressBar
var enemy_bar: ProgressBar
var player_label: Label
var enemy_label: Label

func _ready() -> void:
	RenderingServer.set_default_clear_color(Color("14161c"))

	var arena := Arena.new()
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

# ---------- UI ----------

func _make_bar(root: Control, pos: Vector2, color: Color) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.position = pos
	bar.custom_minimum_size = Vector2(380, 26)
	bar.size = Vector2(380, 26)
	bar.show_percentage = false
	bar.add_theme_stylebox_override("background", UiStyle.box(Color("2a2e38"), 8, 0))
	bar.add_theme_stylebox_override("fill", UiStyle.box(color, 8, 0))
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

	rematch_btn = UiStyle.make_button("REMATCH", Color("2fbf71"), 70, 28)
	rematch_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	rematch_btn.custom_minimum_size.x = 220
	rematch_btn.position = Vector2(530, 590)
	rematch_btn.visible = false
	rematch_btn.pressed.connect(func(): _start_match(last_arch))
	root.add_child(rematch_btn)

	# --- Top selection panel ---
	select_holder = CenterContainer.new()
	select_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(select_holder)
	select_holder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var panel := PanelContainer.new()
	panel.custom_minimum_size.x = 640
	panel.add_theme_stylebox_override("panel", UiStyle.box(Color("1f2229"), 20, 24))
	select_holder.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	panel.add_child(v)
	var title := Label.new()
	title.text = "Choose your top"
	title.add_theme_font_size_override("font_size", 34)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(title)
	list_box = VBoxContainer.new()
	list_box.add_theme_constant_override("separation", 10)
	v.add_child(list_box)

	# --- Archetype panel ---
	arch_holder = CenterContainer.new()
	arch_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(arch_holder)
	arch_holder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var apanel := PanelContainer.new()
	apanel.custom_minimum_size.x = 640
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
		["ATTACK: heavy hits, big knockback", Color("c94f5a"), Top.Archetype.ATTACK],
		["SPEED: fast, erratic ricochets", Color("d9a82f"), Top.Archetype.SPEED],
		["DEFENSE: heavy anchor in the center", Color("4a6fa5"), Top.Archetype.DEFENSE],
	]
	for d in defs:
		var b := UiStyle.make_button(d[0], d[1], 76, 26)
		b.pressed.connect(_start_match.bind(d[2]))
		av.add_child(b)
	var back := UiStyle.make_button("Back", Color("5a5f6b"), 60, 24)
	back.pressed.connect(_show_select)
	av.add_child(back)

func _refresh_list() -> void:
	for c in list_box.get_children():
		c.queue_free()
	if GameData.tops.is_empty():
		var l := Label.new()
		l.text = "No saved tops. Go to Menu and draw one."
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		list_box.add_child(l)
		return
	for i in GameData.tops.size():
		var data: Dictionary = GameData.tops[i]
		var st := TopStats.from_area(data["area"])
		var wname := "No weapon"
		var w: Dictionary = data.get("weapon", {})
		if not w.is_empty():
			wname = WeaponDefs.NAMES[w["type"]]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		var pick := UiStyle.make_button(
			"Top %d   HP %d   %d RPM   %s" % [i + 1, st.max_hp, st.rpm(), wname],
			data["color"].darkened(0.35), 64, 22)
		pick.pressed.connect(_choose_archetype.bind(i))
		row.add_child(pick)
		var del := UiStyle.make_button("X", Color("c94f5a"), 64, 24)
		del.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		del.custom_minimum_size.x = 70
		del.pressed.connect(_delete_top.bind(i))
		row.add_child(del)
		list_box.add_child(row)

func _delete_top(i: int) -> void:
	GameData.remove_top(i)
	_refresh_list()

# ---------- Match flow ----------

func _set_bars_visible(v: bool) -> void:
	for n in [player_bar, enemy_bar, player_label, enemy_label]:
		n.visible = v

func _show_select() -> void:
	_clear_tops()
	state = State.SELECT
	aim_line.visible = false
	aiming = false
	select_holder.visible = true
	arch_holder.visible = false
	rematch_btn.visible = false
	_set_bars_visible(false)
	info.text = ""
	_refresh_list()

func _choose_archetype(index: int) -> void:
	chosen_index = index
	state = State.ARCHETYPE
	select_holder.visible = false
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

func _make_top(index: int, offset: Vector2) -> Top:
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
		weapon = {"type": w["type"], "strokes": ws}

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
	_clear_tops()
	last_arch = player_arch
	var enemy_index := chosen_index
	if GameData.tops.size() > 1:
		while enemy_index == chosen_index:
			enemy_index = randi() % GameData.tops.size()
	player = _make_top(chosen_index, Vector2(-170, 0))
	enemy = _make_top(enemy_index, Vector2(170, 0))

	var enemy_arch := randi() % 3
	player.set_archetype(player_arch, enemy, ARENA_CENTER)
	enemy.set_archetype(enemy_arch, player, ARENA_CENTER)

	_set_bars_visible(true)
	_bind_bar(player, player_bar, player_label, "YOU")
	_bind_bar(enemy, enemy_bar, enemy_label, "ENEMY")

	rematch_btn.visible = false
	arch_holder.visible = false
	state = State.AIM
	info.text = "You: %s (%s)   vs   Enemy: %s (%s)   |   Drag to aim, release to launch" % [
		ARCH_NAMES[player_arch], WeaponDefs.NAMES[player.weapon_type],
		ARCH_NAMES[enemy_arch], WeaponDefs.NAMES[enemy.weapon_type]]

func _on_died(loser: Top) -> void:
	if state != State.FIGHT:
		return
	state = State.OVER
	for t in [player, enemy]:
		if t:
			t.stop()
	loser.set_deferred("freeze", true)
	loser.modulate = Color(1, 1, 1, 0.35)
	for b in get_tree().get_nodes_in_group("bullets"):
		b.queue_free()
	info.text = "YOU WIN!" if loser == enemy else "YOU LOSE"
	rematch_btn.visible = true

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
	state = State.FIGHT
	info.text = "Fight!"
