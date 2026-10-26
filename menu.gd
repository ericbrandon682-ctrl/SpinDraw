extends Control

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var bg := ColorRect.new()
	bg.color = Color("14161c")
	add_child(bg)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var center := CenterContainer.new()
	add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var box := VBoxContainer.new()
	box.custom_minimum_size.x = 440
	box.add_theme_constant_override("separation", 22)
	center.add_child(box)

	var title := Label.new()
	title.text = "SPIN DRAW"
	title.add_theme_font_size_override("font_size", 76)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)

	var count := Label.new()
	count.text = "Saved tops: %d / %d" % [GameData.tops.size(), GameData.MAX_TOPS]
	count.add_theme_font_size_override("font_size", 26)
	count.add_theme_color_override("font_color", Color("9aa3b5"))
	count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(count)

	var draw_btn := UiStyle.make_button("DRAW", Color("2fbf71"), 100, 36)
	draw_btn.pressed.connect(func(): get_tree().change_scene_to_file("res://main.tscn"))
	box.add_child(draw_btn)

	var battle_btn := UiStyle.make_button("BATTLE", Color("c94f5a"), 100, 36)
	battle_btn.disabled = GameData.tops.is_empty()
	battle_btn.pressed.connect(func(): get_tree().change_scene_to_file("res://battle.tscn"))
	box.add_child(battle_btn)

	if GameData.tops.is_empty():
		count.text += "\nDraw a top first to unlock Battle"
