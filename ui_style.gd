class_name UiStyle
extends RefCounted

const WHITE := Color("ffffff")
const BLACK := Color("000000")
const INK := Color("07070f")
const NAVY := Color("0d0d1f")
const YELLOW := Color("ffd23f")
const ORANGE := Color("ff8a2b")
const RED := Color("ff4d4d")
const PINK := Color("ff8fb8")
const GREEN := Color("5ad66b")
const BLUE := Color("4db8ff")
const PURPLE := Color("a86bff")
const LAVENDER := Color("9a9ab8")

const HEART := [
	".WX.XX.",
	"XXXXXXX",
	"XXXXXXX",
	".XXXXX.",
	"..XXX..",
	"...X...",
]

static var _tex_cache := {}

static func heart_texture(color: Color = RED) -> ImageTexture:
	var key := color.to_html()
	if _tex_cache.has(key):
		return _tex_cache[key]
	var img := Image.create(7, 6, false, Image.FORMAT_RGBA8)
	for y in HEART.size():
		for x in 7:
			var ch: String = HEART[y][x]
			if ch == "X":
				img.set_pixel(x, y, color)
			elif ch == "W":
				img.set_pixel(x, y, Color.WHITE)
	var tex := ImageTexture.create_from_image(img)
	_tex_cache[key] = tex
	return tex

static func _btn_box(bg: Color, border: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(0)
	sb.set_border_width_all(4)
	sb.border_color = border
	sb.set_content_margin_all(10)
	sb.anti_aliasing = false
	return sb

## Generic box: dark fill, colored border.
static func box(color: Color, _radius: int = 0, margin: int = 12) -> StyleBoxFlat:
	var sb := _btn_box(INK, color)
	sb.set_content_margin_all(margin)
	return sb

## Undertale-style dialogue box.
static func panel(border: Color = WHITE, bg: Color = NAVY, margin: int = 22) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(0)
	sb.set_content_margin_all(margin)
	sb.set_border_width_all(6)
	sb.border_color = border
	sb.anti_aliasing = false
	return sb

static func frame(border: Color = WHITE, bg: Color = NAVY, margin: int = 22) -> StyleBoxFlat:
	return panel(border, bg, margin)

static func bar_bg() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("3a0d14")
	sb.set_corner_radius_all(0)
	sb.set_border_width_all(4)
	sb.border_color = WHITE
	sb.anti_aliasing = false
	return sb

static func bar_fill(color: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.set_corner_radius_all(0)
	sb.anti_aliasing = false
	return sb

static func outline(label: Label, size: int = 6) -> void:
	label.add_theme_color_override("font_outline_color", BLACK)
	label.add_theme_constant_override("outline_size", size)

static func _add_soul(btn: Button) -> void:
	if btn.has_node("Soul") or btn.text.length() <= 2:
		return
	var soul := TextureRect.new()
	soul.name = "Soul"
	soul.texture = heart_texture(RED)
	soul.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	soul.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	soul.stretch_mode = TextureRect.STRETCH_SCALE
	soul.mouse_filter = Control.MOUSE_FILTER_IGNORE
	soul.visible = false
	btn.add_child(soul)
	soul.set_anchors_and_offsets_preset(Control.PRESET_CENTER_LEFT)
	soul.offset_left = 16.0
	soul.offset_right = 44.0
	soul.offset_top = -12.0
	soul.offset_bottom = 12.0
	btn.mouse_entered.connect(func(): soul.visible = not btn.disabled)
	btn.mouse_exited.connect(func(): soul.visible = false)

static func style_button(btn: Button, color: Color, height: float = 76.0, font_size: int = 28, soul: bool = true) -> void:
	btn.custom_minimum_size.y = height
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.add_theme_font_size_override("font_size", font_size)
	btn.add_theme_stylebox_override("normal", _btn_box(INK, color))
	btn.add_theme_stylebox_override("hover", _btn_box(color.darkened(0.8), YELLOW))
	btn.add_theme_stylebox_override("pressed", _btn_box(color.darkened(0.55), WHITE))
	btn.add_theme_stylebox_override("disabled", _btn_box(INK, Color("3a3a4a")))
	btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	btn.add_theme_color_override("font_color", color.lightened(0.5))
	btn.add_theme_color_override("font_hover_color", YELLOW)
	btn.add_theme_color_override("font_pressed_color", WHITE)
	btn.add_theme_color_override("font_disabled_color", Color("55556a"))
	if soul:
		_add_soul(btn)

static func make_button(text: String, color: Color, height: float = 76.0, font_size: int = 28, soul: bool = true) -> Button:
	var b := Button.new()
	b.text = text
	style_button(b, color, height, font_size, soul)
	return b
