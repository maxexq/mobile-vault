shader_type canvas_item;
// MV-711 crew over a v3 room (rule crew-room-blend, Parames 2026-10-29), the game port of crew_blend.py:
// 70 % saturation, multiplied by the room's colour cast, light falloff from the room lamp (set per actor from its x),
// outline pixels (luma < 40) take the room's darkest colour. `dim` darkens with the room in a power-out.
uniform vec3 tint = vec3(1.0);
uniform vec3 dark_col = vec3(0.05);
uniform float light = 0.95;
uniform float dim = 0.0;
// MV-724: how much of the room grade is applied (tune crew_v3.grade). 1 = the MV-711 grade (crew read too dark),
// 0 = the sprite's own colours. The power-out `dim` is not scaled by it.
uniform float grade = 1.0;
// MV-724: brighten + saturate the crew toward the v2 crew look (tune crew_v3.lift). 1 = off; above 1 lifts the
// mid-tones (gamma 1/lift) and saturation a little. Outline pixels stay dark so the silhouette stays crisp.
uniform float lift = 1.0;

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float l = dot(c.rgb, vec3(0.299, 0.587, 0.114));
	vec3 rgb = mix(vec3(l), c.rgb, 1.0 - 0.3 * grade) * mix(vec3(1.0), tint, grade) * mix(1.0, light, grade);
	if (l < 40.0 / 255.0) {
		rgb = mix(rgb, dark_col, grade);
	} else if (lift != 1.0) {
		rgb = pow(max(rgb, vec3(0.0)), vec3(1.0 / lift));
		float l2 = dot(rgb, vec3(0.299, 0.587, 0.114));
		rgb = clamp(mix(vec3(l2), rgb, 1.0 + 0.6 * (lift - 1.0)), 0.0, 1.0);
	}
	rgb = mix(rgb, rgb * vec3(0.30, 0.27, 0.38), dim);
	COLOR = vec4(rgb, c.a) * COLOR;
}
