shader_type canvas_item;
// MV-604: the Room Close-up blur from a cached frame. Main renders focus_blur.gdshader once, reads the world
// viewport back and shows it here, so the full-screen screen copy + 16-tap blur stop running every frame.
// The focused room (`focus_rect`, SCREEN_UV space) stays see-through: it keeps animating under this overlay.

uniform sampler2D snap_tex : filter_nearest;
uniform vec4 focus_rect = vec4(0.0);          // x, y, w, h in SCREEN_UV

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 lo = focus_rect.xy;
	vec2 hi = focus_rect.xy + focus_rect.zw;
	if (uv.x >= lo.x && uv.x <= hi.x && uv.y >= lo.y && uv.y <= hi.y) {
		COLOR = vec4(0.0);
	} else {
		COLOR = vec4(texture(snap_tex, uv).rgb, 1.0);
	}
}
