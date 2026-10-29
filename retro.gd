extends CanvasLayer

const PIXEL_SIZE := 2.0    # bigger = chunkier (2 = subtle, 4 = very blocky)
const COLOR_LEVELS := 6.0  # fewer = more limited palette
const SCANLINE := 0.0    # 0 turns scanlines off

const CODE := """
shader_type canvas_item;
uniform sampler2D screen_tex : hint_screen_texture, filter_nearest, repeat_disable;
uniform float pixel_size = 3.0;
uniform float levels = 6.0;
uniform float scanline = 0.1;

void fragment() {
	vec2 res = 1.0 / SCREEN_PIXEL_SIZE;
	vec2 cell = vec2(pixel_size) * (res.x / 1280.0);
	vec2 snapped = (floor(FRAGCOORD.xy / cell) + 0.5) * cell;
	vec3 c = texture(screen_tex, snapped / res).rgb;

	c = floor(c * levels + 0.5) / levels;

	float row = mod(floor(FRAGCOORD.y / cell.y), 2.0);
	c *= 1.0 - scanline * row;

	COLOR = vec4(c, 1.0);
}
"""

func _ready() -> void:
	layer = 1   # UI layers are moved to 2 so text and buttons stay crisp
	var rect := ColorRect.new()
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(rect)
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var sh := Shader.new()
	sh.code = CODE
	var mat := ShaderMaterial.new()
	mat.shader = sh
	mat.set_shader_parameter("pixel_size", PIXEL_SIZE)
	mat.set_shader_parameter("levels", COLOR_LEVELS)
	mat.set_shader_parameter("scanline", SCANLINE)
	rect.material = mat
