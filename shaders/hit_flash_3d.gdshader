shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled;

uniform float flash_amount : hint_range(0.0, 1.0) = 0.0;
uniform vec4 flash_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);

void fragment() {
	ALBEDO = flash_color.rgb;
	ALPHA = flash_amount * flash_color.a;
}
