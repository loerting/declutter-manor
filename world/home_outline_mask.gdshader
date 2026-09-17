shader_type spatial;
// Marks where the outlined piece is on screen, and draws nothing, so the home outline is drawn only round it
// (`home_outline.gdshader`). Without the depth test: a piece partly behind another keeps its whole shape
// marked, and its outline stays a line.
render_mode unshaded, shadows_disabled, fog_disabled, depth_draw_never, depth_test_disabled;
stencil_mode write, compare_always, 64;

void fragment() {
	ALBEDO = vec3(0.0);
	ALPHA = 0.0;
}
