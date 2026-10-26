class_name UiStyle
extends RefCounted

static func box(color: Color, radius: int = 16, margin: int = 12) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.set_corner_radius_all(radius)
	sb.set_content_margin_all(margin)
	return sb

static func style_button(btn: Button, color: Color, height: float = 76.0, font_size: int = 28) -> void:
	btn.custom_minimum_size.y = height
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.add_theme_font_size_override("font_size", font_size)
	btn.add_theme_stylebox_override("normal", box(color))
	btn.add_theme_stylebox_override("hover", box(color.lightened(0.15)))
	btn.add_theme_stylebox_override("pressed", box(color.darkened(0.25)))
	btn.add_theme_stylebox_override("disabled", box(Color("3a3d45")))
	btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	btn.add_theme_color_override("font_color", Color.WHITE)
	btn.add_theme_color_override("font_hover_color", Color.WHITE)
	btn.add_theme_color_override("font_pressed_color", Color.WHITE)
	btn.add_theme_color_override("font_disabled_color", Color(1, 1, 1, 0.3))

static func make_button(text: String, color: Color, height: float = 76.0, font_size: int = 28) -> Button:
	var b := Button.new()
	b.text = text
	style_button(b, color, height, font_size)
	return b
