shader_type canvas_item;
// A light line round everything drawn in an item picture, so a dark item stands out on the dark card
// (`Portraits`). Writes straight alpha: the picture is read back and drawn again later.
render_mode blend_disabled, unshaded;

uniform vec4 line_color : source_color = vec4(0.961, 0.937, 0.894, 0.7);
uniform float width = 3.0;

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float near = 0.0;
	for (int i = 0; i < 16; i++) {
		float a = float(i) * TAU / 16.0;
		near = max(near, texture(TEXTURE, UV + vec2(cos(a), sin(a)) * width * TEXTURE_PIXEL_SIZE).a);
	}
	float line_a = line_color.a * smoothstep(0.05, 0.5, near);
	float a = c.a + line_a * (1.0 - c.a);
	vec3 rgb = a > 0.0 ? (c.rgb * c.a + line_color.rgb * line_a * (1.0 - c.a)) / a : vec3(0.0);
	COLOR = vec4(rgb, a);
}
