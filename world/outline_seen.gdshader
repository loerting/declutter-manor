shader_type spatial;
// The part of an outline in plain sight, at full strength (`outline.gdshaderinc`).
render_mode unshaded, cull_front, shadows_disabled, fog_disabled, depth_draw_never;
stencil_mode read, compare_not_equal, 64;

#include "res://world/outline.gdshaderinc"
