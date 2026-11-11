shader_type canvas_item;
// MV-770 Weather v2 fog: 2 px columns ride two slow sine swells so a fog bank rolls and breathes.
// Vertex colour carries the bank: r = bank index / 32, g = 1 for the faint counter-drifting copy, a = alpha.
// Draw each bank with `pad` rows of empty space above and below (the source rect reaches past the texture).
uniform vec4 tint : source_color = vec4(1.0);
uniform float pad = 4.0;
varying vec4 vcol;
varying float wx;

void vertex() {
	vcol = COLOR;
	wx = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).x;
}

void fragment() {
	float i = floor(vcol.r * 32.0 + 0.5);
	bool copy = vcol.g > 0.5;
	float ph = copy ? 2.1 : 0.0;
	float am = copy ? -1.0 : 1.0;
	float cx = floor(wx / 2.0) * 2.0;
	float dy = floor(am * (sin(TIME * 0.62 + cx * 0.045 + i + ph) * 1.7 + sin(TIME * 0.29 + cx * 0.017 + i * 2.0 + ph) * 1.3) + 0.5);
	vec2 uv = UV - vec2(0.0, dy * TEXTURE_PIXEL_SIZE.y);
	vec4 c = vec4(0.0);
	if (uv.y >= 0.0 && uv.y <= 1.0 && uv.x >= 0.0 && uv.x <= 1.0) {
		c = texture(TEXTURE, uv);
	}
	COLOR = vec4(c.rgb * tint.rgb, c.a * vcol.a * tint.a);
}
