shader_type canvas_item;
// Grim mood pass over the whole screen: heavy soot vignette + faint per-design-pixel grain that changes a few
// times per second (stays on the pixel grid, so it reads as dithered dust, not blur).
// Drawn as a dark overlay with varying alpha (cheap on WebGL2, no screen texture read).

uniform vec2 design_size = vec2(360.0, 640.0);
uniform float pixel_scale = 3.0;          // physical pixels per design pixel
uniform float scan_strength = 0.0;        // kept for compatibility (no scanlines in the 16-bit look)
uniform float vignette = 0.55;
uniform float grain = 0.05;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 cell = floor(uv * design_size);
	float a = 0.0;
	vec2 d = uv - 0.5;
	d.x *= design_size.x / design_size.y;
	float v = dot(d, d) * 2.2;
	a += smoothstep(0.2, 1.1, v) * vignette;
	a += step(0.5, hash(cell + floor(TIME * 6.0) * 17.0)) * grain;
	COLOR = vec4(0.03, 0.02, 0.015, clamp(a, 0.0, 0.85));
}
