#if defined(VERTEX) || __VERSION__ > 100 || defined(GL_FRAGMENT_PRECISION_HIGH)
    #define PRECISION highp
#else
    #define PRECISION mediump
#endif

extern PRECISION vec2 water;
extern PRECISION number dissolve;
extern PRECISION number time;
// (sprite_pos_x, sprite_pos_y, sprite_width, sprite_height) [not normalized]
extern PRECISION vec4 texture_details;
// (width, height) for atlas texture [not normalized]
extern PRECISION vec2 image_details;
extern bool shadow;
extern PRECISION vec4 burn_colour_1;
extern PRECISION vec4 burn_colour_2;

// for transforming the card while your mouse is on it
extern PRECISION vec2 mouse_screen_pos;
extern PRECISION float hovering;
extern PRECISION float screen_scale;

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

vec2 local_uv_from_texture_coords(vec2 texture_coords) {
    return (((texture_coords) * (image_details)) - texture_details.xy * texture_details.ba) / texture_details.ba;
}

vec2 texture_coords_from_local_uv(vec2 uv) {
    vec2 sprite_pixels = texture_details.xy * texture_details.ba + uv * texture_details.ba;
    return sprite_pixels / image_details;
}

vec4 dissolve_mask(vec4 tex, vec2 texture_coords, vec2 uv) {
    if (dissolve < 0.001) {
        return vec4(shadow ? vec3(0.0) : tex.xyz, shadow ? tex.a * 0.3 : tex.a);
    }

    float adjusted_dissolve = (dissolve * dissolve * (3.0 - 2.0 * dissolve)) * 1.02 - 0.01;
    float t = time * 10.0 + 2003.0;

    vec2 floored_uv = (floor((uv * texture_details.ba))) / max(texture_details.b, texture_details.a);
    vec2 uv_scaled_centered = (floored_uv - 0.5) * 2.3 * max(texture_details.b, texture_details.a);

    vec2 field_part1 = uv_scaled_centered + 50.0 * vec2(sin(-t / 143.6340), cos(-t / 99.4324));
    vec2 field_part2 = uv_scaled_centered + 50.0 * vec2(cos(t / 53.1532), cos(t / 61.4532));
    vec2 field_part3 = uv_scaled_centered + 50.0 * vec2(sin(-t / 87.53218), sin(-t / 49.0000));

    float field = (1.0 + (
        cos(length(field_part1) / 19.483) +
        sin(length(field_part2) / 33.155) * cos(field_part2.y / 15.73) +
        cos(length(field_part3) / 27.193) * sin(field_part3.x / 21.92)
    )) / 2.0;

    vec2 borders = vec2(0.2, 0.8);

    float res = (0.5 + 0.5 * cos((adjusted_dissolve) / 82.612 + (field - 0.5) * 3.14))
        - (floored_uv.x > borders.y ? (floored_uv.x - borders.y) * (5.0 + 5.0 * dissolve) : 0.0) * dissolve
        - (floored_uv.y > borders.y ? (floored_uv.y - borders.y) * (5.0 + 5.0 * dissolve) : 0.0) * dissolve
        - (floored_uv.x < borders.x ? (borders.x - floored_uv.x) * (5.0 + 5.0 * dissolve) : 0.0) * dissolve
        - (floored_uv.y < borders.x ? (borders.x - floored_uv.y) * (5.0 + 5.0 * dissolve) : 0.0) * dissolve;

    if (tex.a > 0.01 && burn_colour_1.a > 0.01 && !shadow &&
        res < adjusted_dissolve + 0.8 * (0.5 - abs(adjusted_dissolve - 0.5)) &&
        res > adjusted_dissolve) {
        if (res < adjusted_dissolve + 0.5 * (0.5 - abs(adjusted_dissolve - 0.5)) &&
            res > adjusted_dissolve) {
            tex.rgba = burn_colour_1.rgba;
        } else if (burn_colour_2.a > 0.01) {
            tex.rgba = burn_colour_2.rgba;
        }
    }

    return vec4(shadow ? vec3(0.0) : tex.xyz, res > adjusted_dissolve ? (shadow ? tex.a * 0.3 : tex.a) : 0.0);
}


