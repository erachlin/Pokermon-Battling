#if defined(VERTEX) || __VERSION__ > 100 || defined(GL_FRAGMENT_PRECISION_HIGH)
    #define PRECISION highp
#else
    #define PRECISION mediump
#endif

extern PRECISION vec2 lightning;
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

// ----------------------------------------------------
// Utility
// ----------------------------------------------------

float saturate1(float x) {
    return clamp(x, 0.0, 1.0);
}

vec3 saturate3(vec3 x) {
    return clamp(x, vec3(0.0), vec3(1.0));
}

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

    return mix(
        mix(a, b, u.x),
        mix(c, d, u.x),
        u.y
    );
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

float ridge(float x) {
    return 1.0 - abs(2.0 * x - 1.0);
}

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

float roundedRectAlpha(vec2 uv, float radius) {
    float d = roundedRectSDF(uv, radius);
    return 1.0 - smoothstep(0.0, 0.012, d);
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

// ----------------------------------------------------
// Lightning color
// ----------------------------------------------------

vec3 lightningColor(float glow, float core, float hotCore) {
    vec3 deepBlue = vec3(0.04, 0.10, 0.42);
    vec3 electricBlue = vec3(0.05, 0.55, 1.00);
    vec3 cyan = vec3(0.34, 0.92, 1.00);
    vec3 whiteHot = vec3(0.92, 0.98, 1.00);

    vec3 col = mix(deepBlue, electricBlue, saturate1(glow * 1.25));
    col = mix(col, cyan, saturate1(core * 0.95));
    col = mix(col, whiteHot, saturate1(hotCore));

    return col;
}


// ----------------------------------------------------
// Lightning bolt field
// ----------------------------------------------------

vec3 lightningBoltRay(
    vec2 uv,
    float angle,
    float time,
    float seed,
    float intensity,
    float reachScale
) {
    vec2 center = vec2(0.5);
    vec2 p = uv - center;

    vec2 dir = vec2(cos(angle), sin(angle));
    vec2 sideDir = vec2(-dir.y, dir.x);

    float along = dot(p, dir);
    float side = dot(p, sideDir);

    float maxReach = mix(0.35, 0.96, saturate1(reachScale));

    float along01 = along / max(maxReach, 0.0001);

    float activa =
        smoothstep(0.010, 0.055, along) *
        (1.0 - smoothstep(maxReach * 0.82, maxReach * 1.06, along));

    // Jagged electrical path.
    // Several layered waves/noise offsets make the ray look like it is snapping.
    float coarseJitter = fbm(vec2(
        along * 7.0 + seed * 9.0,
        time * 1.20 + seed
    ));

    float fineJitter = fbm(vec2(
        along * 22.0 + seed * 21.0,
        -time * 2.80 + seed * 0.37
    ));

    float snap = sin(along * 96.0 + time * 18.0 + seed * 4.0);
    float snap2 = sin(along * 151.0 - time * 23.0 + seed * 7.0);

    float jitter =
        (coarseJitter - 0.5) * 0.070 +
        (fineJitter - 0.5) * 0.030 +
        snap * 0.006 +
        snap2 * 0.003;

    // More chaotic toward the tip.
    jitter *= mix(0.45, 1.18, saturate1(along01));

    float d = abs(side - jitter);

    // Moving pulse traveling outward from the center.
    float pulse =
        0.58 +
        0.42 * sin(time * 8.0 - along * 26.0 + seed * 5.0);

    pulse *= 0.75 + 0.25 * fineJitter;

    // Width tapers as it reaches the edge.
    float width = mix(0.010, 0.004, saturate1(along01));
    width *= mix(1.25, 0.72, saturate1(along01));

    float hotCore = smoothstep(width * 0.45, 0.0, d);
    float core = smoothstep(width * 1.10, 0.0, d);
    float glow = smoothstep(width * 8.5, 0.0, d);

    // Broken flickering makes it less like a simple clean line.
    float breakNoise = fbm(vec2(
        along * 18.0 + seed * 13.0,
        time * 3.5 + seed
    ));

    float breaker =
        smoothstep(0.18, 0.86, breakNoise + 0.35 * pulse);

    hotCore *= activa * breaker;
    core *= activa * breaker;
    glow *= activa * mix(0.70, 1.0, breaker);

    // Branches that split off from the main bolt.
    float branchStartA = mix(0.20, 0.54, hash12(vec2(seed, 1.37)));
    float branchStartB = mix(0.28, 0.68, hash12(vec2(seed, 4.91)));

    float branchAActive =
        smoothstep(branchStartA, branchStartA + 0.06, along01) *
        (1.0 - smoothstep(branchStartA + 0.28, branchStartA + 0.50, along01));

    float branchBActive =
        smoothstep(branchStartB, branchStartB + 0.05, along01) *
        (1.0 - smoothstep(branchStartB + 0.18, branchStartB + 0.38, along01));

    float branchSideA =
        side -
        jitter -
        (along01 - branchStartA) * mix(0.18, -0.18, hash12(vec2(seed, 8.1)));

    float branchSideB =
        side -
        jitter -
        (along01 - branchStartB) * mix(-0.14, 0.14, hash12(vec2(seed, 2.4)));

    float branchJitterA =
        (fbm(vec2(along * 31.0 + seed * 2.0, time * 4.1)) - 0.5) * 0.026;

    float branchJitterB =
        (fbm(vec2(along * 27.0 + seed * 5.0, -time * 3.7)) - 0.5) * 0.022;

    float branchDistA = abs(branchSideA - branchJitterA);
    float branchDistB = abs(branchSideB - branchJitterB);

    float branchWidth = width * 0.70;

    float branchCoreA = smoothstep(branchWidth, 0.0, branchDistA) * branchAActive;
    float branchGlowA = smoothstep(branchWidth * 5.5, 0.0, branchDistA) * branchAActive;

    float branchCoreB = smoothstep(branchWidth * 0.85, 0.0, branchDistB) * branchBActive;
    float branchGlowB = smoothstep(branchWidth * 4.5, 0.0, branchDistB) * branchBActive;

    branchCoreA *= breaker;
    branchGlowA *= breaker;
    branchCoreB *= breaker;
    branchGlowB *= breaker;

    core = max(core, max(branchCoreA, branchCoreB) * 0.70);
    glow = max(glow, max(branchGlowA, branchGlowB) * 0.55);
    hotCore = max(hotCore, max(branchCoreA, branchCoreB) * 0.34);

    vec3 result = vec3(glow, core, hotCore);
    result *= intensity;

    return result;
}


// ----------------------------------------------------
// Circular electric node / central source
// ----------------------------------------------------

vec3 centralElectricNode(
    vec2 uv,
    float time,
    float intensity
) {
    vec2 p = uv - 0.5;
    float r = length(p);
    float ang = atan(p.y, p.x);

    float ringNoise = fbm(vec2(
        ang * 4.0,
        time * 2.2 + r * 12.0
    ));

    float pulse =
        0.78 +
        0.22 * sin(time * 9.0 + ringNoise * 5.5);

    float core = 1.0 - smoothstep(0.000, 0.042, r);
    float halo = 1.0 - smoothstep(0.025, 0.190, r);

    float ring =
        smoothstep(0.090, 0.105, r + (ringNoise - 0.5) * 0.018) *
        (1.0 - smoothstep(0.122, 0.158, r + (ringNoise - 0.5) * 0.018));

    core *= pulse;
    halo *= pulse * 0.68;
    ring *= pulse;

    return vec3(halo, max(core, ring * 0.65), core) * intensity;
}


// ----------------------------------------------------
// Edge crawling electricity
// ----------------------------------------------------

vec3 edgeElectricity(
    vec2 uv,
    float time,
    float intensity,
    float reachScale
) {
    float sdf = roundedRectSDF(uv, 0.065);
    float edgeDist = minEdgeDistance(uv);

    float edgeBand =
        (1.0 - smoothstep(0.000, 0.095, abs(sdf))) *
        (1.0 - smoothstep(0.000, 0.085, edgeDist));

    // Coordinate around the border.
    float bottom = step(edgeDist, uv.y + 0.0001) * step(edgeDist, 1.0 - uv.y + 0.0001);
    float along = 0.0;

    // Simple approximate perimeter coordinate.
    if (uv.y < edgeDist + 0.002) {
        along = uv.x;
    } else if (1.0 - uv.x < edgeDist + 0.002) {
        along = 1.0 + uv.y;
    } else if (1.0 - uv.y < edgeDist + 0.002) {
        along = 2.0 + (1.0 - uv.x);
    } else {
        along = 3.0 + (1.0 - uv.y);
    }

    float crawlNoise = ridgedFbm(vec2(
        along * 9.0,
        time * 2.0
    ));

    float fine = ridgedFbm(vec2(
        along * 31.0 + time * 3.5,
        edgeDist * 42.0 - time * 4.0
    ));

    float pulse =
        0.55 +
        0.45 * sin(time * 6.5 - along * 5.2 + crawlNoise * 4.0);

    float sparkMask =
        smoothstep(0.58, 0.97, fine) *
        smoothstep(0.15, 1.0, pulse);

    float edgeStrength = edgeBand * sparkMask * intensity;

    // Mouse vertical/reach can make edge crawling more prominent.
    edgeStrength *= mix(0.55, 1.25, saturate1(reachScale));

    float glow = edgeStrength * 0.70;
    float core = edgeStrength * 0.46;
    float hotCore = edgeStrength * 0.20;

    return vec3(glow, core, hotCore);
}


// ----------------------------------------------------
// The actual edition effect
// ----------------------------------------------------

vec4 lightningEdition(
    vec4 tex,
    vec2 uv,
    float time,
    float intensity,
    float reachScale
) {
    float cardAlpha = roundedRectAlpha(uv, 0.065);
    float sdf = roundedRectSDF(uv, 0.065);
    float edgeDist = minEdgeDistance(uv);
    float radial = rectRadialDistance(uv);

    tex.a *= cardAlpha;

    // ------------------------------------------------
    // Darken / charge the card material
    // ------------------------------------------------

    float fieldNoise = fbm(uv * 8.0 + vec2(time * 0.06, -time * 0.04));
    float fineStatic = valueNoise(uv * 180.0 + vec2(time * 2.2, -time * 1.7));

    float chargedField =
        smoothstep(0.10, 0.95, radial + 0.06 * (fieldNoise - 0.5)) *
        cardAlpha *
        intensity;

    vec3 coolShadow = vec3(0.025, 0.038, 0.085);
    vec3 blueViolet = vec3(0.075, 0.060, 0.200);

    tex.rgb = mix(tex.rgb, coolShadow, chargedField * 0.42);
    tex.rgb = mix(tex.rgb, blueViolet, fieldNoise * 0.18 * intensity * cardAlpha);

    // Subtle electrical grain/static.
    float staticSpecks =
        smoothstep(0.965, 1.0, fineStatic) *
        cardAlpha *
        intensity *
        (0.50 + 0.50 * sin(time * 19.0 + uv.x * 90.0));

    tex.rgb += staticSpecks * vec3(0.20, 0.70, 1.0) * 0.35;

    // ------------------------------------------------
    // Main lightning field
    // ------------------------------------------------

    vec3 lightning = vec3(0.0);

    // Primary rays from center.
    lightning = max(lightning, lightningBoltRay(uv,  0.08, time, 1.0, intensity, reachScale));
    lightning = max(lightning, lightningBoltRay(uv,  0.96, time, 2.0, intensity, reachScale));
    lightning = max(lightning, lightningBoltRay(uv,  1.86, time, 3.0, intensity, reachScale));
    lightning = max(lightning, lightningBoltRay(uv,  2.77, time, 4.0, intensity, reachScale));
    lightning = max(lightning, lightningBoltRay(uv,  3.62, time, 5.0, intensity, reachScale));
    lightning = max(lightning, lightningBoltRay(uv,  4.58, time, 6.0, intensity, reachScale));
    lightning = max(lightning, lightningBoltRay(uv,  5.36, time, 7.0, intensity, reachScale));

    // A few secondary weaker rays to make the energy feel like it is coursing through the whole card.
    lightning = max(lightning, lightningBoltRay(uv,  0.52 + 0.05 * sin(time * 0.7), time, 8.0, intensity * 0.55, reachScale));
    lightning = max(lightning, lightningBoltRay(uv,  2.34 + 0.04 * sin(time * 0.9), time, 9.0, intensity * 0.50, reachScale));
    lightning = max(lightning, lightningBoltRay(uv,  4.08 + 0.05 * sin(time * 0.8), time, 10.0, intensity * 0.52, reachScale));

    // Center source.
    lightning = max(lightning, centralElectricNode(uv, time, intensity));

    // Edge crawling arcs.
    lightning = max(lightning, edgeElectricity(uv, time, intensity, reachScale));

    float glow = lightning.x;
    float core = lightning.y;
    float hotCore = lightning.z;

    // Keep lightning attached to the rounded card plus a small halo outside.
    float cardAndHalo = 1.0 - smoothstep(0.000, 0.165, sdf);

    glow *= cardAndHalo;
    core *= cardAndHalo;
    hotCore *= cardAndHalo;

    // ------------------------------------------------
    // Electrical burn / etched channels
    // ------------------------------------------------

    float etched = core * 0.42 + hotCore * 0.35;

    vec3 etchedBlue = vec3(0.015, 0.028, 0.070);
    tex.rgb = mix(tex.rgb, etchedBlue, saturate1(etched) * 0.48);

    // Slight bright pre-glow around conductive channels.
    vec3 eCol = lightningColor(glow, core, hotCore);

    tex.rgb += eCol * pow(glow, 1.25) * 0.58;
    tex.rgb += vec3(0.30, 0.90, 1.00) * pow(core, 1.08) * 0.78;
    tex.rgb += vec3(0.95, 0.98, 1.00) * pow(hotCore, 0.92) * 1.20;

    // Extra electric bloom near the card edge.
    float edgeGlow =
        (1.0 - smoothstep(0.000, 0.075, edgeDist)) *
        cardAlpha *
        intensity;

    tex.rgb += edgeGlow * vec3(0.025, 0.20, 0.45) * 0.45;

    // Alpha contribution for the bolts and glow.
    tex.a = max(tex.a, glow * 0.34 * intensity);
    tex.a = max(tex.a, core * 0.72 * intensity);
    tex.a = max(tex.a, hotCore * 0.92 * intensity);

    // A tiny final flicker to make the whole material feel energized.
    float globalFlicker =
        0.94 +
        0.06 * sin(time * 31.0 + fieldNoise * 8.0);

    tex.rgb *= globalFlicker;

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

    // Sprite-local UV in 0..1, derived from Balatro's atlas coordinates.
    vec2 uv = (((texture_coords) * image_details) - texture_details.xy * texture_details.ba) / texture_details.ba;
    float anim_time = time;
    if (lightning.g > 0.0 || lightning.g < 0.0) {
        anim_time = lightning.y + lightning.x * 0.03125;
    }

    // Safe defaults for the current Balatro/SMODS pipeline.
    float intensity = 1.0;
    float reachScale = 0.90;

    tex = lightningEdition(tex, uv, anim_time, intensity, reachScale);

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
