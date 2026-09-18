shader_type spatial;
// The whole outline, through every wall, floor and door between it and the eye, drawn fainter; the part in plain
// sight is drawn again over it by `outline_seen.gdshader` (`outline.gdshaderinc`).
render_mode unshaded, cull_front, shadows_disabled, fog_disabled, depth_draw_never, depth_test_disabled;
stencil_mode read, compare_not_equal, 64;

#include "res://world/outline.gdshaderinc"
