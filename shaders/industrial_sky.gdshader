shader_type canvas_item;
render_mode unshaded;

uniform sampler2D next_sky : filter_nearest, repeat_disable;
uniform float phase : hint_range(0.0, 1.0) = 0.0;
varying vec4 item_color;

void vertex() { item_color = COLOR; }

float threshold(ivec2 p) {
	int x = p.x % 4;
	int y = p.y % 4;
	int low = ((x % 2 + y % 2) % 2) * 2 + y % 2;
	int high = (((x / 2) % 2 + (y / 2) % 2) % 2) * 2 + (y / 2) % 2;
	return (float(low * 4 + high) + 0.5) / 16.0;
}

void fragment() {
	ivec2 p = ivec2(floor(UV / TEXTURE_PIXEL_SIZE));
	vec4 a = texture(TEXTURE, UV);
	vec4 b = texture(next_sky, UV);
	COLOR = (phase > threshold(p) ? b : a) * item_color;
}
