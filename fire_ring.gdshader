shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;

uniform sampler2D fire_tex : source_color, repeat_enable, filter_linear;

uniform float intensity : hint_range(0.0, 10.0) = 5.0;
uniform float t : hint_range(0.0, 1.0) = 0.0; // 0->1 over lifetime

// Expansion
uniform float r_start : hint_range(0.0, 0.3) = 0.05;
uniform float r_end : hint_range(0.5, 2.0) = 1.2;

// Texture
uniform float tex_scale : hint_range(0.5, 4.0) = 1.2;
uniform float rotation_speed : hint_range(0.0, 3.0) = 0.5;

// Breakup
uniform float breakup_strength : hint_range(0.0, 1.0) = 0.6;

// Color
uniform vec3 fire_color : source_color = vec3(1.0, 0.25, 0.0);
uniform vec3 hot_color : source_color = vec3(1.0, 0.95, 0.4);

void fragment() {
    vec2 p = UV * 2.0 - 1.0;
    float r = length(p);
    vec2 dir = normalize(p + 0.0001); // direction from center

    // Current expansion radius
    float expand_radius = mix(r_start, r_end, t);

    // Rotate texture slowly
    float angle = TIME * rotation_speed;
    vec2 rotated = vec2(
        p.x * cos(angle) - p.y * sin(angle),
        p.x * sin(angle) + p.y * cos(angle)
    );

    // Sample texture - pushed outward over time to simulate pieces drifting
    float outward_push = t * 0.3;
    vec2 tex_uv = (rotated - dir * outward_push) * tex_scale + 0.5;
    float fire = texture(fire_tex, tex_uv).r;

    // === SHAPE: Disc that becomes a ring ===
    // At t=0: solid disc (center_fade = 0)
    // At t=1: hollow ring (center_fade creates hole)
    float center_hole_size = t * expand_radius * 0.7; // hole grows with time
    float inner_edge = smoothstep(center_hole_size - 0.1, center_hole_size + 0.1, r);
    float outer_edge = 1.0 - smoothstep(expand_radius - 0.08, expand_radius + 0.15, r);
    float shape = inner_edge * outer_edge;

    // === BREAKUP: Fire chunks that separate ===
    // Use texture to create distinct chunks
    // Higher contrast = more distinct pieces
    float chunk_threshold = t * breakup_strength;
    float chunks = smoothstep(chunk_threshold - 0.15, chunk_threshold + 0.05, fire);

    // Edges break up more than inner parts
    float edge_breakup = smoothstep(0.3, 0.9, r / expand_radius);
    chunks = mix(chunks, chunks * fire, edge_breakup * t);

    // === OVERALL FADE ===
    float fade = 1.0 - smoothstep(0.75, 1.0, t);

    // === FINAL ALPHA ===
    float alpha = shape * chunks * fade;

    // === COLOR ===
    // Hot center (yellow/white), cooler edges (orange/red)
    float dist_ratio = r / max(expand_radius, 0.01);
    float heat = (1.0 - dist_ratio * 0.6) * (0.5 + fire * 0.5);
    heat = clamp(heat, 0.0, 1.0);
    vec3 col = mix(fire_color, hot_color, heat);

    // Brighten based on fire texture
    float brightness = 0.5 + fire * 0.7;

    ALBEDO = col * alpha * intensity * brightness;
    ALPHA = alpha;
}
