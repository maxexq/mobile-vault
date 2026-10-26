shader_type canvas_item;
// MV-473: an empty equipment slot shows its slot icon as a quiet grey silhouette (no rarity, no colour)
void fragment() {
	vec4 t = texture(TEXTURE, UV);
	float l = dot(t.rgb, vec3(0.299, 0.587, 0.114));
	COLOR = vec4(vec3(0.16 + l * 0.22), t.a * 0.85);
}