vec2 underwaterDisplacement(vec2 uv, float time, float intensity, float flowScale) {
    float t = time;
    vec2 p = uv - 0.5;

    float waveA = sin((uv.y * 21.0) + t * 2.10 + sin(uv.x * 7.0 + t * 0.40));
    float waveB = sin((uv.x * 27.0) - t * 1.70 + sin(uv.y * 9.0 - t * 0.55));
    float waveC = sin((uv.x + uv.y) * 34.0 + t * 1.20);

    float n1 = fbm(uv * vec2(8.0, 13.0) + vec2(t * 0.10, -t * 0.16));
    float n2 = fbm(uv * vec2(19.0, 11.0) + vec2(-t * 0.23, t * 0.12));

    vec2 displacement;
    displacement.x = waveA * 0.0048 + waveC * 0.0022 + (n1 - 0.5) * 0.010;
    displacement.y = waveB * 0.0042 - waveC * 0.0020 + (n2 - 0.5) * 0.008;

    float edgeInfluence = 1.0 - smoothstep(0.000, 0.230, minEdgeDistance(uv));
    float centerRipple = 1.0 - smoothstep(0.0, 0.85, length(p));

    displacement *= mix(0.65, 1.25, edgeInfluence);
    displacement += p * centerRipple * sin(t * 1.4 + length(p) * 20.0) * 0.0025;

    displacement *= intensity;
    displacement *= mix(0.55, 1.45, saturate1(flowScale));

    return displacement;
}

float causticField(vec2 uv, float time, float intensity, float flowScale) {
    float t = time;
    vec2 p = uv;
    p += underwaterDisplacement(uv, time, intensity, flowScale) * 5.0;

    vec2 warpA = vec2(
        fbm(p * 5.0 + vec2(t * 0.18, -t * 0.10)),
        fbm(p * 5.0 + vec2(-t * 0.13, t * 0.16))
    );

    vec2 warpB = vec2(
        fbm(p * 13.0 + vec2(-t * 0.35, t * 0.25)),
        fbm(p * 13.0 + vec2(t * 0.28, -t * 0.31))
    );

    vec2 q = p + (warpA - 0.5) * 0.18 + (warpB - 0.5) * 0.045;

    float c1 = ridgedFbm(q * vec2(10.0, 15.0) + vec2(t * 0.35, -t * 0.22));
    float c2 = ridgedFbm(q * vec2(22.0, 17.0) + vec2(-t * 0.28, t * 0.31));

    float caustics = smoothstep(0.58, 0.92, c1) * 0.58 + smoothstep(0.70, 0.98, c2) * 0.42;
    caustics = pow(caustics, 1.65);

    float pulse = 0.78 + 0.22 * sin(t * 2.1 + fbm(q * 3.0) * 6.0);
    caustics *= pulse;
    caustics *= mix(0.65, 1.35, saturate1(flowScale));

    return caustics * intensity;
}

float bubbleLayer(vec2 uv, float time, float seed, float scale, float intensity) {
    float t = time;
    vec2 p = uv * vec2(5.0 * scale, 8.5 * scale);
    p.y += t * mix(0.32, 0.62, hash12(vec2(seed, 2.7)));

    vec2 id = floor(p);
    vec2 gv = fract(p) - 0.5;

    float rnd = hash12(id + vec2(seed * 17.0, seed * 31.0));

    vec2 offset = vec2(
        hash12(id + vec2(seed + 1.2, 8.1)),
        hash12(id + vec2(seed + 4.7, 3.3))
    ) - 0.5;

    offset *= 0.58;
    gv -= offset;

    float radius = mix(0.035, 0.100, rnd);
    float d = length(gv);

    float outer = 1.0 - smoothstep(radius * 0.90, radius * 1.23, d);
    float inner = 1.0 - smoothstep(radius * 0.48, radius * 0.80, d);
    float ring = max(0.0, outer - inner);

    float tinyHighlight = 1.0 - smoothstep(
        radius * 0.18,
        radius * 0.42,
        length(gv - vec2(-radius * 0.35, radius * 0.28))
    );

    float appear = step(0.62, rnd);
    float verticalFade = smoothstep(-0.08, 0.12, uv.y) * (1.0 - smoothstep(0.94, 1.12, uv.y));
    float shimmer = 0.65 + 0.35 * sin(t * 9.0 + rnd * 17.0 + uv.x * 31.0);

    float bubble = ring + tinyHighlight * 0.35;
    bubble *= appear * verticalFade * shimmer * intensity;

    return bubble;
}

