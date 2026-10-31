class_name OptionPicker
extends CenterContainer

signal chosen(index: int)
signal back

var items: Array = []
var idx := 0
var accent := Color.WHITE

var title_label: Label
var count_label: Label
var tag_label: Label
var item_name: Label
var desc_label: Label
var card: PanelContainer
var dots_row: HBoxContainer
var dots: Array = []
var swipe_start := Vector2.ZERO
var swiping := false

## items: Array of {"name": String, "tag": String, "desc": String, "color": Color}
func setup(p_title: String, p_accent: Color, p_items: Array) -> void:
	items = p_items
	accent = p_accent

	var panel := PanelContainer.new()
	panel.custom_minimum_size.x = 820
	panel.add_theme_stylebox_override("panel", UiStyle.panel(accent, UiStyle.NAVY, 20))
	add_child(panel)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	panel.add_child(v)

	title_label = Label.new()
	title_label.text = p_title
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 34)
	UiStyle.outline(title_label, 5)
	v.add_child(title_label)

	# Row: < card >
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	v.add_child(row)

	var left := UiStyle.make_button("<", accent, 120, 48, false)
	left.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	left.custom_minimum_size.x = 90
	left.pressed.connect(_move.bind(-1))
	row.add_child(left)

	card = PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.custom_minimum_size = Vector2(520, 230)
	card.gui_input.connect(_card_input)
	row.add_child(card)

	var cv := VBoxContainer.new()
	cv.add_theme_constant_override("separation", 8)
	cv.alignment = BoxContainer.ALIGNMENT_CENTER
	card.add_child(cv)

	count_label = Label.new()
	count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	count_label.add_theme_font_size_override("font_size", 18)
	count_label.add_theme_color_override("font_color", UiStyle.LAVENDER)
	cv.add_child(count_label)

	item_name = Label.new()
	item_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	item_name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	item_name.add_theme_font_size_override("font_size", 40)
	item_name.add_theme_color_override("font_color", UiStyle.YELLOW)
	UiStyle.outline(item_name, 8)
	cv.add_child(item_name)

	tag_label = Label.new()
	tag_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tag_label.add_theme_font_size_override("font_size", 20)
	cv.add_child(tag_label)

	desc_label = Label.new()
	desc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_label.custom_minimum_size.x = 480
	desc_label.add_theme_font_size_override("font_size", 24)
	cv.add_child(desc_label)

	var right := UiStyle.make_button(">", accent, 120, 48, false)
	right.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	right.custom_minimum_size.x = 90
	right.pressed.connect(_move.bind(1))
	row.add_child(right)

	# Dots
	dots_row = HBoxContainer.new()
	dots_row.alignment = BoxContainer.ALIGNMENT_CENTER
	dots_row.add_theme_constant_override("separation", 10)
	v.add_child(dots_row)
	for i in items.size():
		var d := ColorRect.new()
		d.custom_minimum_size = Vector2(16, 16)
		dots_row.add_child(d)
		dots.append(d)

	# Bottom buttons
	var bottom := HBoxContainer.new()
	bottom.add_theme_constant_override("separation", 12)
	v.add_child(bottom)
	var back_btn := UiStyle.make_button("BACK", UiStyle.LAVENDER, 72, 26, false)
	back_btn.size_flags_stretch_ratio = 1.0
	back_btn.pressed.connect(func(): back.emit())
	bottom.add_child(back_btn)
	var select_btn := UiStyle.make_button("SELECT", UiStyle.GREEN, 72, 30, false)
	select_btn.size_flags_stretch_ratio = 2.0
	select_btn.pressed.connect(func(): chosen.emit(idx))
	bottom.add_child(select_btn)

	reset()

## Call when the picker is shown, to start from the first option.
func reset() -> void:
	idx = 0
	_refresh()

func _move(dir: int) -> void:
	if items.is_empty():
		return
	idx = posmod(idx + dir, items.size())
	_refresh()

func _refresh() -> void:
	if items.is_empty():
		return
	var it: Dictionary = items[idx]
	var col: Color = it.get("color", accent)
	card.add_theme_stylebox_override("panel", UiStyle.panel(col, UiStyle.BLACK, 16))
	count_label.text = "%d / %d" % [idx + 1, items.size()]
	item_name.text = str(it.get("name", ""))
	tag_label.text = str(it.get("tag", ""))
	tag_label.add_theme_color_override("font_color", col)
	desc_label.text = str(it.get("desc", ""))
	for i in dots.size():
		dots[i].color = col if i == idx else Color("3a3a4a")

# Swipe left/right on the card
func _card_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			swipe_start = event.position
			swiping = true
		elif swiping:
			swiping = false
			var dx: float = event.position.x - swipe_start.x
			if absf(dx) > 60.0:
				_move(-1 if dx > 0.0 else 1)