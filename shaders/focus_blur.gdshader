shader_type canvas_item;
// Full-screen overlay used by Room Close-up:
// blurs + darkens everything except `focus_rect` (in SCREEN_UV space) and draws a pixel frame around it.
// Single pass golden-angle disc blur -> works on the Compatibility (WebGL2) renderer.

uniform sampler2D screen_tex : hint_screen_texture, filter_linear;
uniform float amount : hint_range(0.0, 1.0) = 0.0;
uniform vec4 focus_rect = vec4(0.0);          // x, y, w, h in SCREEN_UV
uniform float radius_uv = 0.012;              // blur radius relative to screen height
uniform vec4 dim_color : source_color = vec4(0.03, 0.025, 0.02, 0.6);
uniform vec4 frame_color : source_color = vec4(0.85, 0.66, 0.26, 1.0);
uniform vec2 px_uv = vec2(0.001, 0.0018);     // size of one UI pixel in UV (1/viewport)

const int SAMPLES = 16;

void fragment() {
	vec2 uv = SCREEN_UV;
	vec3 col = texture(screen_tex, uv).rgb;
	vec2 lo = focus_rect.xy;
	vec2 hi = focus_rect.xy + focus_rect.zw;
	bool inside = uv.x >= lo.x && uv.x <= hi.x && uv.y >= lo.y && uv.y <= hi.y;
	if (!inside && amount > 0.001) {
		float aspect = SCREEN_PIXEL_SIZE.x / SCREEN_PIXEL_SIZE.y;
		vec3 acc = col;
		for (int i = 1; i < SAMPLES; i++) {
			float a = float(i) * 2.39996;
			float r = sqrt(float(i) / float(SAMPLES)) * radius_uv * amount;
			vec2 o = vec2(cos(a) * aspect, sin(a)) * r;
			acc += texture(screen_tex, uv + o).rgb;
		}
		col = acc / float(SAMPLES);
		col = mix(col, dim_color.rgb, dim_color.a * amount);
		// 1px frame hugging the focus rect
		vec2 t = px_uv * 1.0;
		bool in_frame = uv.x >= lo.x - t.x && uv.x <= hi.x + t.x && uv.y >= lo.y - t.y && uv.y <= hi.y + t.y;
		if (in_frame) {
			col = mix(col, frame_color.rgb, amount);
		}
	}
	COLOR = vec4(col, 1.0);
}
