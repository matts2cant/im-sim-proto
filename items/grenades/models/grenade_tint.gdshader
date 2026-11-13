// Kenney colormap model recoloured in one part (ADR 0131): the texels of the colormap inside
// `region` (u0, v0, u1, v1; default: the yellow-orange swatch grenade-a's caps use) take `tint`,
// shaded by their own brightness; the rest of the model keeps its colours. Used as a material
// override, so the model files are never edited.
shader_type spatial;

uniform sampler2D albedo_texture : source_color, filter_linear_mipmap, repeat_enable;
uniform vec4 region = vec4(0.4375, 0.5, 0.5, 0.75);
uniform vec4 tint : source_color = vec4(0.3, 0.85, 0.3, 1.0);
// Linear brightness of the region's texels that maps to the tint itself (darker texels darken it).
uniform float reference_luma = 0.6;
uniform float roughness = 0.6;

void fragment() {
	vec4 texel = texture(albedo_texture, UV);
	vec3 colour = texel.rgb;
	if (UV.x >= region.x && UV.x < region.z && UV.y >= region.y && UV.y < region.w) {
		float luma = dot(texel.rgb, vec3(0.299, 0.587, 0.114));
		colour = tint.rgb * clamp(luma / reference_luma, 0.5, 1.3);
	}
	ALBEDO = colour;
	ROUGHNESS = roughness;
}
