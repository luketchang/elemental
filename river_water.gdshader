shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled, specular_schlick_ggx;

// Gaea river data
uniform sampler2D river_mask : filter_linear, repeat_disable;
uniform sampler2D river_depth : filter_linear, repeat_disable;
uniform sampler2D river_direction : filter_linear, repeat_disable;

// Water appearance
uniform vec4 shallow_color : source_color = vec4(0.2, 0.6, 0.8, 0.5);
uniform vec4 deep_color : source_color = vec4(0.05, 0.15, 0.3, 0.9);
uniform float depth_contrast : hint_range(0.5, 5.0) = 2.0;

// Flow animation
uniform sampler2D water_normal_map : hint_normal, filter_linear, repeat_enable;
uniform float flow_speed : hint_range(0.0, 2.0) = 0.3;
uniform float normal_tile_scale : hint_range(1.0, 50.0) = 12.0;
uniform float normal_strength : hint_range(0.0, 2.0) = 0.6;

// Surface properties
uniform float specular_amount : hint_range(0.0, 1.0) = 0.6;
uniform float roughness_amount : hint_range(0.0, 1.0) = 0.15;
uniform float metallic_amount : hint_range(0.0, 1.0) = 0.1;

// Terrain matching - SET THESE to match your Terrain3D import
uniform float terrain_height_scale : hint_range(1.0, 2000.0) = 300.0;
uniform float terrain_size : hint_range(1.0, 4096.0) = 1024.0;

// Vertex offset to sit water slightly above carved riverbed
uniform float water_surface_offset : hint_range(0.0, 2.0) = 0.15;

varying vec2 world_uv;

void vertex() {
	// Calculate UV from world XZ position (0-1 across terrain)
	vec3 world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_uv = world_pos.xz / terrain_size;

	// Sample river mask at this vertex to discard non-river vertices early
	float mask = texture(river_mask, world_uv).r;

	// Push river vertices up slightly so water sits on carved riverbed
	VERTEX.y += water_surface_offset * mask;
}

void fragment() {
	// Sample river mask - discard non-river pixels
	float mask = texture(river_mask, world_uv).r;
	if (mask < 0.1) {
		discard;
	}

	// Sample depth for color blending
	float depth_val = texture(river_depth, world_uv).r;
	depth_val = clamp(pow(depth_val, 1.0 / depth_contrast), 0.0, 1.0);

	// Blend shallow to deep color based on depth
	vec4 water_color = mix(shallow_color, deep_color, depth_val);

	// Sample flow direction (RG channels, 0.5 = no flow, 0-1 range)
	vec2 flow_dir = texture(river_direction, world_uv).rg;
	flow_dir = (flow_dir - 0.5) * 2.0; // Remap to -1..1

	// Dual-layer flow map animation (avoids visible sliding artifacts)
	float t = TIME * flow_speed;
	float phase0 = fract(t);
	float phase1 = fract(t + 0.5);

	// Offset UVs by flow direction over time
	vec2 tiled_uv = world_uv * normal_tile_scale;
	vec2 uv0 = tiled_uv + flow_dir * phase0;
	vec2 uv1 = tiled_uv + flow_dir * phase1;

	// Sample normal map at both phases
	vec3 normal0 = texture(water_normal_map, uv0).rgb;
	vec3 normal1 = texture(water_normal_map, uv1).rgb;

	// Blend between phases using triangle wave (cross-fade)
	float blend = abs(2.0 * phase0 - 1.0);
	vec3 flow_normal = mix(normal0, normal1, blend);

	// Apply normal strength
	flow_normal = mix(vec3(0.5, 0.5, 1.0), flow_normal, normal_strength);

	// Soften edges of river mask for anti-aliasing
	float edge_fade = smoothstep(0.1, 0.4, mask);

	ALBEDO = water_color.rgb;
	ALPHA = water_color.a * edge_fade;
	NORMAL_MAP = flow_normal;
	SPECULAR = specular_amount;
	ROUGHNESS = roughness_amount;
	METALLIC = metallic_amount;
}
