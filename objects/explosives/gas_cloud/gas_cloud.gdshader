// A gas cloud's puff (GasCloud, ADR 0131): an unshaded translucent sphere whose edges fade out
// (its alpha falls with the angle to the view) and that fades where it meets walls and the floor, so
// overlapping puffs read as one soft cloud; seen from inside it tints the view.
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix, shadows_disabled;

uniform vec4 color : source_color = vec4(0.62, 0.78, 0.36, 0.3);
// Higher: softer, thinner edges.
uniform float softness = 1.8;
// Metres over which it fades into the surfaces it meets.
uniform float proximity = 0.8;
// Opacity of the inner faces (seen from inside the puff, or through it): the view stays readable.
uniform float inside = 0.4;
uniform sampler2D depth_texture : hint_depth_texture, filter_linear_mipmap;

void fragment() {
	float facing = abs(dot(normalize(NORMAL), normalize(VIEW)));
	float alpha = color.a * pow(facing, softness);
	if (!FRONT_FACING) {
		alpha *= inside;
	}
	float depth = textureLod(depth_texture, SCREEN_UV, 0.0).r;
	vec4 behind = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, depth, 1.0);
	behind.xyz /= behind.w;
	alpha *= clamp(1.0 - smoothstep(behind.z + proximity, behind.z, VERTEX.z), 0.0, 1.0);
	ALBEDO = color.rgb;
	ALPHA = alpha;
}
