shader_type spatial;
render_mode unshaded, shadows_disabled;

// A device's status LED (StatusLight, M12c): one shared material, the colour and the blink per
// instance (GeometryInstance3D.set_instance_shader_parameter), so a blinking LED costs no script.

instance uniform vec4 led_color : source_color = vec4(0.06, 0.07, 0.06, 1.0);
// 1: blinks (about 0.4 s on, 0.4 s off); 0: steady.
instance uniform float blink = 0.0;

void fragment() {
	float lit = 1.0;
	if (blink > 0.5) {
		lit = step(0.5, fract(TIME * 1.25));
	}
	ALBEDO = led_color.rgb * mix(0.12, 1.0, lit);
}