float lightShafts(vec2 uv, float time, float intensity) {
    float t = time;
    float n = fbm(uv * 4.0 + vec2(t * 0.04, -t * 0.03));

    float angled = uv.x * 0.75 + uv.y * 0.28 + n * 0.12;
    float bands = 0.5 + 0.5 * sin(angled * 28.0 + t * 0.58);
    bands = pow(bands, 6.0);

    float topFade = smoothstep(0.18, 1.0, uv.y);
    float leftFade = 1.0 - smoothstep(0.25, 1.08, uv.x);

    float shafts = bands * topFade * mix(0.55, 1.0, leftFade);
    shafts *= intensity;

    return shafts;
}

float edgeWaterShimmer(vec2 uv, float time, float intensity, float flowScale) {
    float edgeDist = minEdgeDistance(uv);
    float sdf = roundedRectSDF(uv, 0.065);

    float edgeBand = (1.0 - smoothstep(0.000, 0.120, edgeDist)) * (1.0 - smoothstep(0.000, 0.095, abs(sdf)));

    float n = ridgedFbm(vec2(
        uv.x * 18.0 + uv.y * 7.0 + time * 0.95,
        uv.y * 21.0 - time * 1.35
    ));

    float shimmer = smoothstep(0.50, 0.95, n) * (0.72 + 0.28 * sin(time * 12.0 + uv.x * 41.0 - uv.y * 36.0));
    shimmer *= mix(0.65, 1.35, saturate1(flowScale));
    shimmer *= edgeBand * intensity;

    return shimmer;
}

vec4 underwaterEdition(vec4 tex, vec2 uv, float time, float intensity, float flowScale) {
    float cardAlpha = roundedRectAlpha(uv, 0.065);
    float sdf = roundedRectSDF(uv, 0.065);
    float edgeDist = minEdgeDistance(uv);
    float radial = rectRadialDistance(uv);

    tex.a *= cardAlpha;

    float slowWaterNoise = fbm(uv * vec2(4.0, 6.0) + vec2(time * 0.045, -time * 0.065));
    float depthVignette = smoothstep(0.10, 1.10, radial + slowWaterNoise * 0.10);
    float edgeDepth = 1.0 - smoothstep(0.000, 0.230, edgeDist);

    vec3 shallowBlue = vec3(0.25, 0.68, 0.78);
    vec3 deepTeal = vec3(0.015, 0.115, 0.165);
    vec3 kelpShadow = vec3(0.015, 0.075, 0.070);

    tex.rgb = mix(tex.rgb, tex.rgb * vec3(0.58, 0.86, 1.08), 0.42 * intensity);
    tex.rgb = mix(tex.rgb, shallowBlue, 0.18 * intensity * cardAlpha);
    tex.rgb = mix(tex.rgb, deepTeal, depthVignette * 0.34 * intensity * cardAlpha);
    tex.rgb = mix(tex.rgb, kelpShadow, edgeDepth * 0.22 * intensity * cardAlpha);

    float caustics = causticField(uv, time, intensity, flowScale) * cardAlpha;
    float causticDepthMask = 1.0 - smoothstep(0.88, 1.25, radial);
    caustics *= mix(0.55, 1.0, causticDepthMask);

    vec3 causticColor = vec3(0.70, 1.00, 0.92);
    tex.rgb += causticColor * pow(caustics, 1.25) * 0.34;
    tex.rgb += vec3(0.35, 0.95, 1.00) * pow(caustics, 2.15) * 0.20;

    float shafts = lightShafts(uv, time, intensity) * cardAlpha;
    tex.rgb += shafts * vec3(0.16, 0.48, 0.56) * 0.22;

    float particulateNoise = valueNoise(uv * vec2(210.0, 260.0) + vec2(time * 0.80, -time * 0.55));
    float particulate = smoothstep(0.970, 1.0, particulateNoise) * cardAlpha * intensity * (0.45 + 0.55 * slowWaterNoise);
    tex.rgb += particulate * vec3(0.54, 0.95, 0.95) * 0.25;

    float bubbles = 0.0;
    bubbles += bubbleLayer(uv + vec2(0.00, 0.00), time, 1.0, 1.00, intensity) * 0.72;
    bubbles += bubbleLayer(uv + vec2(0.13, 0.07), time, 2.0, 1.45, intensity) * 0.42;
    bubbles += bubbleLayer(uv + vec2(-0.08, 0.11), time, 3.0, 2.15, intensity) * 0.24;

    float bubbleMask = smoothstep(0.08, 0.92, radial) * cardAlpha;
    bubbles *= bubbleMask;

    vec3 bubbleColor = vec3(0.72, 1.00, 0.96);
    tex.rgb += bubbles * bubbleColor * 0.34;
    tex.a = max(tex.a, bubbles * 0.18 * intensity);

    float edgeShimmer = edgeWaterShimmer(uv, time, intensity, flowScale);
    tex.rgb += edgeShimmer * vec3(0.28, 0.92, 1.00) * 0.42;
    tex.rgb += edgeShimmer * vec3(0.82, 1.00, 0.95) * 0.14;

    float outline = (1.0 - smoothstep(0.000, 0.020, abs(sdf))) * (1.0 - smoothstep(0.000, 0.120, edgeDist)) * intensity;
    tex.rgb += outline * vec3(0.26, 0.88, 1.00) * 0.30;

    vec2 center = uv - 0.5;
    float rippleA = sin(length(center - vec2(0.12, 0.04)) * 48.0 - time * 4.0);
    float rippleB = sin(length(center + vec2(0.16, -0.10)) * 36.0 - time * 3.1);

    float ripple = smoothstep(0.78, 1.0, 0.5 + 0.5 * max(rippleA, rippleB));
    ripple *= cardAlpha;
    ripple *= intensity;
    ripple *= 1.0 - smoothstep(0.85, 1.20, radial);

    tex.rgb += ripple * vec3(0.22, 0.80, 0.95) * 0.10;

    float waterPulse = 0.965 + 0.035 * sin(time * 2.0 + slowWaterNoise * 5.0);
    tex.rgb *= waterPulse;

    return vec4(saturate3(tex.rgb), saturate1(tex.a));
}

