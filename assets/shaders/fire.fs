#if defined(VERTEX) || __VERSION__ > 100 || defined(GL_FRAGMENT_PRECISION_HIGH)
    #define PRECISION highp
#else
    #define PRECISION mediump
#endif

extern PRECISION vec2 fire;
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

float ridge(float x) { return 1.0 - abs(2.0 * x - 1.0); }

float ridgedFbm(vec2 p) {
    float v = 0.0;
    float a = 0.5;
    v += a * ridge(valueNoise(p)); p *= 2.07; a *= 0.52;
    v += a * ridge(valueNoise(p)); p *= 2.11; a *= 0.50;
    v += a * ridge(valueNoise(p)); p *= 2.03; a *= 0.48;
    v += a * ridge(valueNoise(p)); p *= 2.17; a *= 0.46;
    v += a * ridge(valueNoise(p));
    return v;
}

float roundedRectSDF(vec2 uv, float radius) {
    vec2 q = abs(uv - 0.5) - vec2(0.5 - radius);
    return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - radius;
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

vec3 flameColor(float outer, float core) {
    vec3 ember = vec3(0.55, 0.055, 0.010);
    vec3 orange = vec3(1.00, 0.34, 0.045);
    vec3 gold = vec3(1.00, 0.78, 0.18);
    vec3 whiteHot = vec3(1.00, 0.96, 0.72);
    vec3 col = mix(ember, orange, saturate1(outer * 1.25));
    col = mix(col, gold, saturate1(core * 0.95));
    col = mix(col, whiteHot, saturate1(core * core * 0.65));
    return col;
}

vec2 centerOutFlameLayer(vec2 uv, float t, float seed, float intensity, float heightScale) {
    float sdf = roundedRectSDF(uv, 0.065);
    vec2 fromCenter = uv - 0.5;
    float radial = rectRadialDistance(uv);
    float ang = atan(fromCenter.y, fromCenter.x);
    float cardAndHalo = 1.0 - smoothstep(0.000, 0.155, sdf);
    float reach = mix(1.04, 1.42, saturate1(heightScale));
    float centerStart = 0.038;
    float radialBody = smoothstep(centerStart, centerStart + 0.10, radial) * (1.0 - smoothstep(reach - 0.02, reach + 0.20, radial));
    float centerBed = 1.0 - smoothstep(0.00, 0.34, radial);
    float slowWarpA = fbm(vec2(ang * 2.0 + seed * 11.0, radial * 4.0 - t * 0.85));
    float slowWarpB = fbm(vec2(ang * 3.5 - seed * 7.0, radial * 5.5 + t * 0.65));
    vec2 warp = vec2(slowWarpA, slowWarpB) - 0.5;
    float wispZone = smoothstep(0.72, 1.18, radial);
    vec2 p = vec2(
        ang * mix(3.0, 9.5, wispZone) + warp.x * 2.4 + seed,
        radial * mix(6.8, 23.0, wispZone) - t * mix(2.2, 5.8, wispZone) + warp.y * 4.2
    );
    float tongues = ridgedFbm(p);
    float broadFire = smoothstep(0.16, 0.68, tongues);
    float thinWisps = smoothstep(0.56, 0.96, tongues);
    float flameShape = mix(broadFire, thinWisps, wispZone);
    flameShape = pow(flameShape, mix(0.86, 4.80, wispZone));
    float edgeBreakupNoise = fbm(vec2(ang * 13.0 + seed * 19.0, radial * 38.0 - t * 6.5));
    float edgeBreakup = mix(1.0, smoothstep(0.23, 0.95, edgeBreakupNoise), wispZone);
    float pulseNoise = fbm(vec2(ang * 5.0 + seed * 3.0, radial * 11.0 - t * 3.4));
    float outwardPulse = 0.74 + 0.26 * sin(t * 8.0 - radial * 15.0 + pulseNoise * 5.0 + seed);
    float outer = flameShape * radialBody * edgeBreakup * outwardPulse;
    float infernoNoise = fbm(vec2(uv.x * 13.0 + t * 0.70 + seed * 2.0, uv.y * 13.0 - t * 0.55));
    float infernoBloom = smoothstep(0.04, 0.24, radial) * (1.0 - smoothstep(0.88, 1.18, radial)) * smoothstep(0.18, 0.82, infernoNoise) * (0.72 + 0.28 * sin(t * 10.5 - radial * 9.0 + seed));
    outer = max(outer, infernoBloom * 0.82);
    float core = outer * (1.0 - smoothstep(0.58, 1.15, radial)) * smoothstep(0.24, 0.90, pulseNoise);
    float centerNoise = fbm(vec2(uv.x * 18.0 + t * 0.55 + seed, uv.y * 18.0 - t * 0.45));
    float centerIgnition = centerBed * smoothstep(0.16, 0.80, centerNoise) * (0.78 + 0.22 * sin(t * 15.0 + seed * 4.0));
    outer = max(outer, centerIgnition * 0.92);
    core = max(core, centerIgnition * 0.76);
    outer *= cardAndHalo * intensity;
    core *= cardAndHalo * intensity;
    return vec2(outer, core);
}

vec2 outwardEdgeFlameLayer(vec2 uv, float t, float intensity, float heightScale) {
    float sdf = roundedRectSDF(uv, 0.065);
    float dBottom = uv.y;
    float dTop = 1.0 - uv.y;
    float dLeft = uv.x;
    float dRight = 1.0 - uv.x;
    float edgeDist = min(min(dBottom, dTop), min(dLeft, dRight));
    float isBottom = step(dBottom, dTop) * step(dBottom, dLeft) * step(dBottom, dRight);
    float isTop = step(dTop, dBottom) * step(dTop, dLeft) * step(dTop, dRight);
    float isLeft = step(dLeft, dBottom) * step(dLeft, dTop) * step(dLeft, dRight);
    float isRight = step(dRight, dBottom) * step(dRight, dTop) * step(dRight, dLeft);
    float along = uv.x * (isBottom + isTop) + uv.y * (isLeft + isRight);
    float outward = (sdf > 0.0) ? sdf : edgeDist;
    float edgeBand = (1.0 - smoothstep(0.000, 0.105, abs(sdf))) * (1.0 - smoothstep(0.000, 0.115, abs(edgeDist)));
    float baseNoise = fbm(vec2(along * 5.0, t * 0.75));
    float fineNoise = fbm(vec2(along * 19.0 + 4.7, -t * 1.85));
    float flameHeight = mix(0.045, 0.155, baseNoise) * mix(0.72, 1.45, fineNoise) * intensity * heightScale;
    float y = outward / max(flameHeight, 0.0001);
    float verticalMask = 1.0 - smoothstep(0.0, 1.0, y);
    float taper = pow(1.0 - saturate1(y), 2.15);
    vec2 warp;
    warp.x = fbm(vec2(along * 9.0, t * 1.25 + outward * 16.0));
    warp.y = fbm(vec2(along * 13.0 + 8.0, -t * 1.55 + outward * 9.0));
    warp = (warp - 0.5) * 0.18;
    vec2 p = vec2(along * 38.0 + warp.x * 7.0, outward * 24.0 - t * 5.7 + warp.y * 6.0);
    float tongues = ridgedFbm(p);
    tongues = smoothstep(0.62, 0.97, tongues);
    tongues = pow(tongues, mix(2.0, 6.0, saturate1(y)));
    float tipNoise = fbm(vec2(along * 44.0 + 12.0, outward * 52.0 - t * 6.8));
    float tipBreakup = smoothstep(0.24, 0.92, tipNoise + taper * 0.22);
    float outer = edgeBand * verticalMask * tongues * tipBreakup;
    float core = outer;
    core *= 1.0 - smoothstep(0.04, 0.52, y);
    core *= smoothstep(0.48, 1.0, fineNoise);
    float flicker = 0.78 + 0.22 * sin(t * 18.5 + along * 63.0) * (0.65 + 0.35 * fineNoise);
    outer *= flicker;
    core *= flicker;
    return vec2(outer, core);
}

vec4 burningEdition(vec4 tex, vec2 uv, float t, float intensity, float heightScale) {
    float cardAlpha = tex.a;
    float edgeDist = minEdgeDistance(uv);
    float radial = rectRadialDistance(uv);
    float spreadNoise = fbm(uv * 9.0 + vec2(t * 0.035, -t * 0.025));
    float fineNoise = valueNoise(uv * 115.0 + vec2(t * 0.25, t * 0.10));
    float noisyRadial = radial + 0.075 * (spreadNoise - 0.5) + 0.025 * (fineNoise - 0.5);
    float innerScorch = smoothstep(0.05, 0.46, noisyRadial) * (1.0 - smoothstep(1.18, 1.34, noisyRadial)) * cardAlpha * intensity;
    float edgeNoise = fbm(uv * 18.0 + vec2(t * 0.04, -t * 0.03));
    float irregularEdge = edgeDist + 0.016 * (edgeNoise - 0.5) + 0.006 * (fineNoise - 0.5);
    float edgeScorch = (1.0 - smoothstep(0.018, 0.135, irregularEdge)) * cardAlpha * intensity;
    float deepChar = ((1.0 - smoothstep(0.000, 0.044, irregularEdge)) * 0.68 + innerScorch * smoothstep(0.72, 1.10, noisyRadial) * 0.24) * cardAlpha * intensity;
    float erosionNoise = fbm(uv * 46.0 + vec2(t * 0.03, 0.0));
    float erodedEdge = smoothstep(-0.010, 0.030 + 0.018 * erosionNoise, edgeDist);
    tex.a *= mix(1.0, erodedEdge, 0.24 * intensity);
    vec3 warmBrown = vec3(0.42, 0.18, 0.055);
    vec3 brown = vec3(0.29, 0.145, 0.055);
    vec3 blackChar = vec3(0.035, 0.025, 0.018);
    tex.rgb = mix(tex.rgb, warmBrown, innerScorch * 0.38);
    tex.rgb = mix(tex.rgb, brown, edgeScorch * 0.48);
    tex.rgb = mix(tex.rgb, blackChar, deepChar * 0.48);
    float emberNoise = valueNoise(uv * 190.0 + vec2(t * 2.0, -t * 1.3));
    float embers = smoothstep(0.88, 1.0, emberNoise) * max(innerScorch * 0.62, edgeScorch * 0.72) * (0.55 + 0.45 * sin(t * 11.0 + uv.x * 50.0 + uv.y * 33.0));
    tex.rgb += embers * vec3(1.0, 0.29, 0.035) * 0.72;
    vec2 centerFlame = centerOutFlameLayer(uv, t, 1.0, intensity, heightScale);
    float outerFlame = centerFlame.x * 1.14;
    float coreFlame = centerFlame.y * 1.18;
    vec2 edgeFlame = outwardEdgeFlameLayer(uv, t, intensity, heightScale);
    outerFlame = max(outerFlame, edgeFlame.x * 0.88);
    coreFlame = max(coreFlame, edgeFlame.y * 0.58);
    float cornerDistance = min(min(length(uv - vec2(0.0, 0.0)), length(uv - vec2(1.0, 0.0))), min(length(uv - vec2(0.0, 1.0)), length(uv - vec2(1.0, 1.0))));
    float cornerBoost = 1.0 + 0.18 * (1.0 - smoothstep(0.02, 0.24, cornerDistance));
    outerFlame *= cornerBoost;
    coreFlame *= cornerBoost;
    vec3 fcol = flameColor(outerFlame, coreFlame);
    tex.rgb += fcol * pow(outerFlame, 1.18) * 0.76;
    tex.rgb += vec3(1.0, 0.78, 0.34) * pow(coreFlame, 1.10) * 0.52;
    tex.a = max(tex.a, outerFlame * 0.38 * intensity * cardAlpha);
    tex.a = max(tex.a, coreFlame * 0.64 * intensity * cardAlpha);
    float heat = outerFlame * (0.5 + 0.5 * sin(t * 22.0 + uv.x * 45.0 - uv.y * 37.0));
    tex.rgb += heat * vec3(0.15, 0.036, 0.006);
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
    if (fire.g > 0.0 || fire.g < 0.0) {
        anim_time = fire.y + fire.x * 0.03125;
    }

    float intensity = 0.90;
    float heightScale = 0.72;
    tex = burningEdition(tex, uv, anim_time, intensity, heightScale);

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
