shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled;

// CylinderMesh is authored 1 unit tall. Its local -Y end is the trail's
// muzzle-side tail; +Y points toward the projectile tip / resolved impact.
// Use local geometry rather than UV orientation so rotation/scale is safe.
uniform vec4 trail_color : source_color = vec4(1.0, 0.78, 0.27, 1.0);
uniform float start_brightness : hint_range(0.0, 12.0) = 4.0;
uniform float end_brightness : hint_range(0.0, 12.0) = 0.3;
uniform float start_opacity : hint_range(0.0, 1.0) = 0.95;
uniform float end_opacity : hint_range(0.0, 1.0) = 0.0;
uniform float life_fade : hint_range(0.0, 1.0) = 1.0;

varying float trail_progress;

void vertex() {
    trail_progress = clamp(VERTEX.y + 0.5, 0.0, 1.0);
}

void fragment() {
    float brightness = mix(start_brightness, end_brightness, trail_progress);
    float opacity = mix(start_opacity, end_opacity, trail_progress);
    ALBEDO = trail_color.rgb;
    EMISSION = trail_color.rgb * brightness * life_fade;
    ALPHA = trail_color.a * opacity * life_fade;
}