vec4 effect(vec4 colour, Image texture, vec2 texture_coords, vec2 screen_coords) {
    vec2 uv = local_uv_from_texture_coords(texture_coords);
    float anim_time = time;
    if (water.g > 0.0 || water.g < 0.0) {
        anim_time = water.y + water.x * 0.03125;
    }

    float intensity = 1.0;
    float flowScale = 0.60;

    vec2 displacement = underwaterDisplacement(uv, anim_time, intensity, flowScale);

    vec2 coordR = texture_coords_from_local_uv(uv + displacement * 1.10 + displacement * 0.45 + vec2(0.0015, -0.0008) * intensity);
    vec2 coordG = texture_coords_from_local_uv(uv + displacement);
    vec2 coordB = texture_coords_from_local_uv(uv + displacement * 0.90 - displacement * 0.45 - vec2(0.0015, -0.0008) * intensity);

    vec4 texR = Texel(texture, coordR);
    vec4 texG = Texel(texture, coordG);
    vec4 texB = Texel(texture, coordB);

    vec4 tex = vec4(texR.r, texG.g, texB.b, texG.a);
    tex = underwaterEdition(tex, uv, anim_time, intensity, flowScale);

    return dissolve_mask(tex * colour, texture_coords, uv);
}

#ifdef VERTEX
vec4 position(mat4 transform_projection, vec4 vertex_position) {
    if (hovering <= 0.0) {
        return transform_projection * vertex_position;
    }

    float mid_dist = length(vertex_position.xy - 0.5 * love_ScreenSize.xy) / length(love_ScreenSize.xy);
    vec2 mouse_offset = (vertex_position.xy - mouse_screen_pos.xy) / screen_scale;
    float scale = 0.2 * (-0.03 - 0.3 * max(0.0, 0.3 - mid_dist)) * hovering * (length(mouse_offset) * length(mouse_offset)) / (2.0 - mid_dist);

    return transform_projection * vertex_position + vec4(0.0, 0.0, 0.0, scale);
}
#endif
