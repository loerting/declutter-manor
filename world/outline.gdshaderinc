// The line of an outline (`Outline`): a hull behind the outlined meshes, grown in screen space, so the line is as
// wide on a cupboard across the house as on one in reach. Its normals are averaged per corner, so a box's faces
// grow into one closed shell instead of splitting apart at every edge.
//
// A drawer front is flush with the carcass round it, which hides a hull drawn behind it. So the hull is drawn
// `pull` metres nearer the eye, and never over the outlined thing itself: `outline_mask.gdshader` has marked its
// own pixels in the stencil first. What is left is a line round the outside.

uniform vec4 line_color : source_color = vec4(1.0);
// Pixels at 1080 lines.
uniform float width = 2.5;
uniform float pull = 0.05;

void vertex() {
	vec4 view = MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	view.xyz += normalize(-view.xyz) * pull;
	vec4 clip = PROJECTION_MATRIX * view;
	vec3 view_normal = normalize(MODELVIEW_NORMAL_MATRIX * NORMAL);
	vec2 across = (PROJECTION_MATRIX * vec4(view_normal, 0.0)).xy;
	float reach = length(across);
	if (reach > 1e-5) {
		clip.xy += across / reach * width * (VIEWPORT_SIZE.y / 1080.0) * 2.0 / VIEWPORT_SIZE * clip.w;
	}
	POSITION = clip;
}

void fragment() {
	ALBEDO = line_color.rgb;
	ALPHA = line_color.a;
}
