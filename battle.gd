extends Node2D

enum State { SELECT, ARCHETYPE, AIM, FIGHT }

const BATTLE_SCALE := 0.35
const ARENA_CENTER := Vector2(640, 360)
const AIM_MAX_DIST := 220.0
const AIM_MIN_POWER := 0.15
const ARCH_NAMES := ["Attack", "Speed", "Defense"]

var state := State.SELECT
var player: Top
var enemy: Top
var aiming := false
var chosen_index := -1

var tops_node: Node2D
var aim_line: Line2D
var select_holder: CenterContainer
var arch_holder: CenterContainer
var list_box: VBoxContainer
var info: Label

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
				t.rotation += t.stats.spin_speed * delta

# ---------- UI ----------

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

	info = Label.new()
	info.position = Vector2(0, 668)
	info.size = Vector2(1280, 40)
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info.add_theme_font_size_override("font_size", 26)
	root.add_child(info)

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
		["ATTACK: chases the enemy", Color("c94f5a"), Top.Archetype.ATTACK],
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
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		var pick := UiStyle.make_button(
			"Top %d    HP %d    %d RPM" % [i + 1, st.max_hp, st.rpm()],
			data["color"].darkened(0.35), 64, 24)
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

func _show_select() -> void:
	_clear_tops()
	state = State.SELECT
	aim_line.visible = false
	aiming = false
	select_holder.visible = true
	arch_holder.visible = false
	info.text = ""
	_refresh_list()

func _choose_archetype(index: int) -> void:
	chosen_index = index
	state = State.ARCHETYPE
	select_holder.visible = false
	arch_holder.visible = true

func _clear_tops() -> void:
	for t in tops_node.get_children():
		t.queue_free()
	player = null
	enemy = null

func _make_top(index: int, offset: Vector2) -> Top:
	var data: Dictionary = GameData.tops[index]
	var stats := TopStats.from_area(data["area"])
	var strokes_small: Array = []
	for s in data["strokes"]:
		var out := PackedVector2Array()
		out.resize(s.size())
		for i in s.size():
			out[i] = s[i] * BATTLE_SCALE
		strokes_small.append(out)
	var top := Top.new()
	top.setup(strokes_small, stats, data["color"])
	top.hold()
	top.position = ARENA_CENTER + offset
	tops_node.add_child(top)
	return top

func _start_match(player_arch: int) -> void:
	_clear_tops()
	var enemy_index := chosen_index
	if GameData.tops.size() > 1:
		while enemy_index == chosen_index:
			enemy_index = randi() % GameData.tops.size()
	player = _make_top(chosen_index, Vector2(-170, 0))
	enemy = _make_top(enemy_index, Vector2(170, 0))

	var enemy_arch := randi() % 3
	player.set_archetype(player_arch, enemy, ARENA_CENTER)
	enemy.set_archetype(enemy_arch, player, ARENA_CENTER)

	arch_holder.visible = false
	state = State.AIM
	info.text = "You: %s   vs   Enemy: %s    |    Drag to aim, release to launch" % [
		ARCH_NAMES[player_arch], ARCH_NAMES[enemy_arch]]

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
	info.text = "Fight!  You: %s   vs   Enemy: %s" % [
		ARCH_NAMES[player.archetype], ARCH_NAMES[enemy.archetype]]
