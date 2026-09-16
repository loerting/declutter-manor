shader_type canvas_item;
// The HUD's panels: the room behind them, blurred, under a dark tint, so text reads the same over a white
// wall and inside a dark cupboard. The panel's style box still draws the shape: its alpha is the coverage
// (rounded corners, anti-aliased edges) and its colour is the tint, a lighter one on the border.

uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;
// Mip level of the screen read back: 3 is an eighth of the resolution, soft enough that no edge behind a
// label competes with its letters.
uniform float blur_lod = 3.0;
// How much of the tint lies over the blurred room.
uniform float tint_amount = 0.62;

void fragment() {
	vec3 behind = textureLod(screen_texture, SCREEN_UV, blur_lod).rgb;
	COLOR = vec4(mix(behind, COLOR.rgb, tint_amount), COLOR.a);
}
