#if defined(VERTEX) || __VERSION__ > 100 || defined(GL_FRAGMENT_PRECISION_HIGH)
    #define PRECISION highp
#else
    #define PRECISION mediump
#endif

extern PRECISION vec2 singed;
extern PRECISION number dissolve;
extern PRECISION number time;
extern PRECISION vec4 texture_details;
extern PRECISION vec2 image_details;
extern bool shadow;
extern PRECISION vec4 burn_colour_1;
extern PRECISION vec4 burn_colour_2;

extern PRECISION vec2 mouse_screen_pos;
extern PRECISION float hovering;
extern PRECISION float screen_scale;

float saturate1(float x) { return clamp(x, 0.0, 1.0); }
vec3 saturate3(vec3 x) { return clamp(x, vec3(0.0), vec3(1.0)); }

float hash12(vec2 p) {
    vec3 p3 = fract(vec3(p.xyx) * 0.1031);
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.x + p3.y) * p3.z);
}

float valueNoise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    float a = hash12(i);
    float b = hash12(i + vec2(1.0, 0.0));
    float c = hash12(i + vec2(0.0, 1.0));
    float d = hash12(i + vec2(1.0, 1.0));
    vec2 u = f * f * (3.0 - 2.0 * f);
    return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

float fbm(vec2 p) {
    float v = 0.0;
    float a = 0.5;
    v += a * valueNoise(p); p *= 2.02; a *= 0.50;
    v += a * valueNoise(p); p *= 2.03; a *= 0.50;
    v += a * valueNoise(p); p *= 2.01; a *= 0.50;
    v += a * valueNoise(p); p *= 2.04; a *= 0.50;
    v += a * valueNoise(p);
    return v;
}

float minEdgeDistance(vec2 uv) {
    return min(min(uv.x, 1.0 - uv.x), min(uv.y, 1.0 - uv.y));
}

float rectRadialDistance(vec2 uv) {
    vec2 c = abs(uv - 0.5);
    return max(c.x, c.y) * 2.0;
}

float hue(float s, float t, float h) {
    float hs = mod(h, 1.0) * 6.0;
    if (hs < 1.0) return (t - s) * hs + s;
    if (hs < 3.0) return t;
    if (hs < 4.0) return (t - s) * (4.0 - hs) + s;
    return s;
}

vec4 RGB(vec4 c) {
    if (c.y < 0.0001) return vec4(vec3(c.z), c.a);
    float t = (c.z < 0.5) ? c.y * c.z + c.z : -c.y * c.z + (c.y + c.z);
    float s = 2.0 * c.z - t;
    return vec4(hue(s, t, c.x + 1.0 / 3.0), hue(s, t, c.x), hue(s, t, c.x - 1.0 / 3.0), c.w);
}

vec4 HSL(vec4 c) {
    float low = min(c.r, min(c.g, c.b));
    float high = max(c.r, max(c.g, c.b));
    float delta = high - low;
    float sum = high + low;
    vec4 hsl = vec4(0.0, 0.0, 0.5 * sum, c.a);
    if (delta == 0.0) return hsl;
    hsl.y = (hsl.z < 0.5) ? delta / sum : delta / (2.0 - sum);
    if (high == c.r) hsl.x = (c.g - c.b) / delta;
    else if (high == c.g) hsl.x = (c.b - c.r) / delta + 2.0;
    else hsl.x = (c.r - c.g) / delta + 4.0;
    hsl.x = mod(hsl.x / 6.0, 1.0);
    return hsl;
}

vec4 singedEdition(vec4 tex, vec2 uv, float t) {
    float cardAlpha = tex.a;
    float edgeDist = minEdgeDistance(uv);
    float radial = rectRadialDistance(uv);

    float edgeNoise = fbm(uv * 23.0 + vec2(t * 0.035, -t * 0.018));
    float fineNoise = valueNoise(uv * 140.0 + vec2(t * 0.10, -t * 0.07));
    float emberNoise = valueNoise(uv * 230.0 + vec2(t * 1.7, -t * 1.15));

    float irregularEdge = edgeDist + 0.024 * (edgeNoise - 0.5) + 0.009 * (fineNoise - 0.5);
    float singe = (1.0 - smoothstep(0.018, 0.165, irregularEdge)) * cardAlpha;
    float charLine = (1.0 - smoothstep(0.000, 0.050, irregularEdge)) * cardAlpha;

    float centerWarmth = (1.0 - smoothstep(0.20, 1.25, radial)) * fbm(uv * 8.0 + vec2(t * 0.02, -t * 0.02)) * cardAlpha;

    vec3 sepia = vec3(
        tex.r * 0.393 + tex.g * 0.769 + tex.b * 0.189,
        tex.r * 0.349 + tex.g * 0.686 + tex.b * 0.168,
        tex.r * 0.272 + tex.g * 0.534 + tex.b * 0.131
    );

    tex.rgb = mix(tex.rgb, sepia, 0.18);
    tex.rgb = mix(tex.rgb, vec3(0.47, 0.25, 0.10), singe * 0.58);
    tex.rgb = mix(tex.rgb, vec3(0.055, 0.038, 0.024), charLine * 0.62);
    tex.rgb += centerWarmth * vec3(0.055, 0.018, 0.004);

    float emberField = smoothstep(0.925, 1.0, emberNoise) * singe * (0.35 + 0.65 * sin(t * 8.0 + uv.x * 44.0 + uv.y * 37.0));
    tex.rgb += emberField * vec3(0.95, 0.20, 0.030) * 0.78;

    float smokeWisp = fbm(vec2(uv.x * 16.0 + sin(t * 0.7) * 0.2, uv.y * 24.0 - t * 0.38));
    float smokyEdge = singe * smoothstep(0.52, 0.92, smokeWisp);
    tex.rgb = mix(tex.rgb, vec3(0.10, 0.085, 0.070), smokyEdge * 0.18);

    float erosionNoise = fbm(uv * 52.0 + vec2(t * 0.02, 0.0));
    float erodedEdge = smoothstep(-0.010, 0.022 + 0.014 * erosionNoise, edgeDist);
    tex.a *= mix(1.0, erodedEdge, 0.18);

    return vec4(saturate3(tex.rgb), saturate1(tex.a));
}

