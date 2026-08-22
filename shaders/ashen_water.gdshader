shader_type spatial;
render_mode blend_mix, cull_disabled, depth_draw_opaque;

uniform vec4 shallow_color : source_color = vec4(0.06, 0.24, 0.25, 0.82);
uniform vec4 deep_color : source_color = vec4(0.08, 0.03, 0.16, 0.9);
uniform vec4 rune_glow : source_color = vec4(0.18, 0.72, 0.78, 1.0);
uniform float wave_speed : hint_range(0.0, 2.0, 0.05) = 0.22;
uniform float wave_scale : hint_range(1.0, 24.0, 0.5) = 9.0;

void vertex() {
	VERTEX.y += sin((VERTEX.x + VERTEX.z) * 0.7 + TIME * wave_speed * 6.0) * 0.025;
}

void fragment() {
	float first_wave = sin((UV.x + TIME * wave_speed) * wave_scale) * 0.5 + 0.5;
	float second_wave = sin((UV.y - TIME * wave_speed * 0.73) * wave_scale * 1.37) * 0.5 + 0.5;
	float wave = smoothstep(0.42, 0.72, first_wave * second_wave);
	vec4 water = mix(deep_color, shallow_color, wave);
	ALBEDO = water.rgb;
	ROUGHNESS = 0.38;
	METALLIC = 0.08;
	EMISSION = rune_glow.rgb * wave * 0.18;
	ALPHA = water.a;
}
