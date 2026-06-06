shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;

uniform sampler2D detail_tex : source_color; // your imported texture (grayscale-ish)
uniform float intensity = 6.0;

// Arc mask controls
uniform float arc_center : hint_range(0.0, 1.0) = 0.25;  // where the arc sits around the circle
uniform float arc_width  : hint_range(0.01, 0.5) = 0.18; // angular size of the arc
uniform float r_center   : hint_range(0.0, 2.0) = 0.75;  // radius of the arc inside the quad
uniform float r_width    : hint_range(0.01, 1.0) = 0.18; // thickness of the arc band

// Detail shaping
uniform float threshold  : hint_range(0.0, 1.0) = 0.18;  // raise to make it more "broken"
uniform float contrast   : hint_range(0.1, 10.0) = 2.2;  // higher = more filament-y

// Fire color controls
uniform vec3 fire_color : source_color = vec3(1.0, 0.25, 0.05); // orange-red base
uniform float hot_yellow : hint_range(0.0, 1.0) = 0.35;         // how much it shifts toward yellow at hottest parts

float sat(float x) { return clamp(x, 0.0, 1.0); }

void fragment() {
    // UV centered in -1..1
    vec2 p = UV * 2.0 - 1.0;
    float r = length(p);             // radial distance
    float a = atan(p.y, p.x);        // angle
    float u = a / (2.0 * PI) + 0.5;  // 0..1 angle coord

    // --- Arc mask: angle window (wrap-safe) ---
    float du = abs(u - arc_center);
    du = min(du, 1.0 - du); // wrap around edges
    float ang = smoothstep(arc_width, arc_width * 0.6, du);

    // --- Arc mask: radial band ---
    float dr = abs(r - r_center);
    float rad = smoothstep(r_width, r_width * 0.6, dr);

    float arc_mask = ang * rad; // 0..1

    // Sample your texture as detail (angle, radius) mapping
    vec2 d_uv = vec2(u * 2.0, r * 2.0);
    float d = texture(detail_tex, d_uv).r;

    // Turn grayscale into punchy alpha
    float detail = sat((d - threshold) * contrast);

    float alpha = arc_mask * detail;

    // Color: orange-red base, slightly yellower at hottest (highest alpha)
    vec3 hot_color = vec3(1.0, 0.75, 0.15);
    vec3 fire = mix(fire_color, hot_color, sat(alpha) * hot_yellow);

    vec3 col = fire * alpha * intensity;

    ALBEDO = col;
    ALPHA = alpha;
}
