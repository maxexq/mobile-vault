shader_type canvas_item;
// MV-473: an equipment rarity light mask (tools/art/ui.py fx_gear_*) holds three grey codes (gray2 / gray4 / gray6 =
// faint / lit / hot). Decode the code, then colour it with the approved per-rarity emission and hot colours, so the
// atlas keeps the master palette and the metal frame and item are never tinted.
uniform vec4 base_col : source_color = vec4(1.0);
uniform vec4 hot_col : source_color = vec4(1.0);

void fragment() {
	vec4 m = texture(TEXTURE, UV);
	if (m.a < 0.5) {
		discard;
	}
	vec3 e;
	if (m.r < 0.24) {
		e = base_col.rgb * 0.18;        // gray2: the outside aura, faint
	} else if (m.r < 0.47) {
		e = base_col.rgb * 0.75;        // gray4: the lit rim
	} else {
		e = mix(base_col.rgb, hot_col.rgb, 0.65);   // gray6: highlights, motes, embers
	}
	COLOR = vec4(e, 1.0);
}
