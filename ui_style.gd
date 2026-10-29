class_name UiStyle
extends RefCounted

# PICO-8 style palette
const PINK := Color("ff77a8")
const RED := Color("ff004d")
const ORANGE := Color("ffa300")
const YELLOW := Color("ffec27")
const GREEN := Color("00e436")
const BLUE := Color("29adff")
const PURPLE := Color("7e2553")
const LAVENDER := Color("83769c")
const NAVY := Color("1d2b53")
const INK := Color("0b0b1e")

## Chunky pixel box: thick border, extra-thick bottom edge (looks 3D).
static func box(color: Color, _radius: int = 0, margin: int = 12) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.set_corner_radius_all(0)
	sb.set_content_margin_all(margin)
	sb.border_width_left = 4
	sb.border_width_top = 4
	sb.border_width_right = 4
	sb.border_width_bottom = 8
	sb.border_color = color.darkened(0.55)
	sb.anti_aliasing = false
	return sb

## Button pushed down: shorter bottom edge, content shifts down.
static func box_pressed(color: Color, margin: int = 12) -> StyleBoxFlat:
	var sb := box(color, 0, margin)
	sb.border_width_bottom = 4
	sb.content_margin_top = margin + 4
	return sb

## Framed panel with a bright colored border.
static func panel(border: Color, bg: Color = NAVY, margin: int = 22) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(0)
	sb.set_content_margin_all(margin)
	sb.set_border_width_all(6)
	sb.border_color = border
	sb.anti_aliasing = false
	return sb

static func bar_bg() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = INK
	sb.set_corner_radius_all(0)
	sb.set_border_width_all(3)
	sb.border_color = LAVENDER
	sb.anti_aliasing = false
	return sb

static func bar_fill(color: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.set_corner_radius_all(0)
	sb.set_border_width_all(3)
	sb.border_color = color.darkened(0.5)
	sb.anti_aliasing = false
	return sb

## Dark outline so text pops on any background.
static func outline(label: Label, size: int = 6) -> void:
	label.add_theme_color_override("font_outline_color", INK)
	label.add_theme_constant_override("outline_size", size)

static func style_button(btn: Button, color: Color, height: float = 76.0, font_size: int = 28) -> void:
	btn.custom_minimum_size.y = height
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.add_theme_font_size_override("font_size", font_size)
	btn.add_theme_stylebox_override("normal", box(color))
	btn.add_theme_stylebox_override("hover", box(color.lightened(0.2)))
	btn.add_theme_stylebox_override("pressed", box_pressed(color.darkened(0.15)))
	btn.add_theme_stylebox_override("disabled", box(Color("3a3d55")))
	btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	for c in ["font_color", "font_hover_color", "font_pressed_color"]:
		btn.add_theme_color_override(c, Color.WHITE)
	btn.add_theme_color_override("font_disabled_color", Color(1, 1, 1, 0.35))
	btn.add_theme_color_override("font_outline_color", INK)
	btn.add_theme_constant_override("outline_size", 4)

static func make_button(text: String, color: Color, height: float = 76.0, font_size: int = 28) -> Button:
	var b := Button.new()
	b.text = text
	style_button(b, color, height, font_size)
	return b
