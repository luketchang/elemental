shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled, unshaded;

uniform sampler2D river_mask : filter_linear, repeat_disable;
uniform sampler2D river_height : filter_linear, repeat_disable;
uniform vec4 water_color : source_color = vec4(0.1, 0.4, 0.8, 0.7);
uniform float terrain_size : hint_range(1.0, 4096.0) = 1024.0;
// Must match your Terrain3D height scale
uniform float height_scale : hint_range(1.0, 2000.0) = 500.0;
// The max normalized height used when encoding the PNG (0.16)
uniform float height_range : hint_range(0.01, 1.0) = 0.16;
// Small offset to keep water above the riverbed
uniform float water_nudge : hint_range(0.0, 5.0) = 0.3;

varying vec2 world_uv;

void vertex() {
	vec3 world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_uv = world_pos.xz / terrain_size;

	// Sample height texture and convert to world height
	float h = texture(river_height, world_uv).r;
	// PNG value (0-1) -> normalized height (0-0.16) -> world height (0-80m)
	float world_height = h * height_range * height_scale + water_nudge;
	VERTEX.y = world_height - world_pos.y;
}

void fragment() {
	vec2 uv = clamp(world_uv, 0.0, 1.0);
	float mask = texture(river_mask, uv).r;

	if (mask < 0.1) {
		discard;
	}
	ALBEDO = water_color.rgb;
	ALPHA = water_color.a;
}