vec4 dissolve_mask(vec4 tex, vec2 texture_coords, vec2 uv) {
    if (dissolve < 0.001) {
        return vec4(shadow ? vec3(0.0) : tex.xyz, shadow ? tex.a * 0.3 : tex.a);
    }
    float adjusted_dissolve = (dissolve * dissolve * (3.0 - 2.0 * dissolve)) * 1.02 - 0.01;
    float t = time * 10.0 + 2003.0;
    vec2 sprite_size = max(texture_details.ba, vec2(1.0));
    vec2 floored_uv = floor(uv * sprite_size) / max(sprite_size.x, sprite_size.y);
    vec2 uv_scaled_centered = (floored_uv - 0.5) * 2.3 * max(sprite_size.x, sprite_size.y);
    vec2 field_part1 = uv_scaled_centered + 50.0 * vec2(sin(-t / 143.6340), cos(-t / 99.4324));
    vec2 field_part2 = uv_scaled_centered + 50.0 * vec2(cos(t / 53.1532), cos(t / 61.4532));
    vec2 field_part3 = uv_scaled_centered + 50.0 * vec2(sin(-t / 87.53218), sin(-t / 49.0000));
    float field = (1.0 + (cos(length(field_part1) / 19.483) + sin(length(field_part2) / 33.155) * cos(field_part2.y / 15.73) + cos(length(field_part3) / 27.193) * sin(field_part3.x / 21.92))) / 2.0;
    vec2 borders = vec2(0.2, 0.8);
    float res = (0.5 + 0.5 * cos(adjusted_dissolve / 82.612 + (field - 0.5) * 3.14))
        - (floored_uv.x > borders.y ? (floored_uv.x - borders.y) * (5.0 + 5.0 * dissolve) : 0.0) * dissolve
        - (floored_uv.y > borders.y ? (floored_uv.y - borders.y) * (5.0 + 5.0 * dissolve) : 0.0) * dissolve
        - (floored_uv.x < borders.x ? (borders.x - floored_uv.x) * (5.0 + 5.0 * dissolve) : 0.0) * dissolve
        - (floored_uv.y < borders.x ? (borders.x - floored_uv.y) * (5.0 + 5.0 * dissolve) : 0.0) * dissolve;
    if (tex.a > 0.01 && burn_colour_1.a > 0.01 && !shadow && res < adjusted_dissolve + 0.8 * (0.5 - abs(adjusted_dissolve - 0.5)) && res > adjusted_dissolve) {
        if (res < adjusted_dissolve + 0.5 * (0.5 - abs(adjusted_dissolve - 0.5)) && res > adjusted_dissolve) tex.rgba = burn_colour_1.rgba;
        else if (burn_colour_2.a > 0.01) tex.rgba = burn_colour_2.rgba;
    }
    return vec4(shadow ? vec3(0.0) : tex.xyz, res > adjusted_dissolve ? (shadow ? tex.a * 0.3 : tex.a) : 0.0);
}

vec4 effect(vec4 colour, Image texture, vec2 texture_coords, vec2 screen_coords) {
    vec4 tex = Texel(texture, texture_coords);
    vec2 sprite_size = max(texture_details.ba, vec2(1.0));
    vec2 uv = ((texture_coords * image_details) - texture_details.xy * sprite_size) / sprite_size;
    float anim_time = time;
    if (singed.g > 0.0 || singed.g < 0.0) {
        anim_time = singed.y + singed.x * 0.03125;
    }

    tex = singedEdition(tex, uv, anim_time);

    return dissolve_mask(tex * colour, texture_coords, uv);
}

#ifdef VERTEX
vec4 position(mat4 transform_projection, vec4 vertex_position) {
    if (hovering <= 0.0) return transform_projection * vertex_position;
    float mid_dist = length(vertex_position.xy - 0.5 * love_ScreenSize.xy) / length(love_ScreenSize.xy);
    vec2 mouse_offset = (vertex_position.xy - mouse_screen_pos.xy) / screen_scale;
    float scale = 0.2 * (-0.03 - 0.3 * max(0.0, 0.3 - mid_dist)) * hovering * (length(mouse_offset) * length(mouse_offset)) / (2.0 - mid_dist);
    return transform_projection * vertex_position + vec4(0.0, 0.0, 0.0, scale);
}
#endif
