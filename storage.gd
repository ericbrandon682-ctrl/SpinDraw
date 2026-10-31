extends Control

var title: Label
var new_btn: Button
var scroll: ScrollContainer
var grid: GridContainer
var empty_holder: CenterContainer
var pending_delete := -1

func _ready() -> void:
	RenderingServer.set_default_clear_color(Color("07070f"))
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var bg := ColorRect.new()
	bg.color = Color("0d0d1f")
	add_child(bg)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_bottom", 16)
	add_child(margin)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", 14)
	margin.add_child(page)

	# Header: Menu | title | New top
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 12)
	page.add_child(header)

	var menu_btn := UiStyle.make_button("MENU", UiStyle.LAVENDER, 60, 24)
	menu_btn.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	menu_btn.custom_minimum_size.x = 160
	menu_btn.pressed.connect(func(): get_tree().change_scene_to_file("res://menu.tscn"))
	header.add_child(menu_btn)

	title = Label.new()
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 44)
	title.add_theme_color_override("font_color", UiStyle.YELLOW)
	UiStyle.outline(title, 10)
	header.add_child(title)

	new_btn = UiStyle.make_button("+ NEW TOP", UiStyle.GREEN, 60, 24)
	new_btn.size_flags_horizontal = Control.SIZE_SHRINK_END
	new_btn.custom_minimum_size.x = 220
	new_btn.pressed.connect(_new_top)
	header.add_child(new_btn)

	# Grid of saved tops
	scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	page.add_child(scroll)
	var center := CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(center)
	grid = GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 14)
	center.add_child(grid)

	# Empty state
	empty_holder = CenterContainer.new()
	empty_holder.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.add_child(empty_holder)
	var ep := PanelContainer.new()
	ep.add_theme_stylebox_override("panel", UiStyle.panel(UiStyle.YELLOW, UiStyle.BLACK, 28))
	empty_holder.add_child(ep)
	var ev := VBoxContainer.new()
	ev.add_theme_constant_override("separation", 18)
	ep.add_child(ev)
	var el := Label.new()
	el.text = "* No tops saved yet!\n* Draw your first top to get started."
	el.add_theme_font_size_override("font_size", 28)
	ev.add_child(el)
	var create := UiStyle.make_button("CREATE FIRST TOP", UiStyle.GREEN, 84, 30)
	create.pressed.connect(_new_top)
	ev.add_child(create)

	_refresh()

func _refresh() -> void:
	for c in grid.get_children():
		grid.remove_child(c)
		c.queue_free()
	var n := GameData.tops.size()
	title.text = "STORAGE  %d / %d" % [n, GameData.MAX_TOPS]
	new_btn.disabled = n >= GameData.MAX_TOPS
	new_btn.text = "+ NEW TOP" if n < GameData.MAX_TOPS else "FULL"
	empty_holder.visible = n == 0
	scroll.visible = n > 0
	for i in n:
		grid.add_child(_make_card(i))

func _make_card(i: int) -> PanelContainer:
	var data: Dictionary = GameData.tops[i]
	var st := TopStats.from_area(data["area"])
	var wdata: Dictionary = data.get("weapon", {})
	var has_weapon: bool = not wdata.is_empty()

	var card := PanelContainer.new()
	card.custom_minimum_size.x = 240
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

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	v.add_child(row)
	var edit := UiStyle.make_button("EDIT", UiStyle.BLUE, 44, 18, false)
	edit.pressed.connect(_edit_top.bind(i))
	row.add_child(edit)
	var sure := pending_delete == i
	var del := UiStyle.make_button("SURE?" if sure else "DELETE", UiStyle.YELLOW if sure else UiStyle.RED, 44, 18, false)
	del.pressed.connect(_delete_top.bind(i))
	row.add_child(del)
	return card

func _new_top() -> void:
	GameData.editing_index = -1
	get_tree().change_scene_to_file("res://main.tscn")

func _edit_top(i: int) -> void:
	GameData.editing_index = i
	get_tree().change_scene_to_file("res://main.tscn")

func _delete_top(i: int) -> void:
	if pending_delete == i:
		pending_delete = -1
		GameData.remove_top(i)
		_refresh()
		return
	pending_delete = i
	_refresh()
	var tw := create_tween()
	tw.tween_interval(2.5)
	tw.tween_callback(func():
		if pending_delete == i:
			pending_delete = -1
			_refresh())
